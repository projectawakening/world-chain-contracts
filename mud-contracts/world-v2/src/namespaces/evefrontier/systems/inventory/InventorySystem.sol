//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { 
  GlobalDeployableState, 
  Inventory, 
  Tenant, 
  EntityRecord, 
  DeployableState, 
  DeployableStateData, 
  InventoryItemData, 
  InventoryItem,
  InventoryByItem,
  EphemeralInvCapacity
} from "../../codegen/index.sol";

// Local namespace systems
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";

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
  error Inventory_InvalidItemWithdrawalQuantity(string message, uint256 itemSmartObjectId, uint256 quantity, uint256 maxQuantity);
  error Inventory_NonExistentEntityRecord(string message, uint256 smartObjectId);

  /**
   * modifier to enforce inventory changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (!GlobalDeployableState.getIsPaused()) {
      revert DeployableSystem.Deployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * @notice Set the storage capacity of an inventory associated with `smartObjectId`
   * @param smartObjectId The associated smart object id
   * @param capacity The storage capacity to set for the inventory
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
   */
  function depositInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    // Validate state (uses the primary inventory's associated smart object state)
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (currentState == State.NULL || currentState != State.ONLINE) { // NOTE: NULL can never be the state of a createdDeployable smart object, so we are using it to pass non-Deployable smart objects
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    uint256 usedCapacity = Inventory.getUsedCapacity(smartObjectId);
    uint256 maxCapacity = Inventory.getCapacity(smartObjectId);
    uint256 existingItemsLength = Inventory.getItems(smartObjectId).length;
    
    for (uint256 i = 0; i < items.length; i++) {
        if (!EntityRecord.getExists(items[i].smartObjectId)) { // we expect all items to have an EntityRecord. If not, then they should be called via createAndDeposit first
        revert Inventory_NonExistentEntityRecord(
          "InventorySystem: non-existent entity record",
          items[i].smartObjectId
        );
      }
      // Direct calls represent new items being moved onto the chain from the game world simulation
      if(callCount == 1) {
        // Ascribe item ownership to the inventory
        ownershipSystem.ascribeToInventory(items[i].smartObjectId, smartObjectId, items[i].quantity);
      } else {
        // Transfer item ownership to this inventory from the previous inventory
        ownershipSystem.transferInventory(items[i].smartObjectId, smartObjectId, items[i].quantity);
      }

      // Process the item deposit (returning the updated used capacity after processing the item)
      uint256 itemIndex = existingItemsLength + i;
      usedCapacity = _processItemDeposit(smartObjectId, items[i], usedCapacity, maxCapacity, itemIndex);
    }

    // Update the new aggregate used capacity of the inventory
    Inventory.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /**
   * @notice Withdraw items from the inventory
   * @param smartObjectId The associated smart object id
   * @param items The items to withdraw from inventory
   */
  function withdrawInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    // Validate state (uses the primary inventory's associated smart object state)
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (!(currentState == State.NULL || currentState == State.ANCHORED || currentState == State.ONLINE)) { // NOTE: NULL can never be the state of a Deployable smart object, so we are using it to pass non-Deployable smart objects
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    uint256 usedCapacity = Inventory.getUsedCapacity(smartObjectId);

    for (uint256 i = 0; i < items.length; i++) {
      // Process the item withdrawal (returning the updated used capacity after processing the item)
      usedCapacity = _processItemWithdrawal(smartObjectId, items[i], usedCapacity);
      // Direct calls represent items leaving the chain to the game world simulation
      if(callCount == 1) { // a direct call
        // Annul ownership tracking
        ownershipSystem.annulFromInventory(items[i].smartObjectId, smartObjectId, items[i].quantity);
      }
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
    uint256 maxCapacity,
    uint256 itemIndex
  ) internal returns (uint256) {
    uint256 reqCapacity = EntityRecord.getVolume(item.smartObjectId) * item.quantity;
    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert Inventory_InsufficientCapacity(
        "InventorySystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    _updateInventoryAfterDeposit(smartObjectId, item, itemIndex);
    return usedCapacity + reqCapacity;
  }

  function _updateInventoryAfterDeposit(uint256 smartObjectId, InventoryItemParams memory item, uint256 itemIndex) internal {
    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, item.smartObjectId);
    // Validate associated deployable state.
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    // Create a new item if the item storage entry does not exist or if the associated smart object has been re-anchored since the last deposit
    if (itemData.stateUpdate == 0 || itemData.stateUpdate < deployableStateData.anchoredAt) {
      // Item is new or associated with a smart object has been re-anchored since the last deposit
      _depositNewItem(smartObjectId, item, itemIndex);
    } else {
      // Deployable has not been re-anchored and item exists in the inventory
      _increaseItemQuantity(smartObjectId, item, itemData.index);
    }
  }

  /**
   * @notice Increase the quantity of an item in the inventory
   * @dev Increase the quantity of an item in the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param item The item to increase the quantity
   */
  function _increaseItemQuantity(uint256 smartObjectId, InventoryItemParams memory item, uint256 itemIndex) internal {
    uint256 quantity = InventoryItem.getQuantity(smartObjectId, item.smartObjectId);
    InventoryItem.set(smartObjectId, item.smartObjectId, quantity + item.quantity, itemIndex, block.timestamp);
  }

  function _depositNewItem(uint256 smartObjectId, InventoryItemParams memory item, uint256 itemIndex) internal {
    Inventory.pushItems(smartObjectId, item.smartObjectId);
    InventoryItem.set(smartObjectId, item.smartObjectId, item.quantity, itemIndex, block.timestamp);
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, item.smartObjectId);
    
    _validateWithdrawal(item, itemData);
    _updateInventoryAfterWithdrawal(smartObjectId, item, itemData);

    return usedCapacity - (EntityRecord.getVolume(item.smartObjectId) * item.quantity);
  }

  function _validateWithdrawal(InventoryItemParams memory item, InventoryItemData memory itemData) internal pure {
    if (item.quantity > itemData.quantity) {
      revert Inventory_InvalidItemWithdrawalQuantity("InventorySystem: invalid quantity", item.smartObjectId, item.quantity, itemData.quantity);
    }
  }

  function _updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    // Validate associated deployable state.
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    if (itemData.stateUpdate < deployableStateData.anchoredAt) {
      // Cannot withdraw any items if there have been no deposit actions since the inventory was last re-anchored (re-anchoring treats this as a new inventory)
      revert Inventory_InvalidItemWithdrawalQuantity("InventorySystem: invalid quantity", item.smartObjectId, item.quantity, 0);
    } else {
      // Deployable has not been re-anchored since item data was last updated and item exists in the inventory
      if (item.quantity == itemData.quantity) {
        _removeItemCompletely(smartObjectId, item, itemData);
      } else if (item.quantity < itemData.quantity) {
        _reduceItemQuantity(smartObjectId, item, itemData);
      }
    }
  }

  function _removeItemCompletely(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    uint256[] memory inventoryItems = Inventory.getItems(smartObjectId);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    Inventory.updateItems(smartObjectId, itemData.index, lastElement);
    Inventory.popItems(smartObjectId);

    //when a last element is swapped, change the index of the last element in the InventoryItem Table
    InventoryItem.setIndex(smartObjectId, lastElement, itemData.index);
    InventoryItem.deleteRecord(smartObjectId, item.smartObjectId);
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    InventoryItem.set(
      smartObjectId,
      item.smartObjectId,
      itemData.quantity - item.quantity,
      itemData.index,
      block.timestamp
    );
  }

  function _createEntityRecords(
    CreateInventoryItemParams[] memory items
  ) internal returns (InventoryItemParams[] memory) {
    InventoryItemParams[] memory inventoryItems = new InventoryItemParams[](items.length);
    for (uint256 i = 0; i < items.length; i++) {
      // only create entity records for items that don't already exist
      if (!EntityRecord.getExists(items[i].smartObjectId)) {
        // item sanity checks
        if (Tenant.get() != items[i].tenantId) {
          revert Inventory_InvalidTenantId(items[i].smartObjectId, items[i].tenantId);
        }
        if (items[i].itemId != 0) { // singleton item case
          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
            revert Inventory_InvalidItemObjectId(items[i].smartObjectId);
          } 
          if (items[i].quantity != 1) {
            revert Inventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
          }

          uint256 classId = uint256(keccak256(abi.encodePacked(items[i].typeId)));
          if (!EntityRecord.getExists(classId)) { // the classId EntityRecord is not created
            if (!Entity.getExists(classId)) {
              // register the classId with the `evefrontier namespace owner as the default CLASS_ACCESS_ROLE member
              // TODO: after data validation implementation, revisit this:
              // - consider using the CCP Games data signer instead of the namespace owner
              // - alternatively we could setup a specifc role and member for this purpose
              // - alternatively, we could block this call with a revert unless classId is already registered, and thereby requiring all classes to be pre-configured
              entitySystem.scopedRegisterClass(classId, NamespaceOwner.getOwner(SystemRegistry.get(address(this)).getNamespaceId()), new ResourceId[](0));
            }
            // Create an EntityRecord for the classId if it doesn't exist
            if (!EntityRecord.getExists(classId)) {
              entityRecordSystem.createRecord(classId, EntityRecordParams({
                tenantId: 0,
                typeId: items[i].typeId,
                itemId: 0,
                volume: items[i].volume
              }));
            }
          }
        } else { // non-singleton item case
          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].typeId)))) {
            revert Inventory_InvalidItemObjectId(items[i].smartObjectId);
          }
          if (items[i].quantity == 0) {
            revert Inventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
          }
        }

        entityRecordSystem.createRecord(items[i].smartObjectId, EntityRecordParams({
          tenantId: items[i].tenantId,
          typeId: items[i].typeId,
          itemId: items[i].itemId,
          volume: items[i].volume
        }));

        inventoryItems[i] = InventoryItemParams({
          smartObjectId: items[i].smartObjectId,
          quantity: items[i].quantity
        });
      }
    }
    return inventoryItems;
  }
}
