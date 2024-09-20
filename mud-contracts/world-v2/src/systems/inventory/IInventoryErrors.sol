// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

interface IInventoryErrors {
  error Inventory_InvalidCapacity(string message);
  error Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Inventory_InvalidQuantity(string message, uint256 quantity, uint256 maxQuantity);
  error Inventory_InvalidItem(string message, uint256 typeId);
  error Inventory_InvalidItemQuantity(string message, uint256 inventoryItemId, uint256 quantity);
  error Inventory_InvalidDeployable(string message, uint256 deployableId);
  error Inventory_InvalidOwner(string message, address ephemeralInvOwner, address itemOwner);
}
