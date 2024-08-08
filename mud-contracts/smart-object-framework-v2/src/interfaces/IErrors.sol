// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Id } from "../libs/Id.sol";

/**
 * @title IErros
 * @dev An interface for SOF custom errors
 */
interface IErrors {
  error InvalidEntityId(Id invalidId);
  error InvalidEntityType(bytes2 givenType);
  error WrongEntityType(bytes2 givenType, bytes2[] expectedTypes);
  error ClassAlreadyExists(Id classId);
  error ClassDoesNotExist(Id classId);
  error ClassHasObjects(Id classId, uint256 numberOfObjects);
  error ObjectAlreadyExists(Id objectId, Id instanceClass);
  error ObjectDoesNotExist(Id objectId);

  error InvalidTagId(Id tagId);
  error InvalidTagType(bytes2 givenType);
  error TagAlreadyExists(Id tagId);
  error TagDoesNotExist(Id tagId);
  error TagNotFound(Id entityId, Id tagId);
  error WrongTagType(bytes2 givenType, bytes2[] expectedTypes);
  error SystemNotRegistered(ResourceId systemId);
  error EntityAlreadyHasTag(Id entityId, Id tagId);

  error InvalidSystemCall(Id entityId, ResourceId systemId);
}
