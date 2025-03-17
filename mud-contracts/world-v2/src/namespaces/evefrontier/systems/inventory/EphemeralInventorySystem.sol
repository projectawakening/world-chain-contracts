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

  error EphemeralInventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error EphemeralInventory_InvalidTenantId(uint256 smartObjectId, bytes32 tenantId);
  error EphemeralInventory_InvalidItemObjectId(uint256 smartObjectId);
  error EphemeralInventory_InvalidItemDepositQuantity(uint256 smartObjectId, uint256 quantity);
  error EphemeralInventory_NonExistentEntityRecord(string message, uint256 smartObjectId);
  
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

    // update ephemeral inventory version if it is less than the smart object inventory version (if needed)
    if (Inventory.getVersion(ephemeralSmartObjectId) < Inventory.getVersion(smartObjectId)) {
      Inventory.setVersion(ephemeralSmartObjectId, Inventory.getVersion(smartObjectId));
    }

    uint256 usedCapacity = Inventory.getUsedCapacity(ephemeralSmartObjectId);
    uint256 maxCapacity = Inventory.getCapacity(ephemeralSmartObjectId);
    uint256 existingItemsLength = Inventory.getItems(ephemeralSmartObjectId).length;
    
    for (uint256 i = 0; i < items.length; i++) {
        if (!EntityRecord.getExists(items[i].smartObjectId)) { // we expect all items to have an EntityRecord. If not, then they should be called via createAndDeposit first
        revert EphemeralInventory_NonExistentEntityRecord(
          "InventorySystem: non-existent entity record",
          items[i].smartObjectId
        );
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

    // update ephemeral inventory version if it is less than the smart object inventory version
    if (Inventory.getVersion(ephemeralSmartObjectId) < Inventory.getVersion(smartObjectId)) {
      Inventory.setVersion(ephemeralSmartObjectId, Inventory.getVersion(smartObjectId));
    }
    uint256 usedCapacity = Inventory.getUsedCapacity(ephemeralSmartObjectId);
    for (uint256 i = 0; i < items.length; i++) {
      // Process the item withdrawal (returning the updated used capacity after processing the item)
      usedCapacity = _processItemWithdrawal(ephemeralSmartObjectId, items[i], usedCapacity);
    }

    // Update the new aggregate used capacity of the inventory
    Inventory.setUsedCapacity(ephemeralSmartObjectId, usedCapacity);
  }

  /**
   * Internal Functions
   */
  function _processItemDeposit(
    uint256 ephemeralSmartObjectId,
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

    if (!InventoryItem.getExists(ephemeralSmartObjectId, item.smartObjectId)) {
      Inventory.pushItems(ephemeralSmartObjectId, item.smartObjectId);
      InventoryItem.set(ephemeralSmartObjectId, item.smartObjectId, true, 0, itemIndex, Inventory.getVersion(ephemeralSmartObjectId));
    }

    // Adjust ownership/quantity data
    ownershipSystem.ascribeToInventory(ephemeralSmartObjectId, item.smartObjectId, item.quantity);

    return usedCapacity + reqCapacity;
  }

  function _processItemWithdrawal(
    uint256 ephemeralSmartObjectId,
    InventoryItemParams memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemData memory itemData = InventoryItem.get(ephemeralSmartObjectId, item.smartObjectId);

    uint256 existingItemQuantity = InventoryItem.getQuantity(ephemeralSmartObjectId, item.smartObjectId);
    
    // Adjust ownership and quantities
    ownershipSystem.annulFromInventory(ephemeralSmartObjectId, item.smartObjectId, item.quantity);
    
    // remove item if quantity is reduced to 0
    if (item.quantity == existingItemQuantity) {
      _removeItem(ephemeralSmartObjectId, item, itemData);
    }

    return usedCapacity - (EntityRecord.getVolume(item.smartObjectId) * item.quantity);
  }

  function _removeItem(
    uint256 ephemeralSmartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    uint256 length = Inventory.lengthItems(ephemeralSmartObjectId);
    // Only perform swap if this isn't the last item (saves gas)
    if (length > 1 && itemData.index < length - 1) {
      uint256 lastElement = Inventory.getItemItems(ephemeralSmartObjectId, length - 1);
      Inventory.updateItems(ephemeralSmartObjectId, itemData.index, lastElement);
      InventoryItem.setIndex(ephemeralSmartObjectId, lastElement, itemData.index);
    }
    
    Inventory.popItems(ephemeralSmartObjectId);
    InventoryItem.deleteRecord(ephemeralSmartObjectId, item.smartObjectId);
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
        if (items[i].itemId != 0) { // singleton item case
          if (currentTenantId != items[i].tenantId) {
            revert EphemeralInventory_InvalidTenantId(items[i].smartObjectId, items[i].tenantId);
          }
          
          if (items[i].smartObjectId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
            revert EphemeralInventory_InvalidItemObjectId(items[i].smartObjectId);
          }
          
          if (items[i].quantity != 1) {
            revert EphemeralInventory_InvalidItemDepositQuantity(items[i].smartObjectId, items[i].quantity);
          }

          uint256 classId = uint256(keccak256(abi.encodePacked(items[i].typeId)));
          _ensureClassIdExists(classId, items[i].typeId, items[i].volume);
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
      }
      
      // Always populate the output array
      inventoryItems[i] = InventoryItemParams({
        smartObjectId: items[i].smartObjectId,
        quantity: items[i].quantity
      });
    }
    return inventoryItems;
  }

  /**
   * @notice Helper function to ensure a class ID entity record exists
   * @param classId The class ID to check
   * @param typeId The type ID to use if creating the class record
   * @param volume The volume to use if creating the class record
   */
  function _ensureClassIdExists(uint256 classId, uint256 typeId, uint256 volume) internal {
    if (!EntityRecord.getExists(classId)) { // the classId EntityRecord is not created
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
      entityRecordSystem.createRecord(classId, EntityRecordParams({
        tenantId: 0,
        typeId: typeId,
        itemId: 0,
        volume: volume
      }));
    }
  }
}