// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectFramework } from "../../src/inherit/SmartObjectFramework.sol";
import { Id } from "../../src/libs/Id.sol";

contract TaggedSystemMock3 is SmartObjectFramework {
  function allowClassLevelScope3(Id classId) public scope(classId) returns (bool) {
    return true;
  }

  function allowObjectLevelScope3(Id objectId) public scope(objectId) returns (bool) {
    return true;
  }
}
