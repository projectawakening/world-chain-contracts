// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectSystem } from "../../src/systems/inherit/SmartObjectSystem.sol";
import { Id } from "../../src/libs/Id.sol";

contract TaggedSystemMock2 is SmartObjectSystem {  
  function allowClassLevelScope2(Id classId) public scope(classId) returns (bool) {
    return true;
  }

  function allowObjectLevelScope2(Id objectId) public scope(objectId) returns (bool) {
    return true;
  }
}