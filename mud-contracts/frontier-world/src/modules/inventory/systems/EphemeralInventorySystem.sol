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

  /**
   * @notice Set the ephemeral inventory capacity
   * @dev Set the ephemeral inventory capacity by smart storage unit id
   * //TODO Only owner of the smart storage unit can set the capacity
   * @param smartObjectId The smart storage unit id
   * @param inventoryOwner The owner of the inventory
   * @param ephemeralStorageCapacity The storage capacity
   */
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

  /**
   * @notice Deposit items to the ephemeral inventory
   * @dev Deposit items to the ephemeral inventory by smart storage unit id
   * //TODO msg.sender should be the item owner
   * @param smartObjectId The smart storage unit id
   * @param inventoryOwner The owner of the inventory
   * @param items The items to deposit to the inventory
   */
  function depositToEphemeralInventory(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem[] memory items
  ) public {
    //Make sure items are created before depositing items into the inventory
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

  /**
   * @notice Withdraw items from the ephemeral inventory
   * @dev Withdraw items from the ephemeral inventory by smart storage unit id
   * //TODO msg.sender should be the item owner
   * @param smartObjectId The smart storage unit id
   * @param inventoryOwner The owner of the inventory
   * @param items The items to withdraw from the inventory
   */
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

  /**
   * @notice Interact with the inventory
   * @dev Function for external hook implementation
   * @param smartObjectId The smart object id
   * @param owner The owner of the inventory
   * @param interactionParams The interaction data
   */
  function interact(uint256 smartObjectId, address owner, bytes memory interactionParams) public {
    //Function for external hook implementation
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
