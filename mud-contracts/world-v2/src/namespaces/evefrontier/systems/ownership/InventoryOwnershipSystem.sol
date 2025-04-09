// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";

// Local namespace tables
import { CharactersByAccount, EntityRecord, Inventory, InventoryByItem, InventoryItem, OwnershipByObject, InventoryByEphemeral, InventoryByEphemeralData, EphemeralInventory, EphemeralInvItem } from "../../codegen/index.sol";

// Local namespace systems
import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

/**
 * @title InventoryOwnershipSystem
 * @notice Manages ownership of items within inventories
 * @dev Handles both regular and ephemeral inventory ownership
 */
contract InventoryOwnershipSystem is SmartObjectFramework {
  // Custom errors
  error InventoryOwnership_Ephemeral_InsufficientQuantity(
    uint256 inventoryObjectId,
    address ephemeralOwner,
    uint256 itemObjectId,
    uint256 providedQuantity,
    uint256 availableQuantity
  );
  error InventoryOwnership_InvalidQuantity(uint256 itemObjectId, uint256 providedQuantity, uint256 expectedQuantity);
  error InventoryOwnership_ZeroQuantity(uint256 itemObjectId);
  error InventoryOwnership_InsufficientQuantity(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 providedQuantity,
    uint256 availableQuantity
  );
  error InventoryOwnership_InvalidInventory(uint256 itemObjectId, uint256 inventoryObjectId);
  error InventoryOwnership_NonexistentItemRecord(uint256 itemObjectId);
  error InventoryOwnership_NonexistentObject(uint256 objectId);
  error InventoryOwnership_InvalidOperation(string message);
  error InventoryOwnership_SingletonAlreadyAssigned(uint256 itemObjectId, uint256 currentInventoryObjectId);
  error InventoryOwnership_SingletonDirectlyOwned(uint256 itemObjectId, address directOwner);

  /**
   * @notice Assign ownership of item(s) to an inventory associated with a specific smart object
   * @param inventoryObjectId The smart object id associated with the destination inventory
   * @param itemObjectId The smart object id of the item to assign
   * @param quantity The quantity to assign
   * @dev This function handles both regular and ephemeral inventories
   */
  function assignItemToInventory(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 quantity
  ) public access(inventoryObjectId) {
    // Validate inputs
    if (quantity == 0) {
      revert InventoryOwnership_ZeroQuantity(itemObjectId);
    }

    // Validate item exists
    if (!EntityRecord.getExists(itemObjectId)) {
      revert InventoryOwnership_NonexistentItemRecord(itemObjectId);
    }

    // Validate inventory exists
    if (!(Entity.getExists(inventoryObjectId) || InventoryByEphemeral.getExists(inventoryObjectId))) {
      revert InventoryOwnership_NonexistentObject(inventoryObjectId);
    }

    // Handle singleton items
    if (_isSingleton(itemObjectId)) {
      if (quantity != 1) {
        revert InventoryOwnership_InvalidQuantity(itemObjectId, quantity, 1);
      }

      // ownership checks
      address directOwner = OwnershipByObject.get(itemObjectId);
      // Check if the singleton item is directly owned by an account
      if (directOwner != address(0)) {
        revert InventoryOwnership_SingletonDirectlyOwned(itemObjectId, directOwner);
      }

      uint256 currentInventoryId = InventoryByItem.get(itemObjectId);
      // Check if the singleton is already assigned to another inventory
      if (currentInventoryId != 0 && currentInventoryId != inventoryObjectId) {
        revert InventoryOwnership_SingletonAlreadyAssigned(itemObjectId, currentInventoryId);
      }

      // Only set if not already assigned to this inventory (minor optimization)
      if (currentInventoryId != inventoryObjectId) {
        InventoryByItem.set(itemObjectId, inventoryObjectId);
      }
    }

    // Update inventory based on type
    if (InventoryByEphemeral.getExists(inventoryObjectId)) {
      _updateEphemeralInventory(inventoryObjectId, itemObjectId, quantity);
    } else {
      _updateRegularInventory(inventoryObjectId, itemObjectId, quantity);
    }
  }

  /**
   * @notice Remove ownership of item(s) from an inventory associated with a specific smart object
   * @param inventoryObjectId The smart object id associated with the source inventory
   * @param itemObjectId The smart object id of the item to remove
   * @param quantity The quantity to remove
   * @dev This function handles both regular and ephemeral inventories
   */
  function removeItemFromInventory(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 quantity
  ) public access(inventoryObjectId) {
    // Validate inputs
    if (quantity == 0) {
      revert InventoryOwnership_ZeroQuantity(itemObjectId);
    }

    // Handle singleton items
    if (_isSingleton(itemObjectId)) {
      if (InventoryByItem.get(itemObjectId) != inventoryObjectId) {
        revert InventoryOwnership_InvalidInventory(itemObjectId, inventoryObjectId);
      }
      if (quantity != 1) {
        revert InventoryOwnership_InvalidQuantity(itemObjectId, quantity, 1);
      }
      InventoryByItem.deleteRecord(itemObjectId);
    }

    // Remove from inventory based on type
    if (InventoryByEphemeral.getExists(inventoryObjectId)) {
      _removeFromEphemeralInventory(inventoryObjectId, itemObjectId, quantity);
    } else {
      _removeFromRegularInventory(inventoryObjectId, itemObjectId, quantity);
    }
  }

  /**
   * @notice Internal function to update ephemeral inventory
   * @param inventoryObjectId The ephemeral inventory object id
   * @param itemObjectId The item object id
   * @param quantity The quantity to add
   */
  function _updateEphemeralInventory(uint256 inventoryObjectId, uint256 itemObjectId, uint256 quantity) internal {
    InventoryByEphemeralData memory inventoryByEphemeralData = InventoryByEphemeral.get(inventoryObjectId);
    uint256 existingItemQuantity = EphemeralInvItem.getQuantity(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner,
      itemObjectId
    );
    uint256 currentVersion = EphemeralInventory.getVersion(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner
    );
    uint256 recordedVersion = EphemeralInvItem.getVersion(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner,
      itemObjectId
    );
    bool versionChanged = currentVersion > recordedVersion;

    // Update quantity and version
    EphemeralInvItem.setQuantity(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner,
      itemObjectId,
      versionChanged ? quantity : existingItemQuantity + quantity
    );

    if (versionChanged) {
      EphemeralInvItem.setVersion(
        inventoryByEphemeralData.smartObjectId,
        inventoryByEphemeralData.ephemeralOwner,
        itemObjectId,
        currentVersion
      );
    }
  }

  /**
   * @notice Internal function to update regular inventory
   * @param inventoryObjectId The inventory object id
   * @param itemObjectId The item object id
   * @param quantity The quantity to add
   */
  function _updateRegularInventory(uint256 inventoryObjectId, uint256 itemObjectId, uint256 quantity) internal {
    uint256 existingItemQuantity = InventoryItem.getQuantity(inventoryObjectId, itemObjectId);
    uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
    uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);
    bool versionChanged = currentVersion > recordedVersion;

    // Update quantity and version
    InventoryItem.setQuantity(
      inventoryObjectId,
      itemObjectId,
      versionChanged ? quantity : existingItemQuantity + quantity
    );

    if (versionChanged) {
      InventoryItem.setVersion(inventoryObjectId, itemObjectId, currentVersion);
    }
  }

  /**
   * @notice Internal function to remove items from ephemeral inventory
   * @param inventoryObjectId The ephemeral inventory object id
   * @param itemObjectId The item object id
   * @param quantity The quantity to remove
   */
  function _removeFromEphemeralInventory(uint256 inventoryObjectId, uint256 itemObjectId, uint256 quantity) internal {
    InventoryByEphemeralData memory inventoryByEphemeralData = InventoryByEphemeral.get(inventoryObjectId);
    uint256 currentVersion = EphemeralInventory.getVersion(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner
    );
    uint256 recordedVersion = EphemeralInvItem.getVersion(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner,
      itemObjectId
    );
    uint256 existingItemQuantity = currentVersion > recordedVersion
      ? 0
      : EphemeralInvItem.getQuantity(
        inventoryByEphemeralData.smartObjectId,
        inventoryByEphemeralData.ephemeralOwner,
        itemObjectId
      );

    if (existingItemQuantity < quantity) {
      revert InventoryOwnership_Ephemeral_InsufficientQuantity(
        inventoryByEphemeralData.smartObjectId,
        inventoryByEphemeralData.ephemeralOwner,
        itemObjectId,
        quantity,
        existingItemQuantity
      );
    }

    EphemeralInvItem.setQuantity(
      inventoryByEphemeralData.smartObjectId,
      inventoryByEphemeralData.ephemeralOwner,
      itemObjectId,
      existingItemQuantity - quantity
    );
  }

  /**
   * @notice Internal function to remove items from regular inventory
   * @param inventoryObjectId The inventory object id
   * @param itemObjectId The item object id
   * @param quantity The quantity to remove
   */
  function _removeFromRegularInventory(uint256 inventoryObjectId, uint256 itemObjectId, uint256 quantity) internal {
    uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
    uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);
    uint256 existingItemQuantity = currentVersion > recordedVersion
      ? 0
      : InventoryItem.getQuantity(inventoryObjectId, itemObjectId);

    if (existingItemQuantity < quantity) {
      revert InventoryOwnership_InsufficientQuantity(inventoryObjectId, itemObjectId, quantity, existingItemQuantity);
    }

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
