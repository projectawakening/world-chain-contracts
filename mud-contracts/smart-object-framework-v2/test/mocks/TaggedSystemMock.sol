// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectFramework } from "../../src/inherit/SmartObjectFramework.sol";
import { Id } from "../../src/libs/Id.sol";

contract TaggedSystemMock is SmartObjectFramework {
  function allowClassLevelScope(Id classId) public scope(classId) returns (bool) {
    return true;
  }

  function allowObjectLevelScope(Id objectId) public scope(objectId) returns (bool) {
    return true;
  }
}
