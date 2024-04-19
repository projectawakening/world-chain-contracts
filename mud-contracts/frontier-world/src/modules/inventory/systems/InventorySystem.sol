// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";

import { GlobalDeployableState } from "../../../codegen/tables/GlobalDeployableState.sol";
import { InventoryTable } from "../../../codegen/tables/InventoryTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";
import { InventoryItemTableData } from "../../../codegen/tables/InventoryItemTable.sol";
import { InventoryTableData } from "../../../codegen/tables/InventoryTable.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { State } from "../../../codegen/common.sol";

import { SmartDeployableErrors } from "../../smart-deployable/SmartDeployableErrors.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";

import { InventoryItem } from "../../types.sol";
import { Utils } from "../Utils.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";

contract InventorySystem is EveSystem {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;

  /**
   * modifier to enforce online state for an smart deployable
   * @param smartObjectId is the smart deployable id
   */
  modifier onlyOnline(uint256 smartObjectId) {
    State currentState = DeployableState.getState(_namespace().deployableStateTableId(), smartObjectId);
    if (GlobalDeployableState.getGlobalState(_namespace().globalStateTableId()) == State.OFFLINE) {
      revert SmartDeployableErrors.SmartDeployable_GloballyOffline();
    } else if (currentState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, State.ONLINE, currentState);
    }
    _;
  }

  /**
   * modifier to enforce any state above anchored state for an smart deployable
   * @param smartObjectId is the smart deployable id
   */
  modifier beyondAnchored(uint256 smartObjectId) {
    State currentState = DeployableState.getState(_namespace().deployableStateTableId(), smartObjectId);
    if (GlobalDeployableState.getGlobalState(_namespace().globalStateTableId()) == State.OFFLINE) {
      revert SmartDeployableErrors.SmartDeployable_GloballyOffline();
    } else if (currentState == State.NULL || currentState == State.UNANCHORED || currentState == State.DESTROYED) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, State.NULL, currentState);
    }
    _;
  }

  /**
   * @notice Set the inventory capacity
   * @dev Set the inventory capacity by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param storageCapacity The storage capacity
   */
  function setInventoryCapacity(
    uint256 smartObjectId,
    uint256 storageCapacity
  ) public hookable(smartObjectId, _systemId()) {
    if (storageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("InventorySystem: storage capacity cannot be 0");
    }
    InventoryTable.setCapacity(_namespace().inventoryTableId(), smartObjectId, storageCapacity);
  }

  /**
   * @notice Deposit items to the inventory
   * @dev Deposit items to the inventory by smart storage unit id
   * //TODO Only owner(msg.sender) of the smart storage unit can deposit items in the inventory
   * @param smartObjectId The smart storage unit id
   * @param items The items to deposit to the inventory
   */
  function depositToInventory(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public hookable(smartObjectId, _systemId()) onlyOnline(smartObjectId) {
    uint256 usedCapacity = InventoryTable.getUsedCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 maxCapacity = InventoryTable.getCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      //Revert if the items to deposit is not created on-chain
      EntityRecordTableData memory entityRecord = EntityRecordTable.get(
        _namespace().entityRecordTableId(),
        items[i].inventoryItemId
      );
      if (entityRecord.volume <= 0) {
        revert IInventoryErrors.Inventory_InvalidItem("InventorySystem: item is not created on-chain", items[i].typeId);
      }
      usedCapacity = processItemDeposit(smartObjectId, items[i], usedCapacity, maxCapacity, i);
    }

    InventoryTable.setUsedCapacity(_namespace().inventoryTableId(), smartObjectId, usedCapacity);
  }

  /**
   * @notice Withdraw items from the inventory
   * @dev Withdraw items from the inventory by smart storage unit id
   * //TODO Only owner(msg.sender) of the smart storage unit can withdraw items from the inventory
   * @param smartObjectId The smart storage unit id
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromInventory(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public hookable(smartObjectId, _systemId()) beyondAnchored(smartObjectId) {
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
  ) internal returns (uint256) {
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
  ) internal returns (uint256) {
    InventoryItemTableData memory itemData = InventoryItemTable.get(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId
    );
    validateWithdrawal(item, itemData);

    updateInventoryAfterWithdrawal(smartObjectId, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function validateWithdrawal(InventoryItem memory item, InventoryItemTableData memory itemData) internal pure {
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
  ) internal {
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
  ) internal {
    uint256[] memory inventoryItems = InventoryTable.getItems(_namespace().inventoryTableId(), smartObjectId);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    InventoryTable.updateItems(_namespace().inventoryTableId(), smartObjectId, itemData.index, lastElement);
    InventoryTable.popItems(_namespace().inventoryTableId(), smartObjectId);
    InventoryItemTable.deleteRecord(_namespace().inventoryItemTableId(), smartObjectId, item.inventoryItemId);
  }

  function reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) internal {
    InventoryItemTable.set(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      itemData.quantity - item.quantity,
      itemData.index
    );
  }
}
