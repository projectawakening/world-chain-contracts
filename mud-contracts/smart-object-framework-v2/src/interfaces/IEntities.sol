// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Id } from "../libs/Id.sol";

/**
 * @title IEntities
 * @dev An interface for the Entities System functionality
 */
interface IEntities {
	function registerClass(Id classId, Id[] memory systemTagIds) external;
  function deleteClass(Id classId) external;
  function deleteClasses(Id[] memory classIds) external;
  function instantiate(Id classId, Id objectId) external;
  function deleteObject(Id objectId) external;
  function deleteObjects(Id[] memory objectIds) external;
}