// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

/**
 * @title IEntryForwarder
 * @dev An interface for the Entry Forwarder System
 */
interface IEntryForwarder {
  function call(ResourceId systemId, bytes calldata callData) external returns (bytes memory);
}
