// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { GlobalDeployableState } from "../../../codegen/tables/GlobalDeployableState.sol";
import { InventoryTable } from "../../../codegen/tables/InventoryTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";
import { InventoryItemTableData } from "../../../codegen/tables/InventoryItemTable.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { State } from "../../../codegen/common.sol";

import { SmartDeployableErrors } from "../../smart-deployable/SmartDeployableErrors.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";

import { InventoryItem } from "../types.sol";
import { Utils } from "../Utils.sol";

contract Inventory is EveSystem {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused(_namespace().globalStateTableId()) == false) {
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
  function setInventoryCapacity(
    uint256 smartObjectId,
    uint256 storageCapacity
  ) public hookable(smartObjectId, _systemId()) {
    if (storageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("Inventory: storage capacity cannot be 0");
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
  ) public hookable(smartObjectId, _systemId()) onlyActive {
    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );
    if (currentState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    }

    uint256 usedCapacity = InventoryTable.getUsedCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 maxCapacity = InventoryTable.getCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      //Revert if the items to deposit is not created on-chain
      EntityRecordTableData memory entityRecord = EntityRecordTable.get(
        ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
        items[i].inventoryItemId
      );
      if (entityRecord.recordExists == false) {
        revert IInventoryErrors.Inventory_InvalidItem("Inventory: item is not created on-chain", items[i].typeId);
      }
      usedCapacity = _processItemDeposit(smartObjectId, items[i], usedCapacity, maxCapacity, i);
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
  ) public hookable(smartObjectId, _systemId()) onlyActive {
    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );
    if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    }
    uint256 usedCapacity = InventoryTable.getUsedCapacity(_namespace().inventoryTableId(), smartObjectId);
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, items[i], usedCapacity);
    }
    InventoryTable.setUsedCapacity(_namespace().inventoryTableId(), smartObjectId, usedCapacity);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().inventorySystemId();
  }

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
    InventoryItemTableData memory itemData = InventoryItemTable.get(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId
    );

    DeployableStateData memory deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    //Valid deployable state. Create new item if the item does not exist in the inventory or its has been re-anchored
    if (itemData.stateUpdate == 0 || itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Item does not exist in the inventory
      _depositNewItem(smartObjectId, item, itemIndex);
    } else {
      //Deployable is valid and item exists in the inventory
      _increaseItemQuantity(smartObjectId, item, itemIndex);
    }
  }

  /**
   * @notice Increase the quantity of an item in the inventory
   * @dev Increase the quantity of an item in the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param item The item to increase the quantity
   */
  function _increaseItemQuantity(uint256 smartObjectId, InventoryItem memory item, uint256 itemIndex) internal {
    uint256 quantity = InventoryItemTable.getQuantity(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId
    );
    InventoryItemTable.set(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      quantity + item.quantity,
      itemIndex,
      block.timestamp
    );
  }

  function _depositNewItem(uint256 smartObjectId, InventoryItem memory item, uint256 itemIndex) internal {
    InventoryTable.pushItems(_namespace().inventoryTableId(), smartObjectId, item.inventoryItemId);
    InventoryItemTable.set(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      item.quantity,
      itemIndex,
      block.timestamp
    );
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemTableData memory itemData = InventoryItemTable.get(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId
    );
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
    DeployableStateData memory deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    if (itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Disable withdraw if its has been re-anchored
      revert IInventoryErrors.Inventory_InvalidItemQuantity(
        "Inventory: invalid quantity",
        smartObjectId,
        item.quantity
      );
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
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) internal {
    uint256[] memory inventoryItems = InventoryTable.getItems(_namespace().inventoryTableId(), smartObjectId);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    InventoryTable.updateItems(_namespace().inventoryTableId(), smartObjectId, itemData.index, lastElement);
    InventoryTable.popItems(_namespace().inventoryTableId(), smartObjectId);
    InventoryItemTable.deleteRecord(_namespace().inventoryItemTableId(), smartObjectId, item.inventoryItemId);
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemTableData memory itemData
  ) internal {
    InventoryItemTable.set(
      _namespace().inventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      itemData.quantity - item.quantity,
      itemData.index,
      block.timestamp
    );
  }
}
