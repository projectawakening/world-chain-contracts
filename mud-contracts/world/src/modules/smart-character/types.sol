// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

/**
 * @notice Holds the data for a smart object
 * @dev SmartObjectData structure
 */
struct SmartObjectData {
  address owner;
  string tokenURI;
}

struct EntityRecordData {
  uint256 typeId;
  uint256 itemId;
  uint256 volume;
}
