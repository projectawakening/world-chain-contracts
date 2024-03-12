// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

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
  int256 x;
  int256 y;
  int256 z;
}
