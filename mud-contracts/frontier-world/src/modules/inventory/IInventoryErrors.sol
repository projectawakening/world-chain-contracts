//SPDX-LicenseIdentifier: MIT
pragma solidity >=0.8.21;

interface IInventoryErrors {
  error Inventory_InvalidCapacity(string message);
  error EphemeralInventory_InvalidCapacity(string message);

  error Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Inventory_InsufficientEphemeralCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);

  error Inventory_InvalidQuantity(string message, uint256 quantity, uint256 maxQuantity);
}
