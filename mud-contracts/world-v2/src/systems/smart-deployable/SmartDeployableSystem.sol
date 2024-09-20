// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableTokenTable } from "../../codegen/index.sol";
import { FuelSystem } from "../fuel/FuelSystem.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";
import { LocationSystem } from "../location/LocationSystem.sol";
import { LocationData } from "../../codegen/tables/Location.sol";
import { Location, LocationData } from "../../codegen/index.sol";
import { IERC721Mintable } from "../eve-erc721-puppet/IERC721Mintable.sol";
import { StaticDataSystem } from "../static-data/StaticDataSystem.sol";
import { EveSystem } from "../EveSystem.sol";

import { State, SmartObjectData } from "./types.sol";
import { SmartDeployableErrors } from "./SmartDeployableErrors.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "./constants.sol";

import { LocationUtils } from "../location/LocationUtils.sol";
import { FuelUtils } from "../fuel/FuelUtils.sol";
import { StaticDataUtils } from "../static-data/StaticDataUtils.sol";
import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";

import "forge-std/console.sol";

/**
 * @title SmartDeployableSystem
 * @author CCP Games
 * SmartDeployableSystem stores the deployable state of a smart object on-chain
 */
contract SmartDeployableSystem is EveSystem, SmartDeployableErrors {
  using LocationUtils for bytes14;
  using FuelUtils for bytes14;
  using StaticDataUtils for bytes14;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused() == false) {
      revert SmartDeployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * @dev sets the ERC721 address for a deployable token
   * @param erc721Address the address of the ERC721 contract
   */
  function registerDeployableToken(address erc721Address) public {
    if (DeployableTokenTable.getErc721Address() != address(0)) {
      revert SmartDeployableERC721AlreadyInitialized();
    }
    DeployableTokenTable.set(erc721Address);
  }

  /**
   * TODO: restrict this to entityIds that exist
   * @dev registers a new smart deployable (must be "NULL" state)
   * @param entityId entityId
   * @param smartObjectData the data of the smart object
   * @param fuelUnitVolumeInWei the fuel unit volume in wei
   * @param fuelConsumptionIntervalInSeconds the fuel consumption per minute in wei
   * @param fuelMaxCapacityInWei the fuel max capacity in wei
   */
  function registerDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolumeInWei,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacityInWei
  ) public onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.NULL || previousState == State.UNANCHORED)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    if (fuelConsumptionIntervalInSeconds < 1) {
      revert SmartDeployable_InvalidFuelConsumptionInterval(entityId);
    }

    if (previousState == State.NULL) {
      address erc721Address = DeployableTokenTable.getErc721Address();
      IERC721Mintable(erc721Address).mint(smartObjectData.owner, entityId);

      ResourceId staticDataSystemId = StaticDataUtils.staticDataSystemId();
      console.logBytes32(ResourceId.unwrap(staticDataSystemId));
      world().call(staticDataSystemId, abi.encodeCall(StaticDataSystem.setCid, (entityId, smartObjectData.tokenURI)));
    }

    DeployableState.set(
      entityId,
      block.timestamp,
      State.NULL,
      State.UNANCHORED,
      false,
      0,
      block.number,
      block.timestamp
    );

    ResourceId fuelSystemId = FuelUtils.fuelSystemId(); // this doesnt work
    world().call(
      fuelSystemId,
      abi.encodeCall(
        FuelSystem.configureFuelParameters,
        (entityId, fuelUnitVolumeInWei, fuelConsumptionIntervalInSeconds, fuelMaxCapacityInWei, 0, block.timestamp)
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
   * @dev brings all smart deployables online
   * TODO: limit to admin use only
   */
  function globalPause() public {
    GlobalDeployableState.setIsPaused(false);
    GlobalDeployableState.setUpdatedBlockNumber(block.number);
    GlobalDeployableState.setLastGlobalOffline(block.timestamp);
  }

  /**
   * @dev brings all smart deployables offline
   * TODO: limit to admin use only
   */
  function globalResume() public {
    GlobalDeployableState.setIsPaused(true);
    GlobalDeployableState.setUpdatedBlockNumber(block.number);
    GlobalDeployableState.setLastGlobalOnline(block.timestamp);
  }

  /**
   * @dev sets the full deployable state values
   * @param entityId entityId
   * @param createdAt the created at timestamp
   * @param previousState the previous state
   * @param currentState the current state
   * @param isValid the is valid flag
   * @param anchoredAt the anchored at timestamp
   * @param updatedBlockNumber the updated block number
   * @param updatedBlockTime the updated block time
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
  ) public onlyActive {
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

  // set current deployable state
  function setCurrentState(uint256 entityId, State currentState) public onlyActive {
    DeployableState.setCurrentState(entityId, currentState);
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
    GlobalDeployableStateData memory globalData = GlobalDeployableState.get();

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
