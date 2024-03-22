// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

/**
 * @title IEntityCore
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 * Needs to match corresponding System exhaustively
 */
interface IEntityCore {
  function registerEntityType(uint8 entityTypeId, bytes32 entityType) external;

  function registerEntity(uint256 entityId, uint8 entityType) external;

  function registerEntities(uint256[] memory entityId, uint8[] memory entityType) external;

  function registerEntityTypeAssociation(uint8 entityType, uint8 tagEntityType) external;

  function tagEntity(uint256 entityId, uint256 entityTagId) external;

  function tagEntities(uint256 entityId, uint256[] memory entityTagIds) external;

  function removeEntityTag(uint256 entityId, uint256 entityTagId) external;
}
