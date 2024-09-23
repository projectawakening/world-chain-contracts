//SPDX-LicenseIdentifier: MIT
pragma solidity >=0.8.21;

interface IInventoryErrors {
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
  error Inventory_InvalidEphemeralInventoryOwner(string message, address ephemeralInvOwner);
  error Inventory_InvalidTransferItemQuantity(
    string message,
    uint256 smartObjectId,
    string inventoryType,
    address inventoryOwner,
    uint256 inventoryItemId,
    uint256 quantity
  );
}
