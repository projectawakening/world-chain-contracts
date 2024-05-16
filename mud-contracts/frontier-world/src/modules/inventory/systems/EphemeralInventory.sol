// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eveworld/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { EphemeralInvTable } from "../../../codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../../codegen/tables/EphemeralInvItemTable.sol";
import { EphemeralInvCapacityTable } from "../../../codegen/tables/EphemeralInvCapacityTable.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { GlobalDeployableState } from "../../../codegen/tables/GlobalDeployableState.sol";
import { State } from "../../../codegen/common.sol";

import { SmartDeployableErrors } from "../../smart-deployable/SmartDeployableErrors.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";

import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";
import { Utils } from "../Utils.sol";
import { InventoryItem } from "../types.sol";

contract EphemeralInventory is EveSystem {
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
   * @notice Set the ephemeral inventory capacity
   * @dev Set the ephemeral inventory capacity by smart storage unit id
   * //TODO Only owner of the smart storage unit can set the capacity
   * @param smartObjectId The smart storage unit id
   * @param ephemeralStorageCapacity The storage capacity
   */
  function setEphemeralInventoryCapacity(
    uint256 smartObjectId,
    uint256 ephemeralStorageCapacity
  ) public onlyAssociatedModule(smartObjectId, _systemId()) hookable(smartObjectId, _systemId()) {
    if (ephemeralStorageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("InventoryEphemeralSystem: storage capacity cannot be 0");
    }
    EphemeralInvCapacityTable.setCapacity(
      _namespace().ephemeralInvCapacityTableId(),
      smartObjectId,
      ephemeralStorageCapacity
    );
  }

  /**
   * @notice Deposit items to the ephemeral inventory
   * @dev Deposit items to the ephemeral inventory by smart storage unit id
   * //TODO msg.sender should be the ephemeralInventoryOwner
   * @param smartObjectId The smart storage unit id
   * @param ephemeralInventoryOwner The owner of the inventory
   * @param items The items to deposit to the inventory
   */
  function depositToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public onlyAssociatedModule(smartObjectId, _systemId()) hookable(smartObjectId, _systemId()) onlyActive {
    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );
    if (currentState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    }

    uint256 usedCapacity = EphemeralInvTable.getUsedCapacity(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner
    );
    uint256 maxCapacity = EphemeralInvCapacityTable.getCapacity(
      _namespace().ephemeralInvCapacityTableId(),
      smartObjectId
    );
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      //Revert if the items to deposit is not created on-chain
      EntityRecordTableData memory entityRecord = EntityRecordTable.get(
        ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
        items[i].inventoryItemId
      );
      if (entityRecord.recordExists == false) {
        revert IInventoryErrors.Inventory_InvalidItem(
          "InventoryEphemeralSystem: item is not created on-chain",
          items[i].typeId
        );
      }
      usedCapacity = _processItemDeposit(
        smartObjectId,
        ephemeralInventoryOwner,
        items[i],
        usedCapacity,
        maxCapacity,
        i
      );
    }
    EphemeralInvTable.setUsedCapacity(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner,
      usedCapacity
    );
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
  ) public onlyAssociatedModule(smartObjectId, _systemId()) hookable(smartObjectId, _systemId()) onlyActive {
    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );
    if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartObjectId, currentState);
    }

    uint256 usedCapacity = EphemeralInvTable.getUsedCapacity(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner
    );
    uint256 itemsLength = items.length;

    for (uint256 i = 0; i < itemsLength; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, ephemeralInventoryOwner, items[i], usedCapacity);
    }
    EphemeralInvTable.setUsedCapacity(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner,
      usedCapacity
    );
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().ephemeralInventorySystemId();
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
      revert IInventoryErrors.Inventory_InsufficientCapacity(
        "InventoryEphemeralSystem: insufficient capacity",
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
    EphemeralInvItemTableData memory itemData = EphemeralInvItemTable.get(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner
    );

    DeployableStateData memory deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    //Valid deployable state. Create new item if the item does not exist in the inventory or its has been re-anchored
    if (itemData.stateUpdate == 0 || itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Item does not exist in the inventory
      _depositNewItem(smartObjectId, ephemeralInventoryOwner, item, itemIndex);
    } else {
      //Deployable is valid and item exists in the inventory
      _increaseItemQuantity(smartObjectId, ephemeralInventoryOwner, item, itemIndex);
    }
  }

  function _increaseItemQuantity(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem memory item,
    uint256 index
  ) internal {
    uint256 quantity = EphemeralInvItemTable.getQuantity(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner
    );

    EphemeralInvItemTable.set(
      _namespace().ephemeralInventoryItemTableId(),
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
    EphemeralInvTable.pushItems(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner,
      item.inventoryItemId
    );
    EphemeralInvItemTable.set(
      _namespace().ephemeralInventoryItemTableId(),
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
    EphemeralInvItemTableData memory itemData = EphemeralInvItemTable.get(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner
    );

    _validateWithdrawal(item, itemData);
    _updateInventoryAfterWithdrawal(smartObjectId, ephemeralInventoryOwner, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function _validateWithdrawal(InventoryItem memory item, EphemeralInvItemTableData memory itemData) internal pure {
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
    EphemeralInvItemTableData memory itemData
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
    EphemeralInvItemTableData memory itemData
  ) internal {
    uint256[] memory inventoryItems = EphemeralInvTable.getItems(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner
    );
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    EphemeralInvTable.updateItems(
      _namespace().ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner,
      itemData.index,
      lastElement
    );
    EphemeralInvTable.popItems(_namespace().ephemeralInvTableId(), smartObjectId, ephemeralInventoryOwner);

    EphemeralInvItemTable.deleteRecord(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner
    );
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem memory item,
    EphemeralInvItemTableData memory itemData
  ) internal {
    EphemeralInvItemTable.set(
      _namespace().ephemeralInventoryItemTableId(),
      smartObjectId,
      item.inventoryItemId,
      ephemeralInventoryOwner,
      itemData.quantity - item.quantity,
      itemData.index,
      block.timestamp
    );
  }
}
