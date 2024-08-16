// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableTokenTable } from "../../codegen/index.sol";
import { State } from "../../codegen/common.sol";

/**
 * @title SmartDeployableSystem
 * @author CCP Games
 * SmartDeployableSystem stores the deployable state of a smart object on-chain
 */

contract SmartDeployableSystem is System {
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
   * @dev toggles the global state status
   * @param updatedBlockNumber the block number at which the state was updated
   * @param isPaused the state of the deployable
   */
  function setIsPausedGlobalState(uint256 updatedBlockNumber, bool isPaused) public {
    GlobalDeployableState.setIsPaused(updatedBlockNumber, isPaused);
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
   * @dev sets the deployable state
   * @param smartObjectId smartObjectId of the in-game object
   * @param createdAt the time the object was created
   * @param previousState the previous state of the object
   * @param currentState the current state of the object
   * @param isValid the validity of the object
   * @param anchoredAt the time the object was anchored
   * @param updatedBlockNumber the block number at which the state was updated
   * @param updatedBlockTime the time at which the state was updated
   */
  function setDeployableState(
    uint256 smartObjectId,
    uint256 createdAt,
    State previousState,
    State currentState,
    bool isValid,
    uint256 anchoredAt,
    uint256 updatedBlockNumber,
    uint256 updatedBlockTime
  ) public {
    DeployableState.set(
      smartObjectId,
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
   * @param smartObjectId smartObjectId of the in-game object
   * @param createdAt the time the object was created
   */
  function setCreatedAt(uint256 smartObjectId, uint256 createdAt) public {
    DeployableState.setCreatedAt(smartObjectId, createdAt);
  }

  /**
   * @dev sets the previous state of the object
   * @param smartObjectId smartObjectId of the in-game object
   * @param previousState the previous state of the object
   */
  function setPreviousState(uint256 smartObjectId, State previousState) public {
    DeployableState.setPreviousState(smartObjectId, previousState);
  }

  /**
   * @dev sets the current state of the object
   * @param smartObjectId smartObjectId of the in-game object
   * @param currentState the current state of the object
   */
  function setCurrentState(uint256 smartObjectId, State currentState) public {
    DeployableState.setCurrentState(smartObjectId, currentState);
  }

  /**
   * @dev sets the validity of the object
   * @param smartObjectId smartObjectId of the in-game object
   * @param isValid the validity of the object
   */
  function setIsValid(uint256 smartObjectId, bool isValid) public {
    DeployableState.setIsValid(smartObjectId, isValid);
  }

  /**
   * @dev sets the time the object was anchored
   * @param smartObjectId smartObjectId of the in-game object
   * @param anchoredAt the time the object was anchored
   */
  function setAnchoredAt(uint256 smartObjectId, uint256 anchoredAt) public {
    DeployableState.setAnchoredAt(smartObjectId, anchoredAt);
  }

  /**
   * @dev sets the block number at which the state was updated
   * @param smartObjectId smartObjectId of the in-game object
   * @param updatedBlockNumber the block number at which the state was updated
   */
  function setUpdatedBlockNumber(uint256 smartObjectId, uint256 updatedBlockNumber) public {
    DeployableState.setUpdatedBlockNumber(smartObjectId, updatedBlockNumber);
  }

  /**
   * @dev sets the time at which the state was updated
   * @param smartObjectId smartObjectId of the in-game object
   * @param updatedBlockTime the time at which the state was updated
   */
  function setUpdatedBlockTime(uint256 smartObjectId, uint256 updatedBlockTime) public {
    DeployableState.setUpdatedBlockTime(smartObjectId, updatedBlockTime);
  }

  // set deployable token table
  function setDeployableTokenTable(uint256 smartObjectId, address erc721Address) public {
    DeployableTokenTable.set(smartObjectId, erc721Address);
  }
}
