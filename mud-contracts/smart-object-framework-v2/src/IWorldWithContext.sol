// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IWorld } from "./codegen/world/IWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

interface IWorldWithContext is IWorld {
  function getWorldCallContext() external view returns (ResourceId, bytes4, address, uint256);
  function getWorldCallContext(uint256 callCount) external view returns (ResourceId, bytes4, address, uint256);
  function getWorldCallCount() external view returns (uint256);
}
