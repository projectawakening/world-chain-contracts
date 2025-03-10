// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";

// Local namespace tables
import {
  WorldOwnership, 
  AccountOwnership, 
  OwnershipByObject, 
  InventoryByItem, 
  Inventory, 
  InventoryItem, 
  EntityRecord, 
  CharactersByAccount 
} from "../../codegen/index.sol";

/**
 * @title OwnershipSystem
 * @author CCP Games
 * @notice Both World level and Account level ownership tracking. Supports both singleton and non-singleton smart objects.
 */
contract OwnershipSystem is SmartObjectFramework {
  // Custom errors
  error Ownership_InvalidQuantity(uint256 itemObjectId, uint256 providedQuantity, uint256 expectedQuantity);
  error Ownership_ZeroQuantity(uint256 itemObjectId);
  error Ownership_InsufficientQuantity(uint256 itemObjectId, uint256 providedQuantity, uint256 availableQuantity);
  error Ownership_InvalidSingleton(uint256 smartObjectId);
  error Ownership_InvalidAccount(address account);
  error Ownership_InvalidOwner(uint256 smartObjectId, address invalidOwner);
  error Ownership_NonexistentItemRecord(uint256 itemObjectId);
  error Ownership_NonexistentObject(uint256 smartObjectId);
  error Ownership_InvalidInventory(uint256 itemObjectId, uint256 inventoryObjectId);

    /**
     * @notice Get the total world quantity of the smart object. 
     * @param smartObjectId The smart object id
     * @return The total world quantity of `smartObjectId`. This is the sum of all currently ascribed quantities. NOTE: it will be 1 for ascribed singletons.
     */
    function worldQuantity(uint256 smartObjectId) public view returns (uint256) {
      return WorldOwnership.getQuantity(smartObjectId);
    }
 
    /**
     * @notice Get the total quantity of a smart object held by an account. 
     * @param smartObjectId The smart object id
     * @param account The account address
     * @return The total account quantity of `smartObjectId`. This is the sum of all currently ascribed quantities for an account. NOTE: it will be 1 for ascribed singletons.
     */
    function accountQuantity(uint256 smartObjectId, address account) public view returns (uint256) {
      return AccountOwnership.getQuantity(smartObjectId, account);
    }

    /**
     * @notice Get the owner of a singleton smart object or an item via ownership inheritance from an inventory.
     * @param smartObjectId The smart object id
     * @return The ultimate owner of the object, resolving through inventory ownership
     */
    function owner(uint256 smartObjectId) public view returns (address) {
      // Check if the object is directly owned
      address directOwner = OwnershipByObject.get(smartObjectId);
      if (directOwner != address(0)) {
        return directOwner;
      }

      // Check if the object is in a smart object inventory
      uint256 inventoryId = InventoryByItem.getInventoryId(smartObjectId);
      address inventoryOwner = OwnershipByObject.get(inventoryId);
      if (inventoryId != 0 && inventoryOwner != address(0)) {
        return inventoryOwner;
      }

      // Object not owned
      return address(0);
    }

    /**
     * @notice Ascribe new ownership of a singleton smart object to an account
     * @param smartObjectId The smart object id
     * @param to The owner account address to ascribe the smart object to
     */
    function ascribeToAccount(uint256 smartObjectId, address to) access(smartObjectId) scope(smartObjectId) public {
      // Check if the object exists
      if (!Entity.getExists(smartObjectId)) {
        revert Ownership_NonexistentObject(smartObjectId);
      }

      // Check if the object is a singleton
      if (!_isSingleton(smartObjectId)) {
        revert Ownership_InvalidSingleton(smartObjectId);
      }

      // ascribe ownership of the singleton smart object to the account
      _ascribeToAccount(smartObjectId, to);

      // adjust the total world quantity value(s) of the smart object
      uint256 classId = _getClassId(smartObjectId);
      
      WorldOwnership.setQuantity(smartObjectId, WorldOwnership.getQuantity(smartObjectId) + 1);
      WorldOwnership.setQuantity(classId, WorldOwnership.getQuantity(classId) + 1);
    }

    /**
     * @notice Ascribe new ownership of smart object(s) to an inventory, in the given quantity.
     * @param itemObjectId The smart object id of the item to ascribe (singleton or non-singleton)
     * @param inventoryObjectId The inventory object id (singleton)
     * @param quantity The quantity to ascribe
     */
    function ascribeToInventory(uint256 itemObjectId, uint256 inventoryObjectId, uint256 quantity) access(inventoryObjectId) public {
      if (!EntityRecord.getExists(itemObjectId)) {
        revert Ownership_NonexistentItemRecord(itemObjectId);
      }

      if (!Entity.getExists(inventoryObjectId)) {
        revert Ownership_NonexistentObject(inventoryObjectId);
      }

      if (OwnershipByObject.get(inventoryObjectId) == address(0)) {
        revert Ownership_InvalidOwner(inventoryObjectId, address(0));
      }

      // ascribe ownership of the smart object(s) to an inventory in the given quantity
      _ascribeToInventory(itemObjectId, inventoryObjectId, quantity);

      // adjust the total world quantity value(s) of the smart object
      uint256 classId = _getClassId(itemObjectId);
      
      if (_isSingleton(itemObjectId)) { // SINGLETON
        WorldOwnership.setQuantity(itemObjectId, WorldOwnership.getQuantity(itemObjectId) + quantity);
      }
      WorldOwnership.setQuantity(classId, WorldOwnership.getQuantity(classId) + quantity);
    }

    /**
     * @notice Annul ownership of a singleton smart object from an account.
     * @param smartObjectId The singleton smart object id
     * @param from The current owner account address
     */
    function annulFromAccount(uint256 smartObjectId, address from) access(smartObjectId) scope(smartObjectId) public {
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

      _annulFromAccount(smartObjectId, from);

      // adjust the total world quantity value(s) of the smart object
      uint256 classId = _getClassId(smartObjectId);
      
      WorldOwnership.setQuantity(smartObjectId, WorldOwnership.getQuantity(smartObjectId) - 1);
      WorldOwnership.setQuantity(classId, WorldOwnership.getQuantity(classId) - 1);
    }

    /**
     * @notice Annul ownership of smart object(s) from an inventory in the given quantity.
     * @param itemObjectId The smart object id
     * @param inventoryObjectId The inventory object id
     * @param quantity The quantity to annul
     */
    function annulFromInventory(uint256 itemObjectId, uint256 inventoryObjectId, uint256 quantity) access(inventoryObjectId) public {
      // Check if item is in the inventory
      if (InventoryByItem.getInventoryId(itemObjectId) != inventoryObjectId) {
        revert Ownership_InvalidInventory(itemObjectId, inventoryObjectId);
      }

      // Check if the inventory is owned
      if (OwnershipByObject.get(inventoryObjectId) == address(0)) {
        revert Ownership_InvalidOwner(inventoryObjectId, address(0));
      }

      _annulFromInventory(itemObjectId, inventoryObjectId, quantity);

      // Adjust the total world quantity value(s) of the smart object
      uint256 classId = _getClassId(itemObjectId);
      if (_isSingleton(itemObjectId)) { // SINGLETON
        InventoryByItem.deleteRecord(itemObjectId);
        WorldOwnership.setQuantity(itemObjectId, WorldOwnership.getQuantity(itemObjectId) - quantity);
      }
      WorldOwnership.setQuantity(classId, WorldOwnership.getQuantity(classId) - quantity);
    }

    /**
     * @notice Transfer ownership of a smart object from one inventory to another.
     * @param itemObjectId The smart object id
     * @param toInventoryObjectId The destination inventory smart object id
     * @param quantity The quantity to transfer
     */
    function transferInventory(uint256 itemObjectId, uint256 toInventoryObjectId, uint256 quantity) access(toInventoryObjectId) public {
      // Check if the source inventory is owned
      if (owner(itemObjectId) == address(0)) {
        revert Ownership_InvalidOwner(itemObjectId, address(0));
      }
      // Check if the destination inventory is owned
      if (owner(toInventoryObjectId) == address(0)) {
        revert Ownership_InvalidOwner(toInventoryObjectId, address(0));
      }

      uint256 fromInventoryObjectId = InventoryByItem.getInventoryId(itemObjectId);
      if (fromInventoryObjectId != toInventoryObjectId) {
        _annulFromInventory(itemObjectId, fromInventoryObjectId, quantity);
        _ascribeToInventory(itemObjectId, toInventoryObjectId, quantity);
      }
    }

    /**
     * @notice Internal function to ascribe ownership of smart object(s) to an account in the given quantity.
     * @param smartObjectId The smart object id
     * @param to The owner account address
     */
    function _ascribeToAccount(uint256 smartObjectId, address to) internal {
      if (CharactersByAccount.get(to) == 0) {
        revert Ownership_InvalidAccount(to);
      }

      // ascribe the entity to an account
      AccountOwnership.set(smartObjectId, to, AccountOwnership.getQuantity(smartObjectId, to) + 1);
      OwnershipByObject.set(smartObjectId, to);
    }

    /**
     * @notice Internal function to ascribe ownership of smart object(s) to an inventory in the given quantity.
     * @param itemObjectId The smart object id
     * @param inventoryObjectId The inventory object id
     * @param quantity The quantity to ascribe
     */
    function _ascribeToInventory(uint256 itemObjectId, uint256 inventoryObjectId, uint256 quantity) internal {
      if (_isSingleton(itemObjectId)) { // SINGLETON
        if (quantity != 1) {
          revert Ownership_InvalidQuantity(itemObjectId, quantity, 1);
        }
        // Record that this singleton is in the specified inventory
        InventoryByItem.set(itemObjectId, inventoryObjectId);
      } else { // NON-SINGLETON
        if (quantity == 0) {
          revert Ownership_ZeroQuantity(itemObjectId);
        }
      }
      
      // For both singleton and non-singleton items, we need to update account ownership totals
      address inventoryOwner = OwnershipByObject.get(inventoryObjectId);
      // Update account ownership quantity for the inventory owner
      AccountOwnership.setQuantity(
        itemObjectId, 
        inventoryOwner, 
        AccountOwnership.getQuantity(itemObjectId, inventoryOwner) + quantity
      );
    }

    /**
     * @notice Internal function to annul ownership of a singleton smart object from an account.
     * @param smartObjectId The singleton smart object id
     * @param from The current owner account address
     */
    function _annulFromAccount(uint256 smartObjectId, address from) internal {
      // Remove direct ownership reference
      OwnershipByObject.deleteRecord(smartObjectId);
      
      // Update account ownership quantity
      uint256 currentQuantity = AccountOwnership.getQuantity(smartObjectId, from);
      if (currentQuantity == 1) {
        // Removing the only item - delete the record
        AccountOwnership.deleteRecord(smartObjectId, from);
      } else {
        // Reduce quantity (although for singletons this should rarely happen)
        AccountOwnership.setQuantity(smartObjectId, from, currentQuantity - 1);
      }
    }

    function _annulFromInventory(uint256 itemObjectId, uint256 inventoryObjectId, uint256 quantity) internal {
      if (_isSingleton(itemObjectId)) { // SINGLETON
        if (quantity != 1) {
          revert Ownership_InvalidQuantity(itemObjectId, quantity, 1);
        }
        // Delete the record that this singleton is in the specified inventory
        InventoryByItem.deleteRecord(itemObjectId);
      } else { // NON-SINGLETON
        uint256 currentQuantity = InventoryItem.getQuantity(inventoryObjectId, itemObjectId);
        if (quantity == 0) {
          revert Ownership_ZeroQuantity(itemObjectId);
        }
        if (quantity > currentQuantity) {
          revert Ownership_InsufficientQuantity(itemObjectId, quantity, currentQuantity);
        }
      }

      // For both singleton and non-singleton items, we need to update account ownership totals
      address inventoryOwner = OwnershipByObject.get(inventoryObjectId);
      // Decrease account ownership quantity
      uint256 currentAccountQuantity = AccountOwnership.getQuantity(itemObjectId, inventoryOwner);
      if (currentAccountQuantity == quantity) {
        AccountOwnership.deleteRecord(itemObjectId, inventoryOwner);
      } else {
        AccountOwnership.setQuantity(itemObjectId, inventoryOwner, currentAccountQuantity - quantity);
      }
    }

    /**
     * @notice Internal function to check if a smart object is a singleton.
     * @param smartObjectId The smart object id
     * @return True if the smart object is a singleton, false otherwise.
     */
    function _isSingleton(uint256 smartObjectId) internal view returns (bool) {
      // Check if itemId is non-zero to determine if it's a singleton
      return EntityRecord.getItemId(smartObjectId) != 0;
    }

    /**
     * @notice Get the class ID of a smart object.
     * @param smartObjectId The smart object id
     * @return The class ID
     */
    function _getClassId(uint256 smartObjectId) internal view returns (uint256) {
      return uint256(keccak256(abi.encodePacked(EntityRecord.getTypeId(smartObjectId))));
    }
}