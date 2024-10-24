// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

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
import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";

import { InventoryItem } from "./types.sol";
import { InventorySystem } from "./InventorySystem.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { EveSystem } from "../EveSystem.sol";

/**
 * @title EphemeralInventorySystem
 * @author CCP Games
 * @notice EphemeralInventorySystem stores the ephemeral inventory of a smart object on-chain
 */
contract EphemeralInventorySystem is EveSystem {
  error InvalidEphemeralInventoryOwner(string message, address ephemeralInvOwner);
  error Ephemeral_Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Ephemeral_Inventory_InvalidCapacity(string message);
  error Ephemeral_Inventory_InvalidItem(string message, uint256 inventoryItemId);
  error Ephemeral_Inventory_InvalidItemQuantity(string message, uint256 quantity, uint256 maxQuantity);

  ResourceId entityRecordSystemId = EntityRecordUtils.entityRecordSystemId();

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
  function setEphemeralInventoryCapacity(uint256 smartObjectId, uint256 ephemeralStorageCapacity) public {
    if (ephemeralStorageCapacity == 0) {
      revert Ephemeral_Inventory_InvalidCapacity("EphemeralInventorySystem: storage capacity cannot be 0");
    }
    EphemeralInvCapacity.setCapacity(smartObjectId, ephemeralStorageCapacity);
  }

  /**
   * @notice Create and deposit items to the ephemeral inventory
   * @dev Create and deposit items to the ephemeral inventory by smart storage unit id
   * //TODO only owner should be able to create and deposit items
   * @param smartObjectId The smart storage unit id
   * @param ephemeralInventoryOwner The owner of the ephemeral inventory
   * @param items The items to deposit to the inventory
   */
  function createAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    for (uint256 i = 0; i < items.length; i++) {
      EntityRecordStruct memory entityRecord = EntityRecordStruct({
        typeId: items[i].typeId,
        itemId: items[i].itemId,
        volume: items[i].volume
      });
      world().call(
        entityRecordSystemId,
        abi.encodeCall(EntityRecordSystem.createEntityRecord, (items[i].inventoryItemId, entityRecord))
      );
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
    InventoryItem[] memory items
  ) public {
    {
      State currentState = DeployableState.getCurrentState(smartObjectId);
      if (currentState != State.ONLINE) {
        revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
      }
    }
    // ephemeralInventoryOwner MUST be an existing character
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
    InventoryItem[] memory items
  ) public {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
      revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
    }
    uint256 usedCapacity = EphemeralInv.getUsedCapacity(smartObjectId, ephemeralInventoryOwner);
    for (uint256 i = 0; i < items.length; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, ephemeralInventoryOwner, items[i], usedCapacity);
    }
    EphemeralInv.setUsedCapacity(smartObjectId, ephemeralInventoryOwner, usedCapacity);
  }

  function _processAndReturnTotalUsedCapacity(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) internal returns (uint256) {
    uint256 usedCapacity = EphemeralInv.getUsedCapacity(smartObjectId, ephemeralInventoryOwner);
    uint256 totalUsedCapacity = usedCapacity;
    uint256 maxCapacity = EphemeralInvCapacity.getCapacity(smartObjectId);

    uint256 existingItemsLength = EphemeralInv.getItems(smartObjectId, ephemeralInventoryOwner).length;

    for (uint256 i = 0; i < items.length; i++) {
      //Revert if the items to deposit is not created on-chain
      EntityRecordData memory entityRecord = EntityRecord.get(items[i].inventoryItemId);
      if (entityRecord.recordExists == false) {
        revert Ephemeral_Inventory_InvalidItem(
          "EphemeralInventorySystem: item is not created on-chain",
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
    }

    return totalUsedCapacity;
  }

  function _processItemDeposit(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem memory item,
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
    InventoryItem memory item,
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
    InventoryItem memory item,
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
    InventoryItem memory item,
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
    InventoryItem memory item,
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

  function _validateWithdrawal(InventoryItem memory item, EphemeralInvItemData memory itemData) internal pure {
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
    InventoryItem memory item,
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
    InventoryItem memory item,
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
    InventoryItem memory item,
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
