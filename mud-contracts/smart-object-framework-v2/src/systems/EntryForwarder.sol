// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { SmartObjectSystem } from "./inherit/SmartObjectSystem.sol";

contract EntryForwarder is SmartObjectSystem {
  function call(ResourceId systemId, bytes calldata callData) public returns (bytes memory) {
    return _call(systemId, callData);
  }
}
