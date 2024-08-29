// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectFramework } from "../../src/inherit/SmartObjectFramework.sol";
import { Id } from "../../src/libs/Id.sol";

contract TaggedSystemMock2 is SmartObjectFramework {
  function allowClassLevelScope2(Id classId) public scope(classId) returns (bool) {
    return true;
  }

  function allowObjectLevelScope2(Id objectId) public scope(objectId) returns (bool) {
    return true;
  }
}
