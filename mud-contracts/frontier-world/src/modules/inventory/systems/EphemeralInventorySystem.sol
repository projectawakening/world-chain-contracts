// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { EphemeralInventoryTable } from "../../../codegen/tables/EphemeralInventoryTable.sol";
import { EphemeralInvItemTable } from "../../../codegen/tables/EphemeralInvItemTable.sol";
import { EphemeralInvItemTableData } from "../../../codegen/tables/EphemeralInvItemTable.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";
import { Utils } from "../Utils.sol";
import { InventoryItem } from "../../types.sol";

contract EphemeralInventorySystem is EveSystem {
  using Utils for bytes14;

  function setEphemeralInventoryCapacity(
    uint256 smartObjectId,
    address inventoryOwner,
    uint256 ephemeralStorageCapacity
  ) public {
    if (ephemeralStorageCapacity == 0) {
      revert IInventoryErrors.EphemeralInventory_InvalidCapacity(
        "InventoryEphemeralSystem: storage capacity cannot be 0"
      );
    }
    EphemeralInventoryTable.setCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner,
      ephemeralStorageCapacity
    );
  }

  function depositToEphemeralInventory(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem[] memory items
  ) public {
    uint256 usedCapacity = EphemeralInventoryTable.getUsedCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner
    );
    uint256 maxCapacity = EphemeralInventoryTable.getCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner
    );
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = processItemDeposit(smartObjectId, inventoryOwner, items[i], usedCapacity, maxCapacity, i);
    }
    EphemeralInventoryTable.setUsedCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner,
      usedCapacity
    );
  }

  function withdrawFromEphemeralInventory(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem[] memory items
  ) public {
    uint256 usedCapacity = EphemeralInventoryTable.getUsedCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner
    );
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = processItemWithdrawal(smartObjectId, inventoryOwner, items[i], usedCapacity);
    }
    EphemeralInventoryTable.setUsedCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner,
      usedCapacity
    );
  }

  function interact(uint256 smartObjectId, bytes memory interactionData) public {
    //Implement the logic to interact with the inventory
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().ephemeralInventorySystemId();
  }

  function processItemDeposit(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem memory item,
    uint256 usedCapacity,
    uint256 maxCapacity,
    uint256 index
  ) internal returns (uint256) {
    uint256 reqCapacity = item.volume * item.quantity;

    if ((usedCapacity + reqCapacity) > maxCapacity) {
      revert IInventoryErrors.Inventory_InsufficientEphemeralCapacity(
        "InventoryEphemeralSystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    EphemeralInventoryTable.pushItems(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner,
      item.inventoryItemId
    );
    EphemeralInvItemTable.set(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      item.owner,
      item.quantity,
      index
    );
    return usedCapacity + reqCapacity;
  }

  function processItemWithdrawal(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    EphemeralInvItemTableData memory itemData = EphemeralInvItemTable.get(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      item.owner
    );

    validateWithdrawal(item, itemData);
    updateInventoryAfterWithdrawal(smartObjectId, inventoryOwner, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function validateWithdrawal(InventoryItem memory item, EphemeralInvItemTableData memory itemData) internal pure {
    if (item.quantity > itemData.quantity) {
      revert IInventoryErrors.Inventory_InvalidQuantity(
        "InventoryEphemeralSystem: invalid quantity",
        itemData.quantity,
        item.quantity
      );
    }
  }

  function updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem memory item,
    EphemeralInvItemTableData memory itemData
  ) internal {
    if (item.quantity == itemData.quantity) {
      removeItemFromInventory(smartObjectId, inventoryOwner, item, itemData);
    } else {
      EphemeralInvItemTable.set(
        _namespace().ephemeralInventoryItemTableId(),
        smartObjectId,
        item.inventoryItemId,
        item.owner,
        itemData.quantity - item.quantity,
        itemData.index
      );
    }
  }

  function removeItemFromInventory(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem memory item,
    EphemeralInvItemTableData memory itemData
  ) internal {
    uint256[] memory inventoryItems = EphemeralInventoryTable.getItems(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner
    );
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    EphemeralInventoryTable.updateItems(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      inventoryOwner,
      itemData.index,
      lastElement
    );
    EphemeralInventoryTable.popItems(_namespace().ephemeralInventoryTableId(), smartObjectId, inventoryOwner);

    EphemeralInvItemTable.deleteRecord(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      item.owner
    );
  }
}
