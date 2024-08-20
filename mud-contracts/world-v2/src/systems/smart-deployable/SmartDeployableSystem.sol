// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableTokenTable } from "../../codegen/index.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";

import { State, SmartObjectData } from "./types.sol";
import { SmartDeployableErrors } from "./SmartDeployableErrors.sol";

/**
 * @title SmartDeployableSystem
 * @author CCP Games
 * SmartDeployableSystem stores the deployable state of a smart object on-chain
 */

contract SmartDeployableSystem is System, SmartDeployableErrors {
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
  ) public {
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

    // set fuel data
    Fuel.set(entityId, fuelUnitVolumeInWei, 60, fuelMaxCapacityInWei, 0, block.timestamp);
  }

  // destroyDeployable
  function destroyDeployable(uint256 entityId) public {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
  }

  // bringOnline
  // bringOffline
  // anchor
  // unanchor

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
    GlobalDeployableState.setIsPaused(updatedBlockNumber, false);
  }

  /**
   * @dev brings all smart deployables offline
   * @param updatedBlockNumber the block number at which the state was updated
   * TODO: limit to admin use only
   */
  function setGlobalResume(uint256 updatedBlockNumber) public {
    GlobalDeployableState.setIsPaused(updatedBlockNumber, true);
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

  /********************
   * INTERNAL METHODS *
   ********************/
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
}
