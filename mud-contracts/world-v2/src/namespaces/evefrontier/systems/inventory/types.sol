// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @dev CreateInventoryItemParams struct
 */
struct CreateInventoryItemParams {
  uint256 smartObjectId;
  bytes32 tenantId;
  uint256 itemId;
  uint256 typeId;
  uint256 volume;
  uint256 quantity;
}

/**
 * @dev inventoryItemParams struct
 */
struct InventoryItemParams {
  uint256 smartObjectId;
  uint256 quantity;
}
