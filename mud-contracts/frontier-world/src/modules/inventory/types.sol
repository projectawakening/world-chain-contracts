// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/**
 * @notice Holds the data for an inventory item
 * @dev InventoryItem structure
 */
struct InventoryItem {
  uint256 inventoryItemId;
  address ephemeralInventoryOwner;
  uint256 itemId;
  uint256 typeId;
  uint256 volume;
  uint256 quantity;
}
