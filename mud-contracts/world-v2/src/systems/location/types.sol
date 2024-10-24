// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

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
