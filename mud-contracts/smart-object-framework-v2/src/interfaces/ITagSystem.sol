// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Id } from "../libs/Id.sol";

/**
 * @title ITagSystem
 * @dev An interface for the Tag System functionality
 */
interface ITagSystem {
  function setSystemTag(Id classId, Id systemTagId) external;
  function setSystemTags(Id classId, Id[] memory systemTagIds) external;
  function removeSystemTag(Id classId, Id tagId) external;
  function removeSystemTags(Id classId, Id[] memory tagIds) external;
}
