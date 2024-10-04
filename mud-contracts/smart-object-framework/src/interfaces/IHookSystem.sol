// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { HookType } from "../types.sol";

/**
 * @title IHookSystem
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 * Needs to match corresponding System exhaustively
 */
interface IHookSystem {
  function registerHook(ResourceId systemId, bytes4 functionId) external;

  function addHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) external;

  function removeHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) external;

  function associateHook(uint256 entityId, uint256 hookId) external;

  function associateHooks(uint256 entityId, uint256[] memory hookIds) external;

  function removeEntityHookAssociation(uint256 entityId, uint256 hookId) external;
}
