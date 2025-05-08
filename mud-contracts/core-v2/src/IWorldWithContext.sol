// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IWorld } from "./codegen/world/IWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

/**
 * @title IWorldWithContext
 * @author CCP Games
 * @notice Interface for accessing MUD World execution context data getters
 * @dev Extends IWorld with methods to track and retrieve world call context information
 * including system IDs, function selectors, msg.sender and msg.value across the world execution call stack
 */
interface IWorldWithContext is IWorld {
  function callStatic(ResourceId systemId, bytes memory callData) external view returns (bytes memory);
  function getWorldCallContext() external view returns (ResourceId, bytes4, address, uint256);
  function getWorldCallContext(uint256 callCount) external view returns (ResourceId, bytes4, address, uint256);
  function getWorldCallCount() external view returns (uint256);
}
