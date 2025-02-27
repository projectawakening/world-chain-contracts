//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { Inventory } from "../../codegen/index.sol";
import { EntityRecord, EntityRecordData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { InventoryItemData, InventoryItem } from "../../codegen/index.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordParams } from "../entity-record/types.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";

import { InventoryItemParams } from "./types.sol";
import { State } from "../deployable/types.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { Role } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";
import { InventoryUtils } from "./InventoryUtils.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

/**
 * @title InventorySystem
 * @author CCP Games
 * @notice InventorySystem stores the inventory of a smart object on-chain
 */
contract InventorySystem is SmartObjectFramework {
  error Inventory_InvalidCapacity(string message);
  error Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Inventory_InvalidItemQuantity(string message, uint256 quantity, uint256 maxQuantity);
  error Inventory_InvalidItem(string message, uint256 inventoryItemId);
  error Inventory_InvalidItemOwner(
    string message,
    uint256 inventoryItemId,
    address providedItemOwner,
    address expectedOwner
  );
  error Inventory_InvalidDeployable(string message, uint256 deployableId);

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused() == false) {
      revert DeployableSystem.Deployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * @notice sets the inventory capacity of a smart object
   * @dev sets the inventory capacity of a smart object
   * @param smartObjectId on-chain id of the in-game object
   * @param capacity the capacity of the inventory
   * //TODO : onlyAdmin
   */
  function setInventoryCapacity(
    uint256 smartObjectId,
    uint256 capacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (capacity == 0) {
      revert Inventory_InvalidCapacity("InventorySystem: storage capacity cannot be 0");
    }

    bytes32 adminAccessRole = InventoryUtils.getAdminAccessRole(smartObjectId);
    if (!Role.getExists(adminAccessRole)) {
      roleManagementSystem.createRole(adminAccessRole, adminAccessRole);
    }

    bytes32 depositAccessRole = InventoryUtils.getEphemeralToInventoryTransferAccessRole(smartObjectId);

    if (!Role.getExists(depositAccessRole)) {
      roleManagementSystem.createRole(depositAccessRole, adminAccessRole);
    }

    bytes32 withdrawAccessRole = InventoryUtils.getInventoryToEphemeralTransferAccessRole(smartObjectId);

    if (!Role.getExists(withdrawAccessRole)) {
      roleManagementSystem.createRole(withdrawAccessRole, adminAccessRole);
    }

    roleManagementSystem.grantRole(adminAccessRole, _callMsgSender(1));

    Inventory.setCapacity(smartObjectId, capacity);
  }

  /**
   * @notice Create and deposit items to the inventory
   * @dev Create and deposit items to the inventory by smart object
   * @param smartObjectId on-chain id of the in-game object
   * @param items array of InventoryItemParams structs
   */
  function createAndDepositItemsToInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive access(smartObjectId) scope(smartObjectId) {
    bytes32 ownerRole = keccak256(abi.encodePacked("OWNER_ROLE", smartObjectId));
    address inventoryOwner = Role.getMembers(ownerRole)[0];
    for (uint256 i = 0; i < items.length; i++) {
      // item sanity checks
      if (!Tenants.getExists(items[i].tenantId)) {
        revert Inventory_InvalidTenantId(items[i].inventoryItemId, items[i].tenantId);
      }
      if (items[i].itemId != 0) { // singleton item case
        if (items[i].inventoryItemId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
          revert Inventory_InvalidInventoryItemId(items[i].inventoryItemId);
        } 
        if (items[i].quantity != 1) {
          revert Inventory_InvalidItemInputQuantity(items[i].inventoryItemId, items[i].quantity);
        }
      } else { // non-singleton item case
        if (items[i].inventoryItemId != uint256(keccak256(abi.encodePacked(items[i].typeId)))) {
          revert Inventory_InvalidInventoryItemId(items[i].inventoryItemId);
        }
        if (items[i].quantity == 0) {
          revert Inventory_InvalidItemInputQuantity(items[i].inventoryItemId, 0);
        }
      }

      EntityRecordParams memory entityRecordParams = EntityRecordParams({
        typeId: items[i].typeId,
        itemId: items[i].itemId,
        volume: items[i].volume,
        tenantId: items[i].tenantId
      });

      uint256 classId = uint256(uint256(keccak256(abi.encodePacked(items[i].typeId))));
      if (!Entity.getExists(classId)) {
        // TODO: ater data validation implementation, consider using the CCP Games data signer instead of the namespace owner
        // alternatively, we could block this call with a revert unless classId is already registered, and thereby requiring all classes to be pre-configured
        entitySystem.scopedRegisterClass(classId, NamespaceOwner.getOwner(SystemRegistry.get(address(this)).getNamespaceId()), new ResourceId[](0));
      }
      if (items[i].itemId != 0) {
        entitySystem.instantiate(classId, items[i].inventoryItemId, inventoryOwner);
      }

      entityRecordSystem.createEntityRecord(items[i].inventoryItemId, entityRecord);
    }

    depositToInventory(smartObjectId, items);
  }

  /**
   * @notice Deposit items to the inventory
   * @dev Deposit items to the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param items The items to deposit to the inventory
   */
  function depositToInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (currentState != State.ONLINE) {
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }
    
    uint256 totalUsedCapacity = _processAndReturnUsedCapacity(smartObjectId, items);

    Inventory.setUsedCapacity(smartObjectId, totalUsedCapacity);
  }

  /**
   * @notice Withdraw items from the inventory
   * @dev Withdraw items from the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromInventory(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }

    uint256 usedCapacity = Inventory.getUsedCapacity(smartObjectId);

    for (uint256 i = 0; i < items.length; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, items[i], usedCapacity);

      // if the item is a singleton and the call is direct, delete the item from the chain
      uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
      if (callCount == 1 && EntityRecord.getItemId(items[i].smartObjectId) != 0) {
        bytes32 itemOwnerRole = keccak256(abi.encodePacked("OWNER_ROLE", items[i].ismartObjectId));
        roleManagementSystem.scopedRevokeAll(items[i].smartObjectId, itemOwnerRole);
        entitySystem.deleteObject(items[i].smartObjectId);
      }
    }

    Inventory.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /**
   * Internal Functions
   */
  function _processAndReturnUsedCapacity(
    uint256 smartObjectId,
    InventoryItemParams[] memory items
  ) internal returns (uint256) {
    uint256 totalUsedCapacity = Inventory.getUsedCapacity(smartObjectId);
    uint256 maxCapacity = Inventory.getCapacity(smartObjectId);

    uint256 existingItemsLength = Inventory.getItems(smartObjectId).length;

    bytes32 inventoryOwnerRole = keccak256(abi.encodePacked("OWNER_ROLE", smartObjectId));
    address inventoryOwner = Role.getMembers(inventoryOwnerRole)[0];

    for (uint256 i = 0; i < items.length; i++) {
      // Revert if the items to deposit do not have a recorded objectId
      if (!Entity.getExists(items[i].inventoryItemId)) {
        revert Inventory_InvalidItem("InventorySystem: item is not created on-chain", items[i].inventoryItemId);
      }
      // Revert if the items to deposit do not have an entity record
      EntityRecordData memory entityRecord = EntityRecord.get(items[i].inventoryItemId);
      if (entityRecord.recordExists == false) {
        revert Inventory_InvalidRecord("InventorySystem: item does not have an on-chain record", items[i].inventoryItemId);
      }

      //If there are inventory items that already exist for the smartObjectId, then the itemIndex is the length of the inventoryItems + i
      uint256 itemIndex = existingItemsLength + i;
      totalUsedCapacity = _processItemDeposit(smartObjectId, items[i], totalUsedCapacity, maxCapacity, itemIndex);

      bytes32 itemOwnerRole = keccak256(abi.encodePacked("OWNER_ROLE", items[i].inventoryItemId));

      // remove all old item owner information
      roleManagementSystem.scopedRevokeAll(items[i].inventoryItemId, itemOwnerRole);
      // assign the inventory owner as the item owner
      roleManagementSystem.scopedGrantRole(items[i].inventoryItemId, itemOwnerRole, inventoryOwner);
    }
    return totalUsedCapacity;
  }

  function _processItemDeposit(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    uint256 usedCapacity,
    uint256 maxCapacity,
    uint256 itemIndex
  ) internal returns (uint256) {
    uint256 reqCapacity = item.volume * item.quantity;
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
    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, item.inventoryItemId);

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    //Valid deployable state. Create new item if the item does not exist in the inventory or its has been re-anchored
    if (itemData.stateUpdate == 0 || itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Item does not exist in the inventory
      _depositNewItem(smartObjectId, item, itemIndex);
    } else {
      //Deployable is valid and item exists in the inventory
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
    uint256 quantity = InventoryItem.getQuantity(smartObjectId, item.inventoryItemId);
    InventoryItem.set(smartObjectId, item.inventoryItemId, quantity + item.quantity, itemIndex, block.timestamp);
  }

  function _depositNewItem(uint256 smartObjectId, InventoryItemParams memory item, uint256 itemIndex) internal {
    Inventory.pushItems(smartObjectId, item.inventoryItemId);
    InventoryItem.set(smartObjectId, item.inventoryItemId, item.quantity, itemIndex, block.timestamp);
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, item.inventoryItemId);
    _validateWithdrawal(item, itemData);

    _updateInventoryAfterWithdrawal(smartObjectId, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function _validateWithdrawal(InventoryItemParams memory item, InventoryItemData memory itemData) internal pure {
    if (item.quantity > itemData.quantity) {
      revert Inventory_InvalidItemQuantity("InventorySystem: invalid quantity", itemData.quantity, item.quantity);
    }
  }

  function _updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    if (itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Disable withdraw if its has been re-anchored
      revert Inventory_InvalidItemQuantity("InventorySystem: invalid quantity", smartObjectId, item.quantity);
    } else {
      //Deployable is valid and item exists in the inventory
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
    InventoryItem.deleteRecord(smartObjectId, item.inventoryItemId);
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItemParams memory item,
    InventoryItemData memory itemData
  ) internal {
    InventoryItem.set(
      smartObjectId,
      item.inventoryItemId,
      itemData.quantity - item.quantity,
      itemData.index,
      block.timestamp
    );
  }
}
