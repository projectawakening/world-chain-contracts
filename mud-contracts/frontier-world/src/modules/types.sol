// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @notice Holds the data for a game entity
 * @dev EntityRecord structure
 */
struct EntityRecordData {
  uint256 typeId;
  uint256 itemId;
  uint256 volume;
}

/**
 * @notice Holds the data for a smart object
 * @dev SmartObjectData structure
 */
struct SmartObjectData {
  address owner;
  string tokenURI;
}

/**
 * @notice Holds the data for a world position
 * @dev WorldPosition structure
 */
struct WorldPosition {
  uint256 solarSystemId;
  Coord position;
}

/**
 * @notice Holds the data for a coordinate
 * @dev Coord structure
 */
struct Coord {
  uint256 x;
  uint256 y;
  uint256 z;
}

/**
 * @notice Holds the data for an inventory item
 * @dev InventoryItem structure
 */
struct InventoryItem {
  uint256 inventoryItemId;
  address owner;
  uint256 itemId;
  uint256 typeId;
  uint256 volume;
  uint256 quantity;
}
