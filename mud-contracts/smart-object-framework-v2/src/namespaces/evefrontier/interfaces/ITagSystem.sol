// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Id } from "../../../libs/Id.sol";

/**
 * @title ITagSystem
 * @dev An interface for the Tags System functionality
 */
interface ITagSystem {
  function setSystemTag(Id classId, Id systemTagId) external;
  function setSystemTags(Id classId, Id[] memory systemTagIds) external;
  function removeSystemTag(Id classId, Id tagId) external;
  function removeSystemTags(Id classId, Id[] memory tagIds) external;

  error InvalidTagId(Id tagId);
  error InvalidTagType(bytes2 givenType);
  error TagAlreadyExists(Id tagId);
  error TagDoesNotExist(Id tagId);
  error TagNotFound(Id entityId, Id tagId);
  error WrongTagType(bytes2 givenType, bytes2[] expectedTypes);
  error SystemNotRegistered(ResourceId systemId);
  error EntityAlreadyHasTag(Id entityId, Id tagId);
}
