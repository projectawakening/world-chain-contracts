// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "../EveSystem.sol";

import { EphemeralInvCapacity } from "../../codegen/index.sol";
import { EphemeralInv, EphemeralInvData } from "../../codegen/index.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../codegen/index.sol";
import { EntityRecord, EntityRecordData } from "../../codegen/index.sol";

import { IInventoryErrors } from "./IInventoryErrors.sol";

import { InventoryUtils } from "./InventoryUtils.sol";
import { Utils as EntityRecordUtils } from "../entity-record/Utils.sol";

import { InventoryItem } from "./types.sol";

contract EphemeralInventorySystem is EveSystem {
  using EntityRecordUtils for bytes14;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  //   modifier onlyActive() {
  //     if (GlobalDeployableState.getIsPaused(_namespace().globalStateTableId()) == false) {
  //       revert SmartDeployableErrors.SmartDeployable_StateTransitionPaused();
  //     }
  //     _;
  //   }

  /**
   * // TODO Only owner of the smart storage unit can set the capacity
   * @notice Set the ephemeral inventory capacity
   * @dev Set the ephemeral inventory capacity by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param ephemeralStorageCapacity The storage capacity
   */
  function setEphemeralInventoryCapacity(uint256 smartObjectId, uint256 ephemeralStorageCapacity) public {
    if (ephemeralStorageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("InventoryEphemeralSystem: storage capacity cannot be 0");
    }
    EphemeralInvCapacity.setCapacity(smartObjectId, ephemeralStorageCapacity);
  }

  function depositToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    // State currentState = DeployableState.getCurrentState(
    //   SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
    //   smartObjectId
    // );
    // if (currentState != State.ONLINE) {
    //   revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    // }

    uint256 usedCapacity = EphemeralInv.getUsedCapacity(smartObjectId, ephemeralInventoryOwner);
    uint256 maxCapacity = EphemeralInvCapacity.getCapacity(smartObjectId);

    uint256 existingItemsLength = EphemeralInv.getItems(smartObjectId, ephemeralInventoryOwner).length;

    for (uint256 i = 0; i < items.length; i++) {
      // Revert if the items to deposit is not created on-chain
      EntityRecordData memory entityRecord = EntityRecord.get(items[i].inventoryItemId);

      if (entityRecord.recordExists == false) {
        revert IInventoryErrors.Inventory_InvalidItem(
          "InventoryEphemeralSystem: item is not created on-chain",
          items[i].typeId
        );
      }
      uint256 itemIndex = existingItemsLength + i;
      usedCapacity = _processItemDeposit(
        smartObjectId,
        ephemeralInventoryOwner,
        items[i],
        usedCapacity,
        maxCapacity,
        itemIndex
      );
    }
    EphemeralInv.setUsedCapacity(smartObjectId, ephemeralInventoryOwner, usedCapacity);
  }

  /**
   * // TODO msg.sender should be the item owner
   * @notice Withdraw items from the ephemeral inventory
   * @dev Withdraw items from the ephemeral inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param ephemeralInventoryOwner The owner of the inventory
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    // State currentState = DeployableState.getCurrentState(smartObjectId);
    // if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
    //   revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    // }

    uint256 usedCapacity = EphemeralInv.getUsedCapacity(smartObjectId, ephemeralInventoryOwner);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, ephemeralInventoryOwner, items[i], usedCapacity);
    }
    EphemeralInv.setUsedCapacity(smartObjectId, ephemeralInventoryOwner, usedCapacity);
  }

  /*******************
   * INTERNAL METHODS *
   *******************/

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
      revert IInventoryErrors.Inventory_InsufficientCapacity(
        "InventoryEphemeralSystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }
    if (ephemeralInventoryOwner != item.owner) {
      revert IInventoryErrors.Inventory_InvalidOwner(
        "InventoryEphemeralSystem: ephemeralInventoryOwner and item owner should be the same",
        ephemeralInventoryOwner,
        item.owner
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

    // DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    // // Valid deployable state. Create new item if the item does not exist in the inventory or its has been re-anchored
    // if (itemData.stateUpdate == 0 || itemData.stateUpdate < deployableStateData.anchoredAt) {
    //   //Item does not exist in the inventory
    //   _depositNewItem(smartObjectId, ephemeralInventoryOwner, item, itemIndex);
    // } else {
    //   //Deployable is valid and item exists in the inventory
    //   _increaseItemQuantity(smartObjectId, ephemeralInventoryOwner, item, itemData.index);
    // }
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
      revert IInventoryErrors.Inventory_InvalidQuantity(
        "InventoryEphemeralSystem: invalid quantity",
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
    // DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);
    // if (itemData.stateUpdate < deployableStateData.anchoredAt) {
    //   //Disable withdraw if its has been re-anchored
    //   revert IInventoryErrors.Inventory_InvalidItemQuantity(
    //     "Inventory: invalid quantity",
    //     smartObjectId,
    //     item.quantity
    //   );
    // } else {
    //   //Deployable is valid and item exists in the inventory
    //   if (item.quantity == itemData.quantity) {
    //     _removeItemCompletely(smartObjectId, ephemeralInventoryOwner, item, itemData);
    //   } else if (item.quantity < itemData.quantity) {
    //     _reduceItemQuantity(smartObjectId, ephemeralInventoryOwner, item, itemData);
    //   }
    // }
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
