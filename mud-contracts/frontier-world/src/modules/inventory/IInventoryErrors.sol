//SPDX-LicenseIdentifier: MIT
pragma solidity >=0.8.21;

interface IInventoryErrors {
  error Inventory_InvalidCapacity(string message);
  error EphemeralInventory_InvalidCapacity(string message);
}
