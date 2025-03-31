// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { TagId } from "../../../libs/TagId.sol";

import { TagParams } from "../systems/tag-system/types.sol";

/**
 * @title ITagSystem
 * @dev An interface for the Tags System functionality
 */
interface ITagSystem {
  function setTag(uint256 entityId, TagParams memory tagParams) external;
  function setTags(uint256 entityId, TagParams[] memory tagParams) external;
  function removeTag(uint256 entityId, TagId tagId) external;
  function removeTags(uint256 entityId, TagId[] memory tagIds) external;

  error Tag_InvalidTagId(TagId tagId);
  error Tag_TagDoesNotExist(TagId tagId);
  error Tag_TagNotFound(uint256 entityId, TagId tagId);
  error Tag_TagTypeNotDefined(bytes2 tagType);
  error Tag_ResourceNotRegistered(ResourceId systemId);
  error Tag_EntityAlreadyHasTag(uint256 entityId, TagId tagId);
  error Tag_InvalidCaller(address caller);
  error Tag_OnlyClassOrObjectPropertyAllowed();
  error Tag_EntityDoesNotExist(uint256 entityId);
}
