// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableTokenTable } from "../../codegen/index.sol";
import { FuelSystem } from "../fuel/FuelSystem.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";
import { LocationSystem } from "../location/LocationSystem.sol";
import { LocationData } from "../../codegen/tables/Location.sol";
import { Location, LocationData } from "../../codegen/index.sol";
import { EveSystem } from "../EveSystem.sol";

import { State, SmartObjectData } from "./types.sol";
import { SmartDeployableErrors } from "./SmartDeployableErrors.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "./constants.sol";
import { Utils } from "./Utils.sol";

import { Utils as LocationUtils } from "../location/Utils.sol";
import { Utils as FuelUtils } from "../fuel/Utils.sol";

/**
 * @title SmartDeployableSystem
 * @author CCP Games
 * SmartDeployableSystem stores the deployable state of a smart object on-chain
 */

contract SmartDeployableSystem is EveSystem, SmartDeployableErrors {
  using WorldResourceIdInstance for ResourceId;
  using LocationUtils for bytes14;
  using FuelUtils for bytes14;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused(block.timestamp) == false) {
      revert SmartDeployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * TODO: restrict this to entityIds that exist
   * @dev registers a new smart deployable (must be "NULL" state)
   * @param entityId entityId
   * @param smartObjectData the data of the smart object
   * @param fuelUnitVolumeInWei the fuel unit volume in wei
   * @param fuelConsumptionPerMinuteInWei the fuel consumption per minute in wei
   * @param fuelMaxCapacityInWei the fuel max capacity in wei
   */
  function registerDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolumeInWei,
    uint256 fuelConsumptionPerMinuteInWei,
    uint256 fuelMaxCapacityInWei
  ) public onlyActive {
    // create entity if it doesn't exist

    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.NULL || previousState == State.UNANCHORED)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    if (fuelConsumptionPerMinuteInWei < 1) {
      revert SmartDeployable_InvalidFuelConsumptionInterval(entityId);
    }

    if (previousState == State.NULL) {
      // TODO: mint erc721 token to owner
      // TODO: set uri
    }

    DeployableState.set(
      entityId,
      block.timestamp,
      State.NULL,
      State.UNANCHORED,
      true,
      0,
      block.number,
      block.timestamp
    );

    ResourceId fuelSystemId = FuelUtils.fuelSystemId();
    world().call(
      fuelSystemId,
      abi.encodeCall(
        FuelSystem.setFuelBalance,
        (entityId, fuelUnitVolumeInWei, 60, fuelMaxCapacityInWei, 0, block.timestamp)
      )
    );
  }

  /**
   * @dev destroys a smart deployable
   * @param entityId entityId
   */
  function destroyDeployable(uint256 entityId) public onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _setDeployableState(entityId, previousState, State.DESTROYED);
    DeployableState.setIsValid(entityId, false);
  }

  /**
   * @dev brings a smart deployable online
   * @param entityId entityId
   */
  function bringOnline(uint256 entityId) public onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (previousState != State.ANCHORED) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _updateFuel(entityId);
    uint256 currentFuel = Fuel.getFuelAmount(entityId);
    if (currentFuel < 1) revert SmartDeployable_NoFuel(entityId);

    ResourceId fuelSystemId = FuelUtils.fuelSystemId();
    world().call(fuelSystemId, abi.encodeCall(FuelSystem.setFuelAmount, (entityId, currentFuel - ONE_UNIT_IN_WEI)));
    world().call(fuelSystemId, abi.encodeCall(FuelSystem.setLastUpdatedAt, (entityId, block.timestamp)));

    _setDeployableState(entityId, previousState, State.ONLINE);
  }

  /**
   * @dev brings a smart deployable offline
   * @param entityId entityId
   */
  function bringOffline(uint256 entityId) public onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (previousState != State.ONLINE) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _updateFuel(entityId);
    _bringOffline(entityId, previousState);
  }

  /**
   * @dev anchors a smart deployable
   * @param entityId entityId
   * @param locationData the location data of the object
   */
  function anchor(uint256 entityId, LocationData memory locationData) public onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (previousState != State.UNANCHORED) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _setDeployableState(entityId, previousState, State.ANCHORED);

    ResourceId locationSystemId = LocationUtils.locationSystemId();
    world().call(locationSystemId, abi.encodeCall(LocationSystem.saveLocationData, (entityId, locationData)));

    DeployableState.setIsValid(entityId, true);
    DeployableState.setAnchoredAt(entityId, block.timestamp);
  }

  /**
   * @dev unanchors a smart deployable
   * @param entityId entityId
   */
  function unanchor(uint256 entityId) public onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    _setDeployableState(entityId, previousState, State.UNANCHORED);

    ResourceId locationSystemId = LocationUtils.locationSystemId();
    world().call(locationSystemId, abi.encodeCall(LocationSystem.saveLocation, (entityId, 0, 0, 0, 0)));

    DeployableState.setIsValid(entityId, false);
  }

  /**
   * @dev sets the global deployable state
   * @param updatedBlockNumber the block number at which the state was updated
   * @param isPaused the state of the deployable
   * @param lastGlobalOffline the last time the deployable was offline
   * @param lastGlobalOnline the last time the deployable was online
   */
  function setGlobalDeployableState(
    uint256 updatedBlockNumber,
    bool isPaused,
    uint256 lastGlobalOffline,
    uint256 lastGlobalOnline
  ) public {
    GlobalDeployableState.set(updatedBlockNumber, isPaused, lastGlobalOffline, lastGlobalOnline);
  }

  /**
   * @dev brings all smart deployables online
   * @param updatedBlockNumber the block number at which the state was updated
   * TODO: limit to admin use only
   */
  function setGlobalPause(uint256 updatedBlockNumber) public {
    GlobalDeployableState.setIsPaused(updatedBlockNumber, true);
  }

  /**
   * @dev brings all smart deployables offline
   * @param updatedBlockNumber the block number at which the state was updated
   * TODO: limit to admin use only
   */
  function setGlobalResume(uint256 updatedBlockNumber) public {
    GlobalDeployableState.setIsPaused(updatedBlockNumber, false);
  }

  /**
   * @dev sets the last time the deployable was offline
   * @param updatedBlockNumber the block number at which the state was updated
   * @param lastGlobalOffline the last time the deployable was offline
   */
  function setLastGlobalOffline(uint256 updatedBlockNumber, uint256 lastGlobalOffline) public {
    GlobalDeployableState.setLastGlobalOffline(updatedBlockNumber, lastGlobalOffline);
  }

  /**
   * @dev sets the last time the deployable was online
   * @param updatedBlockNumber the block number at which the state was updated
   * @param lastGlobalOnline the last time the deployable was online
   */

  function setLastGlobalOnline(uint256 updatedBlockNumber, uint256 lastGlobalOnline) public {
    GlobalDeployableState.setLastGlobalOnline(updatedBlockNumber, lastGlobalOnline);
  }

  /**
   * @dev sets the ERC721 address for a deployable token
   * @param entityId entityId of the in-game object
   * @param erc721Address the address of the ERC721 contract
   */
  function registerDeployableToken(uint256 entityId, address erc721Address) public {
    DeployableTokenTable.set(entityId, erc721Address);
  }

  /**
   * @dev sets the deployable state
   * @param entityId entityId of the in-game object
   * @param createdAt the time the object was created
   * @param previousState the previous state of the object
   * @param currentState the current state of the object
   * @param isValid the validity of the object
   * @param anchoredAt the time the object was anchored
   * @param updatedBlockNumber the block number at which the state was updated
   * @param updatedBlockTime the time at which the state was updated
   */
  function setDeployableState(
    uint256 entityId,
    uint256 createdAt,
    State previousState,
    State currentState,
    bool isValid,
    uint256 anchoredAt,
    uint256 updatedBlockNumber,
    uint256 updatedBlockTime
  ) public {
    DeployableState.set(
      entityId,
      createdAt,
      previousState,
      currentState,
      isValid,
      anchoredAt,
      updatedBlockNumber,
      updatedBlockTime
    );
  }

  /**
   * @dev sets the time the object was created
   * @param entityId entityId of the in-game object
   * @param createdAt the time the object was created
   */
  function setCreatedAt(uint256 entityId, uint256 createdAt) public {
    DeployableState.setCreatedAt(entityId, createdAt);
  }

  /**
   * @dev sets the previous state of the object
   * @param entityId entityId of the in-game object
   * @param previousState the previous state of the object
   */
  function setPreviousState(uint256 entityId, State previousState) public {
    DeployableState.setPreviousState(entityId, previousState);
  }

  /**
   * @dev sets the current state of the object
   * @param entityId entityId of the in-game object
   * @param currentState the current state of the object
   */
  function setCurrentState(uint256 entityId, State currentState) public {
    DeployableState.setCurrentState(entityId, currentState);
  }

  /**
   * @dev sets the validity of the object
   * @param entityId entityId of the in-game object
   * @param isValid the validity of the object
   */
  function setIsValid(uint256 entityId, bool isValid) public {
    DeployableState.setIsValid(entityId, isValid);
  }

  /**
   * @dev sets the time the object was anchored
   * @param entityId entityId of the in-game object
   * @param anchoredAt the time the object was anchored
   */
  function setAnchoredAt(uint256 entityId, uint256 anchoredAt) public {
    DeployableState.setAnchoredAt(entityId, anchoredAt);
  }

  /**
   * @dev sets the block number at which the state was updated
   * @param entityId entityId of the in-game object
   * @param updatedBlockNumber the block number at which the state was updated
   */
  function setUpdatedBlockNumber(uint256 entityId, uint256 updatedBlockNumber) public {
    DeployableState.setUpdatedBlockNumber(entityId, updatedBlockNumber);
  }

  /**
   * @dev sets the time at which the state was updated
   * @param entityId entityId of the in-game object
   * @param updatedBlockTime the time at which the state was updated
   */
  function setUpdatedBlockTime(uint256 entityId, uint256 updatedBlockTime) public {
    DeployableState.setUpdatedBlockTime(entityId, updatedBlockTime);
  }

  /*******************************
   * INTERNAL DEPLOYABLE METHODS *
   *******************************/

  /**
   * @dev brings offline smart deployable (internal method)
   * @param entityId entityId
   */
  function _bringOffline(uint256 entityId, State previousState) internal {
    _setDeployableState(entityId, previousState, State.ANCHORED);
  }

  /**
   * @dev internal method to set the state of a deployable
   * @param entityId to update
   * @param previousState to set
   * @param currentState to set
   */
  function _setDeployableState(uint256 entityId, State previousState, State currentState) internal {
    DeployableState.setPreviousState(entityId, previousState);
    DeployableState.setCurrentState(entityId, currentState);
    _updateBlockInfo(entityId);
  }

  /**
   * @dev update block information for a given entity
   * @param entityId to update
   */
  function _updateBlockInfo(uint256 entityId) internal {
    DeployableState.setUpdatedBlockNumber(entityId, block.number);
    DeployableState.setUpdatedBlockTime(entityId, block.timestamp);
  }

  /*************************
   * INTERNAL FUEL METHODS *
   **************************/

  /**
   * @dev Deposit fuel into a smart deployable.
   * @param entityId The entity ID to deposit fuel into.
   */
  function _updateFuel(uint256 entityId) internal {
    uint256 currentFuel = _currentFuelAmount(entityId);
    State previousState = DeployableState.getCurrentState(entityId);
    ResourceId fuelSystemId = FuelUtils.fuelSystemId();

    if (currentFuel == 0 && (previousState == State.ONLINE)) {
      _bringOffline(entityId, previousState);

      world().call(fuelSystemId, abi.encodeCall(FuelSystem.setFuelAmount, (entityId, 0)));
    } else {
      world().call(fuelSystemId, abi.encodeCall(FuelSystem.setFuelAmount, (entityId, currentFuel)));
    }

    world().call(fuelSystemId, abi.encodeCall(FuelSystem.setLastUpdatedAt, (entityId, block.timestamp)));
  }

  /**
   * @dev Calculate the current fuel amount for a given entity.
   * @param entityId The entity ID to calculate the fuel amount for.
   * @return The current fuel amount.
   */
  function _currentFuelAmount(uint256 entityId) internal view returns (uint256) {
    // Check if the entity is not online. If it's not online, return the fuel amount directly.
    if (DeployableState.getCurrentState(entityId) != State.ONLINE) {
      return Fuel.getFuelAmount(entityId);
    }

    // Fetch the fuel balance data for the entity.
    FuelData memory fuelData = Fuel.get(entityId);

    uint256 oneFuelUnitConsumptionIntervalInSec = fuelData.fuelConsumptionIntervalInSeconds;

    // Calculate the fuel consumed since the last update.
    uint256 fuelConsumed = ((block.timestamp - fuelData.lastUpdatedAt) * ONE_UNIT_IN_WEI) /
      oneFuelUnitConsumptionIntervalInSec;

    // Subtract any global offline fuel refund from the consumed fuel.
    fuelConsumed -= _globalOfflineFuelRefund(entityId);

    // If the consumed fuel is greater than or equal to the current fuel amount, return 0.
    if (fuelConsumed >= fuelData.fuelAmount) {
      return 0;
    }

    // Return the remaining fuel amount.
    return fuelData.fuelAmount - fuelConsumed;
  }

  /**
   * @dev Calculate the global offline fuel refund for a given entity.
   * @param entityId The entity ID to calculate the refund for.
   * @return The amount of fuel to refund.
   */
  function _globalOfflineFuelRefund(uint256 entityId) internal view returns (uint256) {
    // Fetch the global deployable state data.
    GlobalDeployableStateData memory globalData = GlobalDeployableState.get(entityId);

    if (globalData.lastGlobalOffline == 0) return 0; // servers have never been shut down
    if (DeployableState.getCurrentState(entityId) != State.ONLINE) return 0;

    uint256 bringOnlineTimestamp = DeployableState.getUpdatedBlockTime(entityId);
    if (bringOnlineTimestamp < globalData.lastGlobalOffline) bringOnlineTimestamp = globalData.lastGlobalOffline;

    uint256 lastGlobalOnline = globalData.lastGlobalOnline;
    if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

    uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spent online during server downtime
    return ((elapsedRefundTime * ONE_UNIT_IN_WEI) / (Fuel.getFuelConsumptionIntervalInSeconds(entityId)));
  }
}
