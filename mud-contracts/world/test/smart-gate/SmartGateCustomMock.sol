// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

contract SmartGateCustomMock is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return false;
  }
}
