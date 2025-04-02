// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { AccessControl } from "@latticexyz/world/src/AccessControl.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";

import { IWorldErrors } from "@latticexyz/world/src/IWorldErrors.sol";

import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";

import { StaticWorldContextProviderLib } from "./StaticWorldContext.sol";

/**
 * @title StaticSystemCall
 * @author CCP Games dev team
 * @dev The StaticSystemCall library provides functions for rxplicitly interacting with view/pure functions in systems using their unique Resource IDs.
 * It ensures the necessary access control checks, handles system hooks, and performs system calls.
 */
library StaticSystemCall {
  using WorldResourceIdInstance for ResourceId;

  /**
   * @notice Statically calls a system identified by its Resource ID while ensuring necessary access controls.
   * @dev This function does not revert if the system call fails. Instead, it returns a success flag.
   * @param caller The address initiating the system call.
   * @param systemId The unique Resource ID of the system being called.
   * @param callData The calldata to be executed in the system.
   * @return success A flag indicating whether the system call was successful.
   * @return data The return data from the system call.
   */
  function staticCall(
    address caller,
    ResourceId systemId,
    bytes memory callData
  ) internal view returns (bool success, bytes memory data) {
    // Load the system data
    (address systemAddress, bool publicAccess) = Systems._get(systemId);

    // Check if the system exists
    if (systemAddress == address(0)) revert IWorldErrors.World_ResourceNotFound(systemId, systemId.toString());

    // Allow access if the system is public or the caller has access to the namespace or name
    if (!publicAccess) AccessControl._requireAccess(systemId, caller);

    // Statically call the system and forward any return data
    (success, data) = StaticWorldContextProviderLib.staticCallWithContext({
      msgSender: caller,
      target: systemAddress,
      callData: callData
    });
  }

  /**
   * @notice Statically calls a system identified by its Resource ID, ensures access controls, and reverts on failure.
   * @param caller The address initiating the system call.
   * @param systemId The unique Resource ID of the system being called.
   * @param callData The calldata to be executed in the system.
   * @return data The return data from the system call.
   */
  function staticCallOrRevert(
    address caller,
    ResourceId systemId,
    bytes memory callData
  ) internal view returns (bytes memory data) {
    (bool success, bytes memory returnData) = staticCall({ caller: caller, systemId: systemId, callData: callData });
    if (!success) revertWithBytes(returnData);
    return returnData;
  }
}
