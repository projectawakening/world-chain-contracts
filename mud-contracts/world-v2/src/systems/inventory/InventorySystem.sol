// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "../EveSystem.sol";

import { InventoryTable, InventoryTableData } from "../../codegen/index.sol";
import { InventoryItemTable, InventoryItemTableData } from "../../codegen/index.sol";
import { EntityRecord, EntityRecordData } from "../../codegen/index.sol";
import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { SmartDeployableErrors } from "../smart-deployable/SmartDeployableErrors.sol";
import { State } from "../smart-deployable/types.sol";

import { InventoryUtils } from "./InventoryUtils.sol";
import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";

import { IInventoryErrors } from "./IInventoryErrors.sol";

import { InventoryItem } from "./types.sol";

contract InventorySystem is EveSystem {
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused() == false) {
      revert SmartDeployableErrors.SmartDeployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * @notice Set the inventory capacity
   * @dev Set the inventory capacity by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param storageCapacity The storage capacity
   */
  function setInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    if (storageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("Inventory: storage capacity cannot be 0");
    }
    InventoryTable.setCapacity(smartObjectId, storageCapacity);
  }

  /**
   * // TODO Only owner(msg.sender) of the smart storage unit can deposit items in the inventory
   * @notice Deposit items to the inventory
   * @dev Deposit items to the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param items The items to deposit to the inventory
   */
  function depositToInventory(uint256 smartObjectId, InventoryItem[] memory items) public onlyActive {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (currentState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    }

    uint256 usedCapacity = InventoryTable.getUsedCapacity(smartObjectId);
    uint256 maxCapacity = InventoryTable.getCapacity(smartObjectId);
    uint256 existingItemsLength = InventoryTable.getItems(smartObjectId).length;

    for (uint256 i = 0; i < items.length; i++) {
      // Revert if the items to deposit are not created on-chain
      EntityRecordData memory entityRecord = EntityRecord.get(items[i].inventoryItemId);
      if (entityRecord.recordExists == false) {
        revert IInventoryErrors.Inventory_InvalidItem("Inventory: item is not created on-chain", items[i].typeId);
      }
      // If there are inventory items for the smartObjectId, then the itemIndex is the length of the inventoryItems + i
      uint256 itemIndex = existingItemsLength + i;
      usedCapacity = _processItemDeposit(smartObjectId, items[i], usedCapacity, maxCapacity, itemIndex);
    }

    InventoryTable.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /**
   * // TODO Only owner(msg.sender) of the smart storage unit can withdraw items from the inventory
   * @notice Withdraw items from the inventory
   * @dev Withdraw items from the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromInventory(uint256 smartObjectId, InventoryItem[] memory items) public onlyActive {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    }
    uint256 usedCapacity = InventoryTable.getUsedCapacity(smartObjectId);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, items[i], usedCapacity);
    }
    InventoryTable.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /*******************
   * INTERNAL METHODS *
   *******************/

  function _processItemDeposit(
    uint256 smartObjectId,
    InventoryItem memory item,
    uint256 usedCapacity,
    uint256 maxCapacity,
    uint256 itemIndex
  ) internal returns (uint256) {
    uint256 reqCapacity = item.volume * item.quantity;
    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert IInventoryErrors.Inventory_InsufficientCapacity(
        "Inventory: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    _updateInventoryAfterDeposit(smartObjectId, item, itemIndex);
    return usedCapacity + reqCapacity;
  }

  function _updateInventoryAfterDeposit(uint256 smartObjectId, InventoryItem memory item, uint256 itemIndex) internal {
    InventoryItemTableData memory itemData = InventoryItemTable.get(smartObjectId, item.inventoryItemId);

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
  function _increaseItemQuantity(uint256 smartObjectId, InventoryItem memory item, uint256 itemIndex) internal {
    uint256 quantity = InventoryItemTable.getQuantity(smartObjectId, item.inventoryItemId);
    InventoryItemTable.set(smartObjectId, item.inventoryItemId, quantity + item.quantity, itemIndex, block.timestamp);
  }

  function _depositNewItem(uint256 smartObjectId, InventoryItem memory item, uint256 itemIndex) internal {
    InventoryTable.pushItems(smartObjectId, item.inventoryItemId);
    InventoryItemTable.set(smartObjectId, item.inventoryItemId, item.quantity, itemIndex, block.timestamp);
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemTableData memory itemData = InventoryItemTable.get(smartObjectId, item.inventoryItemId);
    _validateWithdrawal(item, itemData);

    _updateInventoryAfterWithdrawal(smartObjectId, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function _validateWithdrawal(InventoryItem memory item, InventoryItemTableData memory itemData) internal pure {
    if (item.quantity > itemData.quantity) {
      revert IInventoryErrors.Inventory_InvalidQuantity(
        "Inventory: invalid quantity",
        itemData.quantity,
        item.quantity
      );
    }
  }

  function _updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) internal {
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);
    if (itemData.stateUpdate < deployableStateData.anchoredAt) {
      // Disable withdraw if its has been re-anchored
      revert IInventoryErrors.Inventory_InvalidItemQuantity(
        "Inventory: invalid quantity",
        smartObjectId,
        item.quantity
      );
    } else {
      // Deployable is valid and item exists in the inventory
      if (item.quantity == itemData.quantity) {
        _removeItemCompletely(smartObjectId, item, itemData);
      } else if (item.quantity < itemData.quantity) {
        _reduceItemQuantity(smartObjectId, item, itemData);
      }
    }
  }

  function _removeItemCompletely(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) internal {
    uint256[] memory inventoryItems = InventoryTable.getItems(smartObjectId);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];

    InventoryTable.updateItems(smartObjectId, itemData.index, lastElement);
    InventoryTable.popItems(smartObjectId);

    // when a last element is swapped, change the index of the last element in the InventoryItemTable
    InventoryItemTable.setIndex(smartObjectId, lastElement, itemData.index);
    InventoryItemTable.deleteRecord(smartObjectId, item.inventoryItemId);
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) internal {
    InventoryItemTable.set(
      smartObjectId,
      item.inventoryItemId,
      itemData.quantity - item.quantity,
      itemData.index,
      block.timestamp
    );
  }
}
