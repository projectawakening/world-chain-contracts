// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectSystem } from "../../src/systems/inherit/SmartObjectSystem.sol";
import { Id } from "../../src/libs/Id.sol";

contract UnTaggedSystemMock is SmartObjectSystem {  
  function blockClassLevelScope(Id classId) public scope(classId) returns (bool) {
    return true;
  }

  function blockObjectLevelScope(Id objectId) public scope(objectId) returns (bool) {
    return true;
  }
}