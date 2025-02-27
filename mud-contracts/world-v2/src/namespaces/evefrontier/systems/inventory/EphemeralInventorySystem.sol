// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { InventorySystem } from "./InventorySystem.sol";
import { GlobalDeployableState } from "../../codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../codegen/tables/EphemeralInvItem.sol";
import { EphemeralInv } from "../../codegen/tables/EphemeralInv.sol";
import { EphemeralInvCapacity } from "../../codegen/tables/EphemeralInvCapacity.sol";
import { CharactersByAddress } from "../../codegen/tables/CharactersByAddress.sol";
import { EntityRecord, EntityRecordData } from "../../codegen/index.sol";
import { EntityRecordData as EntityRecordStruct } from "../entity-record/types.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";

import { InventoryItemParams } from "./types.sol";
import { InventorySystem } from "./InventorySystem.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

/**
 * @title EphemeralInventorySystem
 * @author CCP Games
 * @notice EphemeralInventorySystem stores the ephemeral inventory of a smart object on-chain
 */
contract EphemeralInventorySystem is SmartObjectFramework {
  error InvalidEphemeralInventoryOwner(string message, address ephemeralInvOwner);
  error Ephemeral_Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Ephemeral_Inventory_InvalidCapacity(string message);
  error Ephemeral_Inventory_InvalidItem(string message, uint256 inventoryItemId);
  error Ephemeral_Inventory_InvalidItemQuantity(string message, uint256 quantity, uint256 maxQuantity);

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
   * @notice Set the ephemeral inventory capacity
   * @dev Set the ephemeral inventory capacity by smart storage unit id
   * //TODO Only owner of the smart storage unit can set the capacity
   * @param smartObjectId The smart storage unit id
   * @param ephemeralStorageCapacity The storage capacity
   */
  function setEphemeralInventoryCapacity(
    uint256 smartObjectId,
    uint256 ephemeralStorageCapacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (ephemeralStorageCapacity == 0) {
      revert Ephemeral_Inventory_InvalidCapacity("EphemeralInventorySystem: storage capacity cannot be 0");
    }
    EphemeralInvCapacity.setCapacity(smartObjectId, ephemeralStorageCapacity);
  }

  /**
   * @notice Create and deposit items to the ephemeral inventory
   * @dev Create and deposit items to the ephemeral inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param ephemeralInventoryOwner The owner of the ephemeral inventory
   * @param items The items to deposit to the inventory
   * NOTE: This function assumes that the owner is assigned as the _callMsgSender(1)
   */
  function createAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    for (uint256 i = 0; i < items.length; i++) {
      // item sanity checks
      if (!EntityRecordTenant.getExists(items[i].tenantId)) {
        revert EphemeralInventory_InvalidTenantId(items[i].inventoryItemId, items[i].tenantId);
      }
      if (items[i].itemId != 0) { // singleton item case
        if (items[i].inventoryItemId != uint256(keccak256(abi.encodePacked(items[i].tenantId, items[i].itemId)))) {
          revert EphemeralInventory_InvalidInventoryItemId(items[i].inventoryItemId);
        } 
        if (items[i].quantity != 1) {
          revert EphemeralInventory_InvalidItemQuantity(items[i].inventoryItemId, items[i].quantity);
        }
      } else { // non-singleton item case
        if (items[i].inventoryItemId != uint256(keccak256(abi.encodePacked(items[i].typeId)))) {
          revert EphemeralInventory_InvalidInventoryItemId(items[i].inventoryItemId);
        }
        if (items[i].quantity == 0) {
          revert EphemeralInventory_InvalidItemQuantity(items[i].inventoryItemId, 0);
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
        entitySystem.instantiate(classId, items[i].inventoryItemId, ephemeralInventoryOwner);
      }

      entityRecordSystem.createEntityRecord(items[i].inventoryItemId, entityRecord);
    }

    depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
  }

  /**
   * @notice Deposit items to the ephemeral inventory
   * @dev Deposit items to the ephemeral inventory by smart storage unit id
   * //TODO msg.sender should be the ephemeralInventoryOwner
   * @param smartObjectId The smart storage unit id
   * @param ephemeralInventoryOwner The owner of the ephemeral inventory
   * @param items The items to deposit to the inventory
   */
  function depositToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (currentState != State.ONLINE) {
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }
    // ephemeralInventoryOwner must be an existing character
    if (CharactersByAddress.get(ephemeralInventoryOwner) == 0) {
      revert InvalidEphemeralInventoryOwner(
        "EphemeralInventorySystem: provided ephemeralInventoryOwner is not a valid address",
        ephemeralInventoryOwner
      );
    }

    uint256 totalUsedCapacity = _processAndReturnTotalUsedCapacity(smartObjectId, ephemeralInventoryOwner, items);

    EphemeralInv.setUsedCapacity(smartObjectId, ephemeralInventoryOwner, totalUsedCapacity);
  }

  /**
   * @notice Withdraw items from the ephemeral inventory
   * @dev Withdraw items from the ephemeral inventory by smart storage unit id
   * //TODO msg.sender should be the item owner
   * @param smartObjectId The smart storage unit id
   * @param ephemeralInventoryOwner The owner of the inventory
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
      revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
    }
    uint256 usedCapacity = EphemeralInv.getUsedCapacity(smartObjectId, ephemeralInventoryOwner);
    for (uint256 i = 0; i < items.length; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, ephemeralInventoryOwner, items[i], usedCapacity);

      // if the item is a singleton and the call is direct, delete the item from the chain
      uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
      if (callCount == 1 && EntityRecord.getItemId(items[i].inventoryItemId) != 0) {
        bytes32 itemOwnerRole = keccak256(abi.encodePacked("OWNER_ROLE", items[i].inventoryItemId));
        roleManagementSystem.scopedRevokeAll(items[i].inventoryItemId, itemOwnerRole);
        entitySystem.deleteObject(items[i].inventoryItemId);
      }
    }
    EphemeralInv.setUsedCapacity(smartObjectId, ephemeralInventoryOwner, usedCapacity);
  }

  function _processAndReturnTotalUsedCapacity(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams[] memory items
  ) internal returns (uint256) {
    uint256 usedCapacity = EphemeralInv.getUsedCapacity(smartObjectId, ephemeralInventoryOwner);
    uint256 totalUsedCapacity = usedCapacity;
    uint256 maxCapacity = EphemeralInvCapacity.getCapacity(smartObjectId);

    uint256 existingItemsLength = EphemeralInv.getItems(smartObjectId, ephemeralInventoryOwner).length;

    for (uint256 i = 0; i < items.length; i++) {
      // Revert if the items to deposit do not have a recorded objectId
      if (!Entity.getExists(items[i].inventoryItemId)) {
        revert Inventory_InvalidItem("EphemeralInventorySystem: item is not created on-chain", items[i].inventoryItemId);
      }
      // Revert if the items to deposit do not have an entity record
      EntityRecordData memory entityRecord = EntityRecord.get(items[i].inventoryItemId);
      if (entityRecord.recordExists == false) {
        revert Ephemeral_Inventory_InvalidItem(
          "EphemeralInventorySystem: item does not have an on-chain record",
          items[i].typeId
        );
      }

      uint256 itemIndex = existingItemsLength + i;
      totalUsedCapacity = _processItemDeposit(
        smartObjectId,
        ephemeralInventoryOwner,
        items[i],
        totalUsedCapacity,
        maxCapacity,
        itemIndex
      );
      bytes32 itemOwnerRole = keccak256(abi.encodePacked("OWNER_ROLE", items[i].inventoryItemId));

      // remove all old item owner information
      roleManagementSystem.scopedRevokeAll(items[i].inventoryItemId, itemOwnerRole);
      // assign the ephemeralinventory owner as the item owner
      roleManagementSystem.scopedGrantRole(items[i].inventoryItemId, itemOwnerRole, ephemeralInventoryOwner);
    }

    return totalUsedCapacity;
  }

  function _processItemDeposit(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    uint256 usedCapacity,
    uint256 maxCapacity,
    uint256 index
  ) internal returns (uint256) {
    uint256 reqCapacity = item.volume * item.quantity;

    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert Ephemeral_Inventory_InsufficientCapacity(
        "EphemeralInventorySystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }
    _updateEphemeralInvAfterDeposit(smartObjectId, ephemeralInventoryOwner, item, index);
    return usedCapacity + reqCapacity;
  }

  function _updateEphemeralInvAfterDeposit(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    uint256 itemIndex
  ) internal {
    EphemeralInvItemData memory itemData = EphemeralInvItem.get(
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner
    );

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    //Valid deployable state. Create new item if the item does not exist in the inventory or its has been re-anchored
    if (itemData.stateUpdate == 0 || itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Item does not exist in the inventory
      _depositNewItem(smartObjectId, ephemeralInventoryOwner, item, itemIndex);
    } else {
      //Deployable is valid and item exists in the inventory
      _increaseItemQuantity(smartObjectId, ephemeralInventoryOwner, item, itemData.index);
    }
  }

  function _increaseItemQuantity(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    uint256 index
  ) internal {
    uint256 quantity = EphemeralInvItem.getQuantity(smartObjectId, item.inventoryItemId, ephemeralInventoryOwner);

    EphemeralInvItem.set(
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner,
      quantity + item.quantity,
      index,
      block.timestamp
    );
  }

  function _depositNewItem(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    uint256 index
  ) internal {
    EphemeralInv.pushItems(smartObjectId, ephemeralInventoryOwner, item.inventoryItemId);
    EphemeralInvItem.set(
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner,
      item.quantity,
      index,
      block.timestamp
    );
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    EphemeralInvItemData memory itemData = EphemeralInvItem.get(
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner
    );

    _validateWithdrawal(item, itemData);
    _updateInventoryAfterWithdrawal(smartObjectId, ephemeralInventoryOwner, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function _validateWithdrawal(InventoryItemParams memory item, EphemeralInvItemData memory itemData) internal pure {
    if (item.quantity > itemData.quantity) {
      revert Ephemeral_Inventory_InvalidItemQuantity(
        "EphemeralInventorySystem: invalid quantity",
        itemData.quantity,
        item.quantity
      );
    }
  }

  function _updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    EphemeralInvItemData memory itemData
  ) internal {
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    if (itemData.stateUpdate < deployableStateData.anchoredAt) {
      // Disable withdraw if its has been re-anchored
      revert Ephemeral_Inventory_InvalidItemQuantity(
        "EphemeralInventorySystem: invalid quantity",
        smartObjectId,
        item.quantity
      );
    } else {
      //Deployable is valid and item exists in the inventory
      if (item.quantity == itemData.quantity) {
        _removeItemCompletely(smartObjectId, ephemeralInventoryOwner, item, itemData);
      } else if (item.quantity < itemData.quantity) {
        _reduceItemQuantity(smartObjectId, ephemeralInventoryOwner, item, itemData);
      }
    }
  }

  function _removeItemCompletely(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    EphemeralInvItemData memory itemData
  ) internal {
    uint256[] memory inventoryItems = EphemeralInv.getItems(smartObjectId, ephemeralInventoryOwner);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    EphemeralInv.updateItems(smartObjectId, ephemeralInventoryOwner, itemData.index, lastElement);
    EphemeralInv.popItems(smartObjectId, ephemeralInventoryOwner);

    //when a last element is swapped, change the index of the last element in the EphemeralInvItem
    EphemeralInvItem.setIndex(smartObjectId, lastElement, ephemeralInventoryOwner, itemData.index);
    EphemeralInvItem.deleteRecord(smartObjectId, item.inventoryItemId, ephemeralInventoryOwner);
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItemParams memory item,
    EphemeralInvItemData memory itemData
  ) internal {
    EphemeralInvItem.set(
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner,
      itemData.quantity - item.quantity,
      itemData.index,
      block.timestamp
    );
  }
}
