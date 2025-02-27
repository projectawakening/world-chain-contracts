// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @dev InventoryItemParams structure
 */
struct InventoryItemParams {
  uint256 smartObjectId;
  uint256 itemId;
  uint256 typeId;
  uint256 volume;
  string tenantId;
  uint256 quantity;
}

/**
 * @dev TransferItemParams is a subset of InventoryItemParams for easier interfacing
 */
struct TransferItemParams {
  uint256 smartObjectId;
  uint256 quantity;
}
