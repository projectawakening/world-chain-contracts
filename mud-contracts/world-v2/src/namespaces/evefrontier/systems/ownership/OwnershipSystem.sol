// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";

import { CharactersByAccount, EntityRecord, Inventory, InventoryByItem, InventoryItem, OwnershipByObject, InventoryByEphemeral, InventoryByEphemeralData, EphemeralInventory, EphemeralInvItem } from "../../codegen/index.sol";

import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

/**
 * @title OwnershipSystem
 * @notice Core system for managing ownership of smart objects
 * @dev Handles direct ownership assignment and removal
 */
contract OwnershipSystem is SmartObjectFramework {
  // Custom errors
  error Ownership_InvalidSingleton(uint256 smartObjectId);
  error Ownership_InvalidAccount(address account);
  error Ownership_InvalidOwner(uint256 smartObjectId, address invalidOwner);
  error Ownership_NonexistentObject(uint256 smartObjectId);
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

    // Check inventory ownership
    uint256 inventoryObjectId = InventoryByItem.get(smartObjectId);
    if (inventoryObjectId == 0) {
      return address(0);
    }

    // Handle different inventory types
    if (InventoryByEphemeral.getExists(inventoryObjectId)) {
      return getEphemeralOwner(inventoryObjectId, smartObjectId);
    } else {
      return getInventoryOwner(inventoryObjectId, smartObjectId);
    }
  }

  /**
   * @notice assign new ownership of a singleton smart object to an account
   * @param smartObjectId The smart object id to assign ownership
   * @param to The owner account address to assign the smart object to
   */
  function assignOwner(uint256 smartObjectId, address to) public access(smartObjectId) {
    /// Check if the object exists
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
   * @notice remove ownership of a singleton smart object from an account
   * @param smartObjectId The smart object id to remove ownership of
   * @param from The current owner account address
   */
  function removeOwner(uint256 smartObjectId, address from) public access(smartObjectId) {
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
   * @notice Get the owner of an ephemeral inventory
   * @param inventoryObjectId The id of the inventory
   * @param itemObjectId The id of the ephemeral object item
   * @return The owner of the item
   */
  function getEphemeralOwner(uint256 inventoryObjectId, uint256 itemObjectId) public view returns (address) {
    // Get the ephemeral inventory data
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

    // If the current version is the same as the recorded version, return the ephemeral owner
    if (currentVersion == recordedVersion) {
      return inventoryByEphemeralData.ephemeralOwner;
    }

    return address(0);
  }

  /**
   * @notice Get the owner of a standard inventory
   * @param inventoryObjectId The id of the inventory
   * @param itemObjectId The id of the inventory item
   * @return The owner of the item
   */
  function getInventoryOwner(uint256 inventoryObjectId, uint256 itemObjectId) public view returns (address) {
    // Get the current version of the inventory
    uint256 currentVersion = Inventory.getVersion(inventoryObjectId);
    uint256 recordedVersion = InventoryItem.getVersion(inventoryObjectId, itemObjectId);

    // If the current version is the same as the recorded version, return the owner of the inventory
    if (currentVersion == recordedVersion) {
      return OwnershipByObject.get(inventoryObjectId);
    }

    return address(0);
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
