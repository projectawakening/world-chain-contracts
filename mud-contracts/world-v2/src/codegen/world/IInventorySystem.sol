// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { InventoryItem } from "../../systems/inventory/types.sol";

/**
 * @title IInventorySystem
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IInventorySystem {
  error Inventory_InvalidCapacity(string message);
  error Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Inventory_InvalidItemQuantity(string message, uint256 quantity, uint256 maxQuantity);
  error Inventory_InvalidItem(string message, uint256 inventoryItemId);
  error Inventory_InvalidItemOwner(
    string message,
    uint256 inventoryItemId,
    address providedItemOwner,
    address expectedOwner
  );
  error Inventory_InvalidDeployable(string message, uint256 deployableId);

  function evefrontier__setInventoryCapacity(uint256 smartObjectId, uint256 capacity) external;

  function evefrontier__createAndDepositItemsToInventory(uint256 smartObjectId, InventoryItem[] memory items) external;

  function evefrontier__depositToInventory(uint256 smartObjectId, InventoryItem[] memory items) external;

  function evefrontier__withdrawFromInventory(uint256 smartObjectId, InventoryItem[] memory items) external;
}
