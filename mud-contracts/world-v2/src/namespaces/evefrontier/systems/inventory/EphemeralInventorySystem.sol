// SPDX-License-Identifier: MIT
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
  DeployableState, 
  DeployableStateData,
  Inventory,
  EphemeralInvCapacity,
  EntityRecord,
  ObjectByEphemeral,
  InventoryItem,
  InventoryItemData,
  Tenant
} from "../../codegen/index.sol";

// Local namespace systems
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
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

  error EphemeralInventory_NonExistentEntityRecord(string message, uint256 smartObjectId);
  error EphemeralInventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error EphemeralInventory_InvalidItemWithdrawalQuantity(string message, uint256 smartObjectId, uint256 quantity, uint256 maxQuantity);
  error EphemeralInventory_InvalidTenantId(uint256 smartObjectId, bytes32 tenantId);
  error EphemeralInventory_InvalidItemObjectId(uint256 smartObjectId);
  error EphemeralInventory_InvalidItemDepositQuantity(uint256 smartObjectId, uint256 quantity);
  
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
   * @notice Generate a unique ephemeral smart object id given an associated smart object and ephemeral owner
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
    // Validate state (uses the associated smart object's state). This entails that the associated smart object exists and is anchored or online.
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (!(currentState == State.NULL || currentState == State.ANCHORED || currentState == State.ONLINE)) {
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    // Generate ephemeral inventory object id
    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(smartObjectId, ephemeralOwner);
    
    // Link the ephemeral inventory object to the associated smart object (if needed)
    if (ObjectByEphemeral.getSmartObjectId(ephemeralSmartObjectId) == 0) {
      ObjectByEphemeral.set(ephemeralSmartObjectId, smartObjectId);
    }

    // Ascribe ephemeral inventory ownership to the account owner (if needed)
    if (ownershipSystem.owner(ephemeralSmartObjectId) == address(0)) {
      ownershipSystem.ascribeToAccount(ephemeralSmartObjectId, ephemeralOwner);
    }

    // Ensure Inventory capacity for this ephemeral object is set if EphemeralInvCapacity is set (if needed)
    uint256 ephemeralCapacity = EphemeralInvCapacity.getCapacity(smartObjectId);
    if (ephemeralCapacity != 0 && Inventory.getCapacity(ephemeralSmartObjectId) == 0) {
      inventorySystem.setCapacity(ephemeralSmartObjectId, ephemeralCapacity);
    }

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    uint256 usedCapacity = Inventory.getUsedCapacity(ephemeralSmartObjectId);
    uint256 maxCapacity = Inventory.getCapacity(ephemeralSmartObjectId);
    uint256 existingItemsLength = Inventory.getItems(ephemeralSmartObjectId).length;
    
    for (uint256 i = 0; i < items.length; i++) {
      if (!EntityRecord.getExists(items[i].smartObjectId)) { // we expect all items to have an EntityRecord. If not, then they should be called via createAndDeposit first
        revert EphemeralInventory_NonExistentEntityRecord(
          "EphemeralInventorySystem: non-existent entity record",
          items[i].smartObjectId
        );
      }
      // Direct calls represent new items being moved onto the chain from the game world simulation
      if(callCount == 1) {
        // Ascribe item ownership to the ephemeral inventory
        ownershipSystem.ascribeToInventory(items[i].smartObjectId, ephemeralSmartObjectId, items[i].quantity);
      } else {
        // Transfer item ownership from the object's primary inventory to the ephemeral inventory
        ownershipSystem.transferInventory(items[i].smartObjectId, ephemeralSmartObjectId, items[i].quantity);
      }

      // Process the item deposit (returning the updated used capacity after processing the item)
      uint256 itemIndex = existingItemsLength + i;
      usedCapacity = _processItemDeposit(ephemeralSmartObjectId, items[i], usedCapacity, maxCapacity, itemIndex);
    }

    // Update the new aggregate used capacity of the inventory
    Inventory.setUsedCapacity(ephemeralSmartObjectId, usedCapacity);
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
      if (!(currentState == State.NULL || currentState == State.ANCHORED || currentState == State.ONLINE)) { // NOTE: NULL can never be the state of a Deployable smart object, so we are using it for non-Deployable smart objects
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    // Generate ephemeral inventory object id
    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(smartObjectId, ephemeralOwner);

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    uint256 usedCapacity = Inventory.getUsedCapacity(ephemeralSmartObjectId);

    for (uint256 i = 0; i < items.length; i++) {
      // Process the item withdrawal (returning the updated used capacity after processing the item)
      usedCapacity = _processItemWithdrawal(ephemeralSmartObjectId, items[i], usedCapacity);
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
      revert EphemeralInventory_InsufficientCapacity(
        "EphemeralInventorySystem: insufficient capacity",
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
      revert EphemeralInventory_InvalidItemWithdrawalQuantity("EphemeralInventorySystem: invalid quantity", item.smartObjectId, item.quantity, itemData.quantity);
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
      revert EphemeralInventory_InvalidItemWithdrawalQuantity("EphemeralInventorySystem: invalid quantity", item.smartObjectId, item.quantity, 0);
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
        if (items[i].itemId != 0) { // singleton item case
          if (Tenant.get() != items[i].tenantId) {
            revert EphemeralInventory_InvalidTenantId(items[i].smartObjectId, items[i].tenantId);
          }
          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
            revert EphemeralInventory_InvalidItemObjectId(items[i].smartObjectId);
          } 
          if (items[i].quantity != 1) {
            revert EphemeralInventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
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
            revert EphemeralInventory_InvalidItemObjectId(items[i].smartObjectId);
          }
          if (items[i].quantity == 0) {
            revert EphemeralInventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
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
