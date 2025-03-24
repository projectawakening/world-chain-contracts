// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";

// Local namespace tables
import { CharactersByAccount, EntityRecord, Inventory, InventoryByItem, InventoryItem, OwnershipByObject, ObjectByEphemeral, ObjectByEphemeralData, EphemeralInventory, EphemeralInvItem } from "../../codegen/index.sol";

// Local namespace systems
import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

contract OwnershipSystem is SmartObjectFramework {
  // Custom errors
  error Ownership_InvalidQuantity(uint256 itemObjectId, uint256 providedQuantity, uint256 expectedQuantity);
  error Ownership_ZeroQuantity(uint256 itemObjectId);
  error Inventory_InsufficientQuantity(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 providedQuantity,
    uint256 availableQuantity
  );
  error EphemeralInventory_InsufficientQuantity(
    uint256 inventoryObjectId,
    address ephemeralOwner,
    uint256 itemObjectId,
    uint256 providedQuantity,
    uint256 availableQuantity
  );
  error Ownership_InvalidSingleton(uint256 smartObjectId);
  error Ownership_InvalidAccount(address account);
  error Ownership_InvalidOwner(uint256 smartObjectId, address invalidOwner);
  error Ownership_NonexistentItemRecord(uint256 itemObjectId);
  error Ownership_NonexistentObject(uint256 smartObjectId);
  error Ownership_InvalidInventory(uint256 itemObjectId, uint256 inventoryObjectId);
  error Ownership_AlreadyOwned(uint256 smartObjectId, address currentOwner);

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

    uint256 inventoryObjectId = InventoryByItem.get(smartObjectId);

    // Check if the inventoryObjectId is an ephemeral inventory object
    uint256 currentVersion;
    uint256 recordedVersion;
    if (ObjectByEphemeral.getExists(inventoryObjectId)) {
      // yes, it is an ephemeral inventory
      ObjectByEphemeralData memory objectByEphemeralData = ObjectByEphemeral.get(inventoryObjectId);
      currentVersion = EphemeralInventory.getVersion(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner
      );
      recordedVersion = EphemeralInvItem.getVersion(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner,
        smartObjectId
      );
      if (currentVersion == recordedVersion) {
        return objectByEphemeralData.ephemeralOwner;
      }
    } else {
      // no, it is not an ephemeral inventory
      currentVersion = Inventory.getVersion(inventoryObjectId);
      recordedVersion = InventoryItem.getVersion(inventoryObjectId, smartObjectId);
      if (currentVersion == recordedVersion) {
        return OwnershipByObject.get(inventoryObjectId);
      }
    }

    return address(0);
  }

  /**
   * @notice Assign new ownership of a singleton smart object to an account
   * @param smartObjectId The smart object id to assign ownership of
   * @param to The owner account address to assign the smart object to
   */
  function assignToAccount(uint256 smartObjectId, address to) public access(smartObjectId) {
    // Check if the object exists
    if (!Entity.getExists(smartObjectId)) {
      revert Ownership_NonexistentObject(smartObjectId);
    }

    // Check if the account is valid
    if (_callMsgSender() != smartCharacterSystem.getAddress() && CharactersByAccount.get(to) == 0) {
      revert Ownership_InvalidAccount(to);
    }

    // Check if the object is a singleton
    if (!_isSingleton(smartObjectId)) {
      revert Ownership_InvalidSingleton(smartObjectId);
    }

    // Check if the object is already assigned to an account
    address currentOwner = OwnershipByObject.get(smartObjectId);
    if (currentOwner != address(0)) {
      revert Ownership_AlreadyOwned(smartObjectId, currentOwner);
    }

    // Assign ownership of the singleton smart object to the defined account
    OwnershipByObject.set(smartObjectId, to);
  }

  /**
   * @notice Remove ownership of a singleton smart object from an account
   * @param smartObjectId The smart object id to remove ownership of
   * @param from The current owner account address
   */
  function removeFromAccount(uint256 smartObjectId, address from) public access(smartObjectId) {
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
   * @notice Assign ownership of item(s) to an inventory associated with a specific smart object
   * @param inventoryObjectId The smart object id associated with the destination inventory
   * @param itemObjectId The smart object id of the item to assign
   * @param quantity The quantity to assign
   */
  function assignToInventory(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 quantity
  ) public access(inventoryObjectId) {
    // sanity checks
    if (!EntityRecord.getExists(itemObjectId)) {
      revert Ownership_NonexistentItemRecord(itemObjectId);
    }

    if (!(Entity.getExists(inventoryObjectId) || ObjectByEphemeral.getExists(inventoryObjectId))) {
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
    uint256 existingItemQuantity;
    uint256 currentVersion;
    uint256 recordedVersion;
    bool versionChanged;
    if (ObjectByEphemeral.getExists(inventoryObjectId)) {
      // yes, it is an ephemeral inventory
      ObjectByEphemeralData memory objectByEphemeralData = ObjectByEphemeral.get(inventoryObjectId);
      existingItemQuantity = EphemeralInvItem.getQuantity(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner,
        itemObjectId
      );
      currentVersion = EphemeralInventory.getVersion(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner
      );
      recordedVersion = EphemeralInvItem.getVersion(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner,
        itemObjectId
      );
      versionChanged = currentVersion > recordedVersion;

      // Update ephemeral inventory quantity for this item
      EphemeralInvItem.setQuantity(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner,
        itemObjectId,
        uint256(versionChanged ? quantity : existingItemQuantity + quantity)
      );
      if (versionChanged) {
        // if the version has changed, update the version
        EphemeralInvItem.setVersion(
          objectByEphemeralData.smartObjectId,
          objectByEphemeralData.ephemeralOwner,
          itemObjectId,
          currentVersion
        );
      }
    } else {
      // no, it is not an ephemeral inventory
      existingItemQuantity = InventoryItem.getQuantity(inventoryObjectId, itemObjectId);
      currentVersion = Inventory.getVersion(inventoryObjectId);
      recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);
      versionChanged = currentVersion > recordedVersion;

      // Update inventory quantity for this item
      InventoryItem.setQuantity(
        inventoryObjectId,
        itemObjectId,
        uint256(versionChanged ? quantity : existingItemQuantity + quantity)
      );
      if (versionChanged) {
        // if the version has changed, update the version
        InventoryItem.setVersion(inventoryObjectId, itemObjectId, currentVersion);
      }
    }
  }

  /**
   * @notice Remove ownership of item(s) from an inventory associated with a specific smart object.
   * @param inventoryObjectId The smart object id associated with the source inventory
   * @param itemObjectId The smart object id of the item to remove
   * @param quantity The quantity to remove
   */
  function removeFromInventory(
    uint256 inventoryObjectId,
    uint256 itemObjectId,
    uint256 quantity
  ) public access(inventoryObjectId) {
    // sanity checks
    if (_isSingleton(itemObjectId)) {
      if (InventoryByItem.get(itemObjectId) != inventoryObjectId) {
        revert Ownership_InvalidInventory(itemObjectId, inventoryObjectId);
      } else {
        InventoryByItem.deleteRecord(itemObjectId);
      }
      if (quantity != 1) {
        revert Ownership_InvalidQuantity(itemObjectId, quantity, 1);
      }
    } else {
      if (quantity == 0) {
        revert Ownership_ZeroQuantity(itemObjectId);
      }
    }

    if (ObjectByEphemeral.getExists(inventoryObjectId)) {
      // yes, it is an ephemeral inventory
      ObjectByEphemeralData memory objectByEphemeralData = ObjectByEphemeral.get(inventoryObjectId);
      uint256 currentVersion = EphemeralInventory.getVersion(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner
      );
      uint256 recordedVersion = EphemeralInvItem.getVersion(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner,
        itemObjectId
      );
      uint256 existingItemQuantity = currentVersion > recordedVersion
        ? 0
        : EphemeralInvItem.getQuantity(
          objectByEphemeralData.smartObjectId,
          objectByEphemeralData.ephemeralOwner,
          itemObjectId
        );

      // safety check
      if (existingItemQuantity < quantity) {
        revert EphemeralInventory_InsufficientQuantity(
          objectByEphemeralData.smartObjectId,
          objectByEphemeralData.ephemeralOwner,
          itemObjectId,
          quantity,
          existingItemQuantity
        );
      }

      // Update inventory quantity for this item
      EphemeralInvItem.setQuantity(
        objectByEphemeralData.smartObjectId,
        objectByEphemeralData.ephemeralOwner,
        itemObjectId,
        existingItemQuantity - quantity
      );
    } else {
      // no, it is not an ephemeral inventory
      uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
      uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);
      uint256 existingItemQuantity = currentVersion > recordedVersion
        ? 0
        : InventoryItem.getQuantity(inventoryObjectId, itemObjectId);

      // safety check
      if (existingItemQuantity < quantity) {
        revert Inventory_InsufficientQuantity(inventoryObjectId, itemObjectId, quantity, existingItemQuantity);
      }

      // Update inventory quantity for this item
      InventoryItem.setQuantity(inventoryObjectId, itemObjectId, existingItemQuantity - quantity);
    }
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
