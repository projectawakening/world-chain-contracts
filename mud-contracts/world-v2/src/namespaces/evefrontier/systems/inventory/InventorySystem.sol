//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// External libraries
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IERC721 } from "../eve-erc721-puppet/IERC721.sol";

// Smart Object Framework
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Role, Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Project imports - Tables
import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { Inventory } from "../../codegen/index.sol";
import { EntityRecord, EntityRecordData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../codegen/index.sol";
import { DeployableToken } from "../../codegen/index.sol";

// Project imports - Systems
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";

// Local imports
import { InventoryItem } from "./types.sol";
import { State } from "../deployable/types.sol";
import { EntityRecordData as EntityRecordStruct } from "../entity-record/types.sol";
import { InventoryUtils } from "./InventoryUtils.sol";

/**
 * @title InventorySystem
 * @author CCP Games
 * @notice InventorySystem stores the inventory of a smart object on-chain
 */
contract InventorySystem is SmartObjectFramework {
  error Inventory_InvalidCapacity(string message);
  error Inventory_InsufficientCapacity(string message, uint256 maxCapacity, uint256 usedCapacity);
  error Inventory_InvalidItemQuantity(string message, uint256 quantity, uint256 maxQuantity);
  error Inventory_InvalidItem(string message, uint256 inventoryItemId);
  error Inventory_InvalidItemOwner(
    string message,
    uint256 inventoryItemId,
    address providedItemOwner,
    address expectedOwner
  );
  error Inventory_InvalidDeployable(string message, uint256 deployableId);

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
   * @notice sets the inventory capacity of a smart object
   * @dev sets the inventory capacity of a smart object
   * @param smartObjectId on-chain id of the in-game object
   * @param capacity the capacity of the inventory
   * //TODO : onlyAdmin
   */
  function setInventoryCapacity(
    uint256 smartObjectId,
    uint256 capacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (capacity == 0) {
      revert Inventory_InvalidCapacity("InventorySystem: storage capacity cannot be 0");
    }

    bytes32 adminAccessRole = InventoryUtils.getAdminAccessRole(smartObjectId);
    if (!Role.getExists(adminAccessRole)) {
      roleManagementSystem.createRole(adminAccessRole, adminAccessRole);
    }

    bytes32 depositAccessRole = InventoryUtils.getEphemeralToInventoryTransferAccessRole(smartObjectId);

    if (!Role.getExists(depositAccessRole)) {
      roleManagementSystem.createRole(depositAccessRole, adminAccessRole);
    }

    bytes32 withdrawAccessRole = InventoryUtils.getInventoryToEphemeralTransferAccessRole(smartObjectId);

    if (!Role.getExists(withdrawAccessRole)) {
      roleManagementSystem.createRole(withdrawAccessRole, adminAccessRole);
    }

    roleManagementSystem.grantRole(adminAccessRole, _callMsgSender(1));

    Inventory.setCapacity(smartObjectId, capacity);
  }

  /**
   * @notice Create and deposit items to the inventory
   * @dev Create and deposit items to the inventory by smart object
   * @param smartObjectId on-chain id of the in-game object
   * @param items array of InventoryItem structs
   */
  function createAndDepositItemsToInventory(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public onlyActive access(smartObjectId) scope(smartObjectId) {
    for (uint256 i = 0; i < items.length; i++) {
      EntityRecordStruct memory entityRecord = EntityRecordStruct({
        typeId: items[i].typeId,
        itemId: items[i].itemId,
        volume: items[i].volume
      });

      bool isDeployable = DeployableState.getCreatedAt(smartObjectId) != 0;
      address owner;
      if (isDeployable) {
        address erc721Address = DeployableToken.getErc721Address();
        owner = IERC721(erc721Address).ownerOf(smartObjectId);
      } else {
        owner = _callMsgSender(1);
      }

      if (!Entity.getExists(items[i].inventoryItemId)) {
        entitySystem.instantiate(uint256(bytes32("INVENTORY_ITEM")), items[i].inventoryItemId, owner);
      }
      entityRecordSystem.createEntityRecord(items[i].inventoryItemId, entityRecord);
    }

    depositToInventory(smartObjectId, items);
  }

  /**
   * @notice Deposit items to the inventory
   * @dev Deposit items to the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param items The items to deposit to the inventory
   */
  function depositToInventory(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    {
      bool isDeployable = DeployableState.getCreatedAt(smartObjectId) != 0;

      if (isDeployable) {
        State currentState = DeployableState.getCurrentState(smartObjectId);
        if (currentState != State.ONLINE) {
          revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
        }
      }
    }

    uint256 totalUsedCapacity = _processAndReturnUsedCapacity(smartObjectId, items);

    Inventory.setUsedCapacity(smartObjectId, totalUsedCapacity);
  }

  /**
   * @notice Withdraw items from the inventory
   * @dev Withdraw items from the inventory by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromInventory(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    {
      bool isDeployable = DeployableState.getCreatedAt(smartObjectId) != 0;

      if (isDeployable) {
        State currentState = DeployableState.getCurrentState(smartObjectId);
        if (!(currentState == State.ANCHORED || currentState == State.ONLINE)) {
          revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
        }
      }
    }

    uint256 usedCapacity = Inventory.getUsedCapacity(smartObjectId);

    for (uint256 i = 0; i < items.length; i++) {
      usedCapacity = _processItemWithdrawal(smartObjectId, items[i], usedCapacity);
    }

    Inventory.setUsedCapacity(smartObjectId, usedCapacity);
  }

  /**
   * Internal Functions
   */
  function _processAndReturnUsedCapacity(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) internal returns (uint256) {
    uint256 totalUsedCapacity = Inventory.getUsedCapacity(smartObjectId);
    uint256 maxCapacity = Inventory.getCapacity(smartObjectId);

    uint256 existingItemsLength = Inventory.getItems(smartObjectId).length;

    for (uint256 i = 0; i < items.length; i++) {
      //Revert if the items to deposit is not created on-chain
      EntityRecordData memory entityRecord = EntityRecord.get(items[i].inventoryItemId);
      if (entityRecord.recordExists == false) {
        revert Inventory_InvalidItem("InventorySystem: item is not created on-chain", items[i].inventoryItemId);
      }
      //If there are inventory items exists for the smartObjectId, then the itemIndex is the length of the inventoryItems + i
      uint256 itemIndex = existingItemsLength + i;
      totalUsedCapacity = _processItemDeposit(smartObjectId, items[i], totalUsedCapacity, maxCapacity, itemIndex);
    }
    return totalUsedCapacity;
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
      revert Inventory_InsufficientCapacity(
        "InventorySystem: insufficient capacity",
        maxCapacity,
        usedCapacity + reqCapacity
      );
    }

    _updateInventoryAfterDeposit(smartObjectId, item, itemIndex);
    return usedCapacity + reqCapacity;
  }

  function _updateInventoryAfterDeposit(uint256 smartObjectId, InventoryItem memory item, uint256 itemIndex) internal {
    InventoryItemData memory itemData = InventoryItemTable.get(smartObjectId, item.inventoryItemId);

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
    Inventory.pushItems(smartObjectId, item.inventoryItemId);
    InventoryItemTable.set(smartObjectId, item.inventoryItemId, item.quantity, itemIndex, block.timestamp);
  }

  function _processItemWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    uint256 usedCapacity
  ) internal returns (uint256) {
    InventoryItemData memory itemData = InventoryItemTable.get(smartObjectId, item.inventoryItemId);
    _validateWithdrawal(item, itemData);

    _updateInventoryAfterWithdrawal(smartObjectId, item, itemData);

    return usedCapacity - (item.volume * item.quantity);
  }

  function _validateWithdrawal(InventoryItem memory item, InventoryItemData memory itemData) internal pure {
    if (item.quantity > itemData.quantity) {
      revert Inventory_InvalidItemQuantity("InventorySystem: invalid quantity", itemData.quantity, item.quantity);
    }
  }

  function _updateInventoryAfterWithdrawal(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemData memory itemData
  ) internal {
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    if (itemData.stateUpdate < deployableStateData.anchoredAt) {
      //Disable withdraw if its has been re-anchored
      revert Inventory_InvalidItemQuantity("InventorySystem: invalid quantity", smartObjectId, item.quantity);
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
    InventoryItemData memory itemData
  ) internal {
    uint256[] memory inventoryItems = Inventory.getItems(smartObjectId);
    uint256 lastElement = inventoryItems[inventoryItems.length - 1];
    Inventory.updateItems(smartObjectId, itemData.index, lastElement);
    Inventory.popItems(smartObjectId);

    //when a last element is swapped, change the index of the last element in the InventoryItemTable
    InventoryItemTable.setIndex(smartObjectId, lastElement, itemData.index);
    InventoryItemTable.deleteRecord(smartObjectId, item.inventoryItemId);
  }

  function _reduceItemQuantity(
    uint256 smartObjectId,
    InventoryItem memory item,
    InventoryItemData memory itemData
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
