// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectFramework } from "../../src/inherit/SmartObjectFramework.sol";
import { Id } from "../../src/libs/Id.sol";

contract UnTaggedSystemMock is SmartObjectFramework {
  function blockClassLevelScope(Id classId) public scope(classId) returns (bool) {
    return true;
  }

  function blockObjectLevelScope(Id objectId) public scope(objectId) returns (bool) {
    return true;
  }
}
