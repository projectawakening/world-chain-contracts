//SPDX-License-Identifier: MIT
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
import { GlobalDeployableState, Tenant, EntityRecord, DeployableState, DeployableStateData, Inventory, InventoryData, InventoryItemData, InventoryItem, InventoryByItem, EphemeralInvCapacity } from "../../codegen/index.sol";

// Local namespace systems
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { inventoryOwnershipSystem } from "../../codegen/systems/InventoryOwnershipSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../entity-record/types.sol";
import { InventoryItemParams, CreateInventoryItemParams } from "./types.sol";
import { State } from "../deployable/types.sol";

/**
 * @title InventorySystem
 * @author CCP Games
 * @notice InventorySystem is an interface for creating and interacting with the primary inventory data associated with a smart object
 */
contract InventorySystem is SmartObjectFramework {
  using WorldResourceIdInstance for ResourceId;

  error Inventory_InvalidCapacity(string message);
  error Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Inventory_InvalidTenantId(uint256 itemObjectId, bytes32 tenantId);
  error Inventory_InvalidItemObjectId(uint256 itemObjectId);
  error Inventory_InvalidItemDepositQuantity(uint256 itemObjectId, uint256 quantity);
  error Inventory_NonExistentEntityRecord(string message, uint256 smartObjectId);

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
   * @notice Set the storage capacity of an inventory associated with `smartObjectId`
   * @param smartObjectId The associated smart object id
   * @param capacity The storage capacity to set for the inventory
   * @dev access control: this function is only callable by the admin role directly or via scoped system call
   */
  function setCapacity(
    uint256 smartObjectId,
    uint256 capacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    // Validate capacity
    if (capacity == 0) {
      revert Inventory_InvalidCapacity("InventorySystem: storage capacity cannot be 0");
    }

    Inventory.setCapacity(smartObjectId, capacity);
  }

  /**
   * @notice Set the storage capacity for all ephemeral inventories associated with `smartObjectId`
   * @param smartObjectId The associated smart object id
   * @param ephemeralCapacity The storage capacity to set for all ephemeral inventories associated with `smartObjectId`
   * @dev access control: this function is only callable by the admin role directly or via scoped system call
   */
  function setEphemeralCapacity(
    uint256 smartObjectId,
    uint256 ephemeralCapacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    EphemeralInvCapacity.setCapacity(smartObjectId, ephemeralCapacity);
  }

  /**
   * @notice Create and deposit items to the inventory
   * @param smartObjectId The associated smart object id
   * @param items The items to create records for and deposit to the inventory
   * @dev access control: this function is only callable by the admin role directly or via scoped system call
   */
  function createAndDepositInventory(
    uint256 smartObjectId,
    CreateInventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    // Create entity records for the items and format input as InventoryItemParams
    InventoryItemParams[] memory inventoryItems = _createEntityRecords(items);
    // Deposit the items
    depositInventory(smartObjectId, inventoryItems);
  }

  /**
   * @notice Deposit items to the inventory
   * @param smartObjectId The associated smart object id
   * @param items The items to deposit to inventory
   * @dev access control: this function is callable by the admin role directly or via scoped system call or by the inventory/ephemeral interact systems
   */
  function depositInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    // Validate state (uses the primary inventory's associated smart object state)
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (currentState == State.NULL || currentState != State.ONLINE) {
        // NOTE: NULL can never be the state of a createdDeployable smart object, so we are using it to pass non-Deployable smart objects
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    uint256 usedCapacity = Inventory.getUsedCapacity(smartObjectId);
    uint256 maxCapacity = Inventory.getCapacity(smartObjectId);

    for (uint256 i = 0; i < items.length; i++) {
      if (!EntityRecord.getExists(items[i].smartObjectId)) {
        // we expect all items to have an EntityRecord. If not, then they should be called via createAndDeposit first
        revert Inventory_NonExistentEntityRecord("InventorySystem: non-existent entity record", items[i].smartObjectId);
      }
      // Process the item deposit (returning the updated used capacity after processing the item)
      usedCapacity = _processItemDeposit(smartObjectId, items[i], usedCapacity, maxCapacity);
    }

    // Update the new aggregate used capacity of the inventory
    Inventory.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /**
   * @notice Withdraw items from the inventory
   * @param smartObjectId The associated smart object id
   * @param items The items to withdraw from the inventory
   * @dev access control: this function is callable by the admin role directly or via scoped system call or by the inventory/ephemeral interact systems
   */
  function withdrawInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    // Validate state (uses the primary inventory's associated smart object state)
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (!(currentState == State.NULL || currentState == State.ANCHORED || currentState == State.ONLINE)) {
        // NOTE: NULL can never be the state of a Deployable smart object, so we are using it to pass non-Deployable smart objects
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    uint256 usedCapacity = Inventory.getUsedCapacity(smartObjectId);
    for (uint256 i = 0; i < items.length; i++) {
      // Process the item withdrawal (returning the updated used capacity after processing the item)
      usedCapacity = _processItemWithdrawal(smartObjectId, items[i], usedCapacity);
    }

    // Update the new aggregate used capacity of the inventory
    Inventory.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /**
   * Internal Functions
   */
  function _processItemDeposit(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    uint256 usedCapacity,
    uint256 maxCapacity
  ) internal returns (uint256) {
    uint256 reqCapacity = EntityRecord.getVolume(item.smartObjectId) * item.quantity;
    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert Inventory_InsufficientCapacity(
        "InventorySystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    if (!InventoryItem.getExists(smartObjectId, item.smartObjectId)) {
      uint256 itemIndex = Inventory.lengthItems(smartObjectId);
      Inventory.pushItems(smartObjectId, item.smartObjectId);
      InventoryItem.set(smartObjectId, item.smartObjectId, true, 0, itemIndex, Inventory.getVersion(smartObjectId));
    }

    // Adjust ownership/quantity data
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, item.smartObjectId, item.quantity);

    return usedCapacity + reqCapacity;
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, item.smartObjectId);

    uint256 existingItemQuantity = InventoryItem.getQuantity(smartObjectId, item.smartObjectId);

    // Adjust ownership and quantities
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, item.smartObjectId, item.quantity);

    // remove item if quantity is reduced to 0
    if (item.quantity == existingItemQuantity) {
      _removeItem(smartObjectId, item, itemData);
    }

    return usedCapacity - (EntityRecord.getVolume(item.smartObjectId) * item.quantity);
  }

  function _removeItem(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    uint256 length = Inventory.lengthItems(smartObjectId);
    // Only perform swap if this isn't the last item (saves gas)
    if (length > 1 && itemData.index < length - 1) {
      uint256 lastElement = Inventory.getItemItems(smartObjectId, length - 1);
      Inventory.updateItems(smartObjectId, itemData.index, lastElement);
      InventoryItem.setIndex(smartObjectId, lastElement, itemData.index);
    }

    Inventory.popItems(smartObjectId);
    InventoryItem.deleteRecord(smartObjectId, item.smartObjectId);
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
            revert Inventory_InvalidTenantId(items[i].smartObjectId, items[i].tenantId);
          }

          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
            revert Inventory_InvalidItemObjectId(items[i].smartObjectId);
          }

          if (items[i].quantity != 1) {
            revert Inventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
          }

          uint256 classId = uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].typeId)));
          _ensureClassIdExists(classId, items[i].tenantId, items[i].typeId, items[i].volume);
        } else {
          // non-singleton item case
          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].typeId)))) {
            revert Inventory_InvalidItemObjectId(items[i].smartObjectId);
          }

          if (items[i].quantity == 0) {
            revert Inventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
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
