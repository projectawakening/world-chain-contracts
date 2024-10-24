// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Id } from "../../../libs/Id.sol";

/**
 * @title IEntitySystem
 * @dev An interface for the Entity System functionality
 */
interface IEntitySystem {
  function registerClass(Id classId, Id[] memory systemTagIds) external;
  function deleteClass(Id classId) external;
  function deleteClasses(Id[] memory classIds) external;
  function instantiate(Id classId, Id objectId) external;
  function deleteObject(Id objectId) external;
  function deleteObjects(Id[] memory objectIds) external;

  error InvalidEntityId(Id invalidId);
  error InvalidEntityType(bytes2 givenType);
  error WrongEntityType(bytes2 givenType, bytes2[] expectedTypes);
  error ClassAlreadyExists(Id classId);
  error ClassDoesNotExist(Id classId);
  error ClassHasObjects(Id classId, uint256 numberOfObjects);
  error ObjectAlreadyExists(Id objectId, Id instanceClass);
  error ObjectDoesNotExist(Id objectId);
}
