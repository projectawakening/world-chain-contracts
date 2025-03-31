// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { GlobalDeployableState, DeployableState, Inventory, EphemeralInvCapacity, EphemeralInventory, EphemeralInvItem, EphemeralInvItemData, EntityRecord, InventoryByEphemeral, Tenant, OwnershipByObject } from "../../codegen/index.sol";

// Local namespace systems
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { inventoryOwnershipSystem } from "../../codegen/systems/InventoryOwnershipSystemLib.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { DeployableSystem } from "../deployable/DeployableSystem.sol";

// Types and parameters
import { CreateInventoryItemParams, InventoryItemParams } from "./types.sol";
import { EntityRecordParams } from "../entity-record/types.sol";
import { State } from "../deployable/types.sol";

/**
 * @title EphemeralInventorySystem
 * @author CCP Games
 * @notice EphemeralInventorySystem provides ephemeral inventory functionality
 *
 * NOTE: Ephemeral inventories are owned by a specific player and track items separately than the primary smart object inventory. We create an ephemeral smart object for each player and use that epheemral smart object id to track the inventory.
 */
contract EphemeralInventorySystem is SmartObjectFramework {
  using WorldResourceIdInstance for ResourceId;

  error EphemeralInventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error EphemeralInventory_InvalidTenantId(uint256 smartObjectId, bytes32 tenantId);
  error EphemeralInventory_InvalidItemObjectId(uint256 smartObjectId);
  error EphemeralInventory_InvalidItemDepositQuantity(uint256 smartObjectId, uint256 quantity);
  error EphemeralInventory_NonExistentEntityRecord(string message, uint256 smartObjectId);
  error EphemeralInventory_InvalidSmartObjectId(uint256 smartObjectId);
  error EphemeralInventory_InvalidEphemeralOwner(uint256 smartObjectId, address ephemeralOwner);
  /**
   * modifier to enforce inventory changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused()) {
      revert DeployableSystem.Deployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * @notice Generate a unique ephemeral smart object id given an associated smart object and ephemeral owner (this is used for ownership data tracking)
   * @param smartObjectId The associated smart object id
   * @param ephemeralOwner The ephemeral owner address
   * @return A unique ephemeral smart object id
   */
  function getEphemeralSmartObjectId(uint256 smartObjectId, address ephemeralOwner) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(smartObjectId, ephemeralOwner)));
  }

  /**
   * @notice Create and deposit items to the ephemeral inventory
   * @param smartObjectId The associated smart object id
   * @param ephemeralOwner The owner of the ephemeral inventory object
   * @param items The items to create records for and deposit to the ephemeral inventory
   */
  function createAndDepositEphemeral(
    uint256 smartObjectId,
    address ephemeralOwner,
    CreateInventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    // Ensure the entity exists
    if (!Entity.getExists(smartObjectId)) {
      revert EphemeralInventory_InvalidSmartObjectId(smartObjectId);
    }

    // Ensure the smartObjectId is an ownership assigned object
    if (OwnershipByObject.getAccount(smartObjectId) == address(0)) {
      revert EphemeralInventory_InvalidSmartObjectId(smartObjectId);
    }

    // Set entity records and format input as InventoryItemParams
    InventoryItemParams[] memory inventoryItems = _createEntityRecords(items);
    // Deposit the items
    depositEphemeral(smartObjectId, ephemeralOwner, inventoryItems);
  }

  /**
   * @notice Deposit items to the ephemeral inventory
   * @param smartObjectId The associated smart object id
   * @param ephemeralOwner The owner of the ephemeral inventory object
   * @param items The items to deposit to ephemeral inventory
   */
  function depositEphemeral(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    // Ensure the entity exists
    if (!Entity.getExists(smartObjectId)) {
      revert EphemeralInventory_InvalidSmartObjectId(smartObjectId);
    }

    // Ensure the smartObjectId is not itself an ephemeral object
    if (OwnershipByObject.get(smartObjectId) == address(0)) {
      revert EphemeralInventory_InvalidSmartObjectId(smartObjectId);
    }

    // Validate state (uses the associated smart object's state). This entails that the associated smart object exists and is anchored or online.
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (!(currentState == State.NULL || currentState == State.ONLINE)) {
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    if (ephemeralOwner == OwnershipByObject.getAccount(smartObjectId)) {
      revert EphemeralInventory_InvalidEphemeralOwner(smartObjectId, ephemeralOwner);
    }

    // Generate ephemeral inventory object id
    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(smartObjectId, ephemeralOwner);

    // Link the ephemeral inventory object to the associated smart object (if needed)
    if (!InventoryByEphemeral.getExists(ephemeralSmartObjectId)) {
      // Store mapping from ephemeral ID to associated smart object and owner
      InventoryByEphemeral.set(ephemeralSmartObjectId, true, smartObjectId, ephemeralOwner);
    }

    // update ephemeral inventory capacity if it is not set and the smart object has an ephemeral capacity set
    if (
      EphemeralInventory.getCapacity(smartObjectId, ephemeralOwner) == 0 && EphemeralInvCapacity.get(smartObjectId) > 0
    ) {
      EphemeralInventory.setCapacity(smartObjectId, ephemeralOwner, EphemeralInvCapacity.get(smartObjectId));
    }

    // update ephemeral inventory version if it is less than the smart object inventory version along with the used capacity (if needed)
    if (EphemeralInventory.getVersion(smartObjectId, ephemeralOwner) < Inventory.getVersion(smartObjectId)) {
      EphemeralInventory.setVersion(smartObjectId, ephemeralOwner, Inventory.getVersion(smartObjectId));
      EphemeralInventory.setUsedCapacity(smartObjectId, ephemeralOwner, 0);
    }

    uint256 usedCapacity = EphemeralInventory.getUsedCapacity(smartObjectId, ephemeralOwner);
    uint256 maxCapacity = EphemeralInventory.getCapacity(smartObjectId, ephemeralOwner);

    for (uint256 i = 0; i < items.length; i++) {
      if (!EntityRecord.getExists(items[i].smartObjectId)) {
        // we expect all items to have an EntityRecord. If not, then they should be called via createAndDeposit first
        revert EphemeralInventory_NonExistentEntityRecord(
          "InventorySystem: non-existent entity record",
          items[i].smartObjectId
        );
      }
      // Process the item deposit (returning the updated used capacity after processing the item)
      usedCapacity = _processItemDeposit(smartObjectId, ephemeralOwner, items[i], usedCapacity, maxCapacity);
    }

    // Update the new aggregate used capacity of the inventory
    EphemeralInventory.setUsedCapacity(smartObjectId, ephemeralOwner, usedCapacity);
  }

  /**
   * @notice Withdraw items from the ephemeral inventory
   * @param smartObjectId The associated smart object id
   * @param ephemeralOwner The owner of the ephemeral inventory
   * @param items The items to withdraw from ephemeral inventory
   */
  function withdrawEphemeral(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    // Validate state (uses the associated smart object's state. This entails that the associated smart object exists and is anchored or online.
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (!(currentState == State.NULL || currentState == State.ANCHORED || currentState == State.ONLINE)) {
        // NOTE: NULL can never be the state of a Deployable smart object, so we are using it for non-Deployable smart objects
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    // update ephemeral inventory version if it is less than the smart object inventory version
    if (EphemeralInventory.getVersion(smartObjectId, ephemeralOwner) < Inventory.getVersion(smartObjectId)) {
      EphemeralInventory.setVersion(smartObjectId, ephemeralOwner, Inventory.getVersion(smartObjectId));
    }

    uint256 usedCapacity = EphemeralInventory.getUsedCapacity(smartObjectId, ephemeralOwner);
    for (uint256 i = 0; i < items.length; i++) {
      // Process the item withdrawal (returning the updated used capacity after processing the item)
      usedCapacity = _processItemWithdrawal(smartObjectId, ephemeralOwner, items[i], usedCapacity);
    }

    // Update the new aggregate used capacity of the inventory
    EphemeralInventory.setUsedCapacity(smartObjectId, ephemeralOwner, usedCapacity);
  }

  /**
   * Internal Functions
   */
  function _processItemDeposit(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams memory item,
    uint256 usedCapacity,
    uint256 maxCapacity
  ) internal returns (uint256) {
    uint256 reqCapacity = EntityRecord.getVolume(item.smartObjectId) * item.quantity;
    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert EphemeralInventory_InsufficientCapacity(
        "EphemeralInventorySystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    if (!EphemeralInvItem.getExists(smartObjectId, ephemeralOwner, item.smartObjectId)) {
      uint256 itemIndex = EphemeralInventory.lengthItems(smartObjectId, ephemeralOwner);
      EphemeralInventory.pushItems(smartObjectId, ephemeralOwner, item.smartObjectId);
      EphemeralInvItem.set(
        smartObjectId,
        ephemeralOwner,
        item.smartObjectId,
        true,
        0,
        itemIndex,
        EphemeralInventory.getVersion(smartObjectId, ephemeralOwner)
      );
    }

    // Adjust ownership/quantity data
    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(smartObjectId, ephemeralOwner);
    inventoryOwnershipSystem.assignItemToInventory(ephemeralSmartObjectId, item.smartObjectId, item.quantity);

    return usedCapacity + reqCapacity;
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    EphemeralInvItemData memory itemData = EphemeralInvItem.get(smartObjectId, ephemeralOwner, item.smartObjectId);

    // Adjust ownership and quantities
    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(smartObjectId, ephemeralOwner);
    inventoryOwnershipSystem.removeItemFromInventory(ephemeralSmartObjectId, item.smartObjectId, item.quantity);

    // remove item if quantity is reduced to 0
    if (item.quantity == itemData.quantity) {
      _removeItem(smartObjectId, ephemeralOwner, item, itemData);
    }

    return usedCapacity - (EntityRecord.getVolume(item.smartObjectId) * item.quantity);
  }

  function _removeItem(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams memory item,
    EphemeralInvItemData memory itemData
  ) internal {
    uint256 length = EphemeralInventory.lengthItems(smartObjectId, ephemeralOwner);
    // Only perform swap if this isn't the last item (saves gas)
    if (length > 1 && itemData.index < length - 1) {
      uint256 lastElement = EphemeralInventory.getItemItems(smartObjectId, ephemeralOwner, length - 1);
      EphemeralInventory.updateItems(smartObjectId, ephemeralOwner, itemData.index, lastElement);
      EphemeralInvItem.setIndex(smartObjectId, ephemeralOwner, lastElement, itemData.index);
    }

    EphemeralInventory.popItems(smartObjectId, ephemeralOwner);
    EphemeralInvItem.deleteRecord(smartObjectId, ephemeralOwner, item.smartObjectId);
  }

  function _createEntityRecords(
    CreateInventoryItemParams[] memory items
  ) internal returns (InventoryItemParams[] memory) {
    InventoryItemParams[] memory inventoryItems = new InventoryItemParams[](items.length);
    bytes32 currentTenantId = Tenant.get(); // Cache tenant ID - only read once

    for (uint256 i = 0; i < items.length; i++) {
      // only create entity records for items that don't already exist
      if (!EntityRecord.getExists(items[i].smartObjectId)) {
        // item sanity checks
        if (items[i].itemId != 0) {
          // singleton item case
          if (currentTenantId != items[i].tenantId) {
            revert EphemeralInventory_InvalidTenantId(items[i].smartObjectId, items[i].tenantId);
          }

          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
            revert EphemeralInventory_InvalidItemObjectId(items[i].smartObjectId);
          }

          if (items[i].quantity != 1) {
            revert EphemeralInventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
          }

          uint256 classId = uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].typeId)));
          _ensureClassIdExists(classId, items[i].tenantId, items[i].typeId, items[i].volume);
        } else {
          // non-singleton item case
          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].typeId)))) {
            revert EphemeralInventory_InvalidItemObjectId(items[i].smartObjectId);
          }

          if (items[i].quantity == 0) {
            revert EphemeralInventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
          }
        }

        entityRecordSystem.createRecord(
          items[i].smartObjectId,
          EntityRecordParams({
            tenantId: items[i].tenantId,
            typeId: items[i].typeId,
            itemId: items[i].itemId,
            volume: items[i].volume
          })
        );
      }

      // Always populate the output array
      inventoryItems[i] = InventoryItemParams({ smartObjectId: items[i].smartObjectId, quantity: items[i].quantity });
    }
    return inventoryItems;
  }

  /**
   * @notice Helper function to ensure a class ID entity record exists
   * @param classId The class ID to check
   * @param typeId The type ID to use if creating the class record
   * @param volume The volume to use if creating the class record
   */
  function _ensureClassIdExists(uint256 classId, bytes32 tenantId, uint256 typeId, uint256 volume) internal {
    if (!EntityRecord.getExists(classId)) {
      // the classId EntityRecord is not created
      if (!Entity.getExists(classId)) {
        // register the classId with the namespace owner as the default CLASS_ACCESS_ROLE member
        // TODO: after data validation implementation, revisit this:
        // - consider using the CCP Games data signer instead of the namespace owner
        // - alternatively we could setup a specifc role and member for this purpose
        // - alternatively, we could block this call with a revert unless classId is already registered, and thereby requiring all classes to be pre-configured
        entitySystem.scopedRegisterClass(
          classId,
          NamespaceOwner.getOwner(SystemRegistry.get(address(this)).getNamespaceId()),
          new ResourceId[](0)
        );
      }

      // Create an EntityRecord for the classId
      entityRecordSystem.createRecord(
        classId,
        EntityRecordParams({ tenantId: tenantId, typeId: typeId, itemId: 0, volume: volume })
      );
    }
  }
}
