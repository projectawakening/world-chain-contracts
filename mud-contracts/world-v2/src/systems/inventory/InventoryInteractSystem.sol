// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { InventorySystem } from "./InventorySystem.sol";
import { EphemeralInventorySystem } from "./EphemeralInventorySystem.sol";
import { IERC721 } from "../eve-erc721-puppet/IERC721.sol";
import { DeployableToken } from "../../codegen/index.sol";
import { EntityRecord, EntityRecordData } from "../../codegen/index.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../codegen/index.sol";
import { ItemTransferOffchain } from "../../codegen/index.sol";
import { EphemeralInvItem } from "../../codegen/index.sol";
import { InventoryUtils } from "./InventoryUtils.sol";

import { TransferItem, InventoryItem } from "./types.sol";
import { EveSystem } from "../EveSystem.sol";

/**
 * @title InventoryInteractSystem
 * @author CCP Games
 * @notice This system is responsible for the interaction between the inventory and ephemeral inventory
 * @dev This system is responsible for the interaction between the inventory and ephemeral inventory
 */
contract InventoryInteractSystem is EveSystem {
  error Inventory_InvalidTransferItemQuantity(
    string message,
    uint256 smartObjectId,
    string inventoryType,
    address inventoryOwner,
    uint256 inventoryItemId,
    uint256 quantity
  );
  ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();

  /**
   * @notice Transfer items from ephemeral to inventory
   * @dev transfer items from ephemeral to inventory
   * @param smartObjectId is the smart object id
   * @param ephInvOwner is the ephemeral inventory owner
   * @param items is the array of items to transfer
   * TODO: get the _initialMsgSender when execution context is implemented
   */
  function ephemeralToInventoryTransfer(
    uint256 smartObjectId,
    address ephInvOwner,
    TransferItem[] memory items
  ) public {
    InventoryItem[] memory ephInvOut = new InventoryItem[](items.length);
    InventoryItem[] memory invIn = new InventoryItem[](items.length);
    // address ephInvOwner = _initialMsgSender();
    address objectInvOwner = IERC721(DeployableToken.getErc721Address()).ownerOf(smartObjectId);
    for (uint i = 0; i < items.length; i++) {
      TransferItem memory item = items[i];
      //check the ephInvOwner has enough items to transfer to the inventory
      if (EphemeralInvItem.get(smartObjectId, item.inventoryItemId, ephInvOwner).quantity < item.quantity) {
        revert Inventory_InvalidTransferItemQuantity(
          "InventoryInteractSystem: not enough items to transfer",
          smartObjectId,
          "EPHEMERAL",
          ephInvOwner,
          item.inventoryItemId,
          item.quantity
        );
      }
      EntityRecordData memory itemRecord = EntityRecord.get(item.inventoryItemId);

      ephInvOut[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: ephInvOwner,
        itemId: itemRecord.itemId,
        typeId: itemRecord.typeId,
        volume: itemRecord.volume,
        quantity: item.quantity
      });

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchain.set(
        smartObjectId,
        item.inventoryItemId,
        ephInvOwner,
        objectInvOwner,
        item.quantity,
        block.timestamp
      );
    }

    // withdraw the items from ephemeral and deposit to inventory table
    world().call(
      ephemeralInventorySystemId,
      abi.encodeWithSelector(
        EphemeralInventorySystem.withdrawFromEphemeralInventory.selector,
        smartObjectId,
        ephInvOwner,
        ephInvOut
      )
    );
    for (uint i = 0; i < items.length; i++) {
      invIn[i] = ephInvOut[i];
      invIn[i].owner = objectInvOwner;
    }
    world().call(
      inventorySystemId,
      abi.encodeWithSelector(InventorySystem.depositToInventory.selector, smartObjectId, invIn)
    );
  }

  /**
   * @notice Transfer items from inventory to ephemeral
   * @dev transfer items from inventory storage to an ephemeral storage
   * @param smartObjectId is the smart object id
   * @param ephemeralInventoryOwner is the ephemeral inventory owner
   * @param items is the array of items to transfer
   */
  function inventoryToEphemeralTransfer(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    TransferItem[] memory items
  ) public {
    InventoryItem[] memory invOut = new InventoryItem[](items.length);
    InventoryItem[] memory ephInvIn = new InventoryItem[](items.length);
    address objectInvOwner = IERC721(DeployableToken.getErc721Address()).ownerOf(smartObjectId);

    for (uint i = 0; i < items.length; i++) {
      TransferItem memory item = items[i];
      if (InventoryItemTable.get(smartObjectId, item.inventoryItemId).quantity < item.quantity) {
        revert Inventory_InvalidTransferItemQuantity(
          "InventoryInteractSystem: not enough items to transfer",
          smartObjectId,
          "OBJECT",
          objectInvOwner,
          item.inventoryItemId,
          item.quantity
        );
      }

      EntityRecordData memory itemRecord = EntityRecord.get(item.inventoryItemId);

      invOut[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: objectInvOwner,
        itemId: itemRecord.itemId,
        typeId: itemRecord.typeId,
        volume: itemRecord.volume,
        quantity: item.quantity
      });

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchain.set(
        smartObjectId,
        item.inventoryItemId,
        objectInvOwner,
        ephemeralInventoryOwner,
        item.quantity,
        block.timestamp
      );
    }

    //withdraw the items from inventory and deposit to ephemeral inventory\
    world().call(
      inventorySystemId,
      abi.encodeWithSelector(InventorySystem.withdrawFromInventory.selector, smartObjectId, invOut)
    );
    for (uint i = 0; i < items.length; i++) {
      ephInvIn[i] = invOut[i];
      ephInvIn[i].owner = ephemeralInventoryOwner;
    }
    world().call(
      ephemeralInventorySystemId,
      abi.encodeWithSelector(
        EphemeralInventorySystem.depositToEphemeralInventory.selector,
        smartObjectId,
        ephemeralInventoryOwner,
        ephInvIn
      )
    );
  }
}
