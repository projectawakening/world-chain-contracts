// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

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
