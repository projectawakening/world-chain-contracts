// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { InventoryTable } from "../../../codegen/tables/InventoryTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";
import { InventoryItemTableData } from "../../../codegen/tables/InventoryItemTable.sol";
import { InventoryTableData } from "../../../codegen/tables/InventoryTable.sol";
import { InventoryItem } from "../../types.sol";
import { Utils } from "../Utils.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";

contract InventorySystem is EveSystem {
  using Utils for bytes14;

  /**
   * @notice Set the inventory capacity
   * @dev Set the inventory capacity by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param storageCapacity The storage capacity
   */
  function setInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    if (storageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("InventorySystem: storage capacity cannot be 0");
    }
    InventoryTable.setCapacity(_namespace().inventoryTableId(), smartObjectId, storageCapacity);
  }

  /**
   * @notice Deposit items to the inventory
   * @dev Deposit items to the inventory by smart storage unit id
   * //TODO Only owner of the smart storage unit can deposit items in the inventory
   * @param smartObjectId The smart storage unit id
   * @param items The items to deposit to the inventory
   */
  function depositToInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    uint256 usedCapacity = InventoryTable.getUsedCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 maxCapacity = InventoryTable.getCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = processItemDeposit(smartObjectId, items[i], usedCapacity, maxCapacity, i);
    }

    InventoryTable.setUsedCapacity(_namespace().inventoryTableId(), smartObjectId, usedCapacity);
  }

  /**
   * @notice Withdraw items from the inventory
   * @dev Withdraw items from the inventory by smart storage unit id
   * //TODO Only owner of the smart storage unit can withdraw items from the inventory
   * @param smartObjectId The smart storage unit id
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    uint256 usedCapacity = InventoryTable.getUsedCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = processItemWithdrawal(smartObjectId, items[i], usedCapacity);
    }
    InventoryTable.setUsedCapacity(_namespace().inventoryTableId(), smartObjectId, usedCapacity);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().inventorySystemId();
  }

  function processItemDeposit(
    uint256 smartObjectId,
    InventoryItem memory item,
    uint256 usedCapacity,
    uint256 maxCapacity,
    uint256 index
  ) private returns (uint256) {
    uint256 reqCapacity = item.volume * item.quantity;
    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert IInventoryErrors.Inventory_InsufficientCapacity(
        "InventorySystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    InventoryTable.pushItems(_namespace().inventoryTableId(), smartObjectId, item.inventoryItemId);
    InventoryItemTable.set(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      item.quantity,
      index
    );

    return usedCapacity + reqCapacity;
  }

  function processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    uint256 usedCapacity
  ) private returns (uint256) {
    InventoryItemTableData memory itemData = InventoryItemTable.get(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId
    );
    validateWithdrawal(item, itemData);

    updateInventoryAfterWithdrawal(smartObjectId, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function validateWithdrawal(InventoryItem memory item, InventoryItemTableData memory itemData) private pure {
    if (item.quantity > itemData.quantity) {
      revert IInventoryErrors.Inventory_InvalidQuantity(
        "InventorySystem: invalid quantity",
        itemData.quantity,
        item.quantity
      );
    }
  }

  function updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) private {
    if (item.quantity == itemData.quantity) {
      removeItemCompletely(smartObjectId, item, itemData);
    } else {
      reduceItemQuantity(smartObjectId, item, itemData);
    }
  }

  function removeItemCompletely(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) private {
    InventoryItemTable.deleteRecord(_namespace().inventoryItemTableId(), smartObjectId, item.inventoryItemId);
    uint256[] memory inventoryItems = InventoryTable.getItems(_namespace().inventoryTableId(), smartObjectId);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    InventoryTable.updateItems(_namespace().inventoryTableId(), smartObjectId, itemData.index, lastElement);
    InventoryTable.popItems(_namespace().inventoryTableId(), smartObjectId);
  }

  function reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) private {
    InventoryItemTable.set(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      itemData.quantity - item.quantity,
      itemData.index
    );
  }
}
