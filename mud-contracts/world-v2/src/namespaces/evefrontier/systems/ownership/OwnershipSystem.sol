// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";

import {
  CharactersByAccount,
  EntityRecord,
  Inventory,
  InventoryByItem,
  InventoryItem,
  OwnershipByObject
} from "../../codegen/index.sol";

contract OwnershipSystem is SmartObjectFramework {
  // Custom errors
  error Ownership_InvalidQuantity(uint256 itemObjectId, uint256 providedQuantity, uint256 expectedQuantity);
  error Ownership_ZeroQuantity(uint256 itemObjectId);
  error Inventory_InsufficientQuantity(uint256 itemObjectId, uint256 providedQuantity, uint256 availableQuantity);
  error Ownership_InvalidSingleton(uint256 smartObjectId);
  error Ownership_InvalidAccount(address account);
  error Ownership_InvalidOwner(uint256 smartObjectId, address invalidOwner);
  error Ownership_NonexistentItemRecord(uint256 itemObjectId);
  error Ownership_NonexistentObject(uint256 smartObjectId);
  error Ownership_InvalidInventory(uint256 itemObjectId, uint256 inventoryObjectId);

  /**
   * @notice Get the owner account of a smart object
   * @param smartObjectId The smart object id to get the owner of
   * @return The owner account of the smart object
   */
  function owner(uint256 smartObjectId) public view returns (address) {
    // Check direct ownership first
    address directOwner = OwnershipByObject.get(smartObjectId);
    if (directOwner != address(0)) {
      return directOwner;
    }
    
    // Check if the object is in an inventory with valid versioning
    uint256 inventoryObjectId = InventoryByItem.get(smartObjectId);
    uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
    uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, smartObjectId);
    bool versionChanged = currentVersion > recordedVersion;
    if (!versionChanged) {
      return OwnershipByObject.get(inventoryObjectId);
    }

    return address(0);
  }

    /**
   * @notice Ascribe new ownership of a singleton smart object to an account
   * @param smartObjectId The smart object id to ascribe ownership of
   * @param to The owner account address to ascribe the smart object to
   */
  function ascribeToAccount(uint256 smartObjectId, address to) public access(smartObjectId) {
    // Check if the object exists
    if (!Entity.getExists(smartObjectId)) {
      revert Ownership_NonexistentObject(smartObjectId);
    }

    // Check if the account is valid
    if (CharactersByAccount.get(to) == 0) {
      revert Ownership_InvalidAccount(to);
    }

    // Check if the object is a singleton
    if (!_isSingleton(smartObjectId)) {
      revert Ownership_InvalidSingleton(smartObjectId);
    }

    // Ascribe ownership of the singleton smart object to the defined account
    OwnershipByObject.set(smartObjectId, to);
  }

  /**
   * @notice Annul ownership of a singleton smart object from an account
   * @param smartObjectId The smart object id to annul ownership of
   * @param from The current owner account address
   */
  function annulFromAccount(uint256 smartObjectId, address from) public access(smartObjectId) {
    // Check if the object exists
    if (!Entity.getExists(smartObjectId)) {
      revert Ownership_NonexistentObject(smartObjectId);
    }
    
    // Check if the object is a singleton
    if (!_isSingleton(smartObjectId)) {
      revert Ownership_InvalidSingleton(smartObjectId);
    }
    
    // Check if account owns the singleton object
    if (OwnershipByObject.get(smartObjectId) != from) {
      revert Ownership_InvalidOwner(smartObjectId, from);
    }

    // Remove direct ownership reference
    OwnershipByObject.deleteRecord(smartObjectId);
  }


  /**
   * @notice Ascribe ownership of item(s) to an inventory associated with a specific smart object
   * @param inventoryObjectId The smart object id associated with the destination inventory
   * @param itemObjectId The smart object id of the item to ascribe
   * @param quantity The quantity to ascribe
   */
  function ascribeToInventory(
    uint256 inventoryObjectId, 
    uint256 itemObjectId,
    uint256 quantity
  ) public access(inventoryObjectId) {
    // sanity checks
    if (!EntityRecord.getExists(itemObjectId)) {
      revert Ownership_NonexistentItemRecord(itemObjectId);
    }

    if (!Entity.getExists(inventoryObjectId)) {
      revert Ownership_NonexistentObject(inventoryObjectId);
    }
    
    if (_isSingleton(itemObjectId)) {
      if (quantity != 1) {
        revert Ownership_InvalidQuantity(itemObjectId, quantity, 1);
      }
      if (InventoryByItem.get(itemObjectId) != inventoryObjectId) {
        InventoryByItem.set(itemObjectId, inventoryObjectId);
      }
    } else {
      if (quantity == 0) {
        revert Ownership_ZeroQuantity(itemObjectId);
      }
    }

    uint256 existingItemQuantity = InventoryItem.getQuantity(inventoryObjectId, itemObjectId);
    uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
    uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);
    bool versionChanged = currentVersion > recordedVersion;

    // Update inventory quantity for this item
    InventoryItem.setQuantity(inventoryObjectId, itemObjectId, uint256(versionChanged ? quantity : existingItemQuantity + quantity));

    if (versionChanged) {
      InventoryItem.setVersion(inventoryObjectId, itemObjectId, currentVersion);
    }
  }

  /**
   * @notice Annul ownership of item(s) from an inventory associated with a specific smart object.
   * @param inventoryObjectId The smart object id associated with the source inventory
   * @param itemObjectId The smart object id of the item to remove
   * @param quantity The quantity to annul
   */
  function annulFromInventory(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 quantity
  ) public access(inventoryObjectId) {
    // sanity checks
    if (_isSingleton(itemObjectId)) {
      if (quantity != 1) {
        revert Ownership_InvalidQuantity(itemObjectId, quantity, 1);
      }
      if (InventoryByItem.get(itemObjectId) != inventoryObjectId) {
        revert Ownership_InvalidInventory(itemObjectId, inventoryObjectId);
      } else {
        InventoryByItem.deleteRecord(itemObjectId);
      }
    } else {
      if (quantity == 0) {
        revert Ownership_ZeroQuantity(itemObjectId);
      }
    }

    uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
    uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);
    uint256 existingItemQuantity = currentVersion > recordedVersion ? 0: InventoryItem.getQuantity(inventoryObjectId, itemObjectId);

    // safety check
    if (existingItemQuantity < quantity) {
      revert Inventory_InsufficientQuantity(itemObjectId, quantity, existingItemQuantity);
    }

    // Update inventory quantity for this item
    InventoryItem.setQuantity(inventoryObjectId, itemObjectId, existingItemQuantity - quantity);
  }

  /**
   * @notice Internal function to check if a smart object is a singleton
   * @param smartObjectId The smart object id
   * @return True if the smart object is a singleton, false otherwise
   */
  function _isSingleton(uint256 smartObjectId) internal view returns (bool) {
    return EntityRecord.getItemId(smartObjectId) != 0;
  }
}