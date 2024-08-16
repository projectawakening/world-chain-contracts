// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableTokenTable } from "../../codegen/index.sol";

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
}
