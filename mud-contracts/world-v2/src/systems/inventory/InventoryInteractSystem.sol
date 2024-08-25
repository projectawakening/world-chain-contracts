// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "../EveSystem.sol";

import { ItemTransferOffchainTable, EphemeralInvItem, InventoryItemTable } from "../../codegen/index.sol";
// import { DeployableTokenTable } from "../../codegen/index.sol";
import { InventorySystem } from "./InventorySystem.sol";
import { EphemeralInventorySystem } from "./EphemeralInventorySystem.sol";

import { InventoryUtils } from "./InventoryUtils.sol";
import { IInventoryErrors } from "./IInventoryErrors.sol";

import { InventoryItem } from "./types.sol";

contract InventoryInteractSystem is EveSystem {
  using InventoryUtils for bytes14;

  /**
   * // TODO this function should be restricted to be called by a systemId that is configured only the owner of the SSU
   * @notice Transfer items from inventory to ephemeral
   * @dev transfer items from inventory to ephemeral
   * @param smartObjectId is the smart object id
   * @param outItems is the array of items to transfer
   */
  function inventoryToEphemeralTransfer(uint256 smartObjectId, InventoryItem[] memory outItems) public {
    // address owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);
    address ephemeralInventoryOwner = msg.sender; // TODO: check new _initialMsgSender() implementation
    InventoryItem[] memory inItems = new InventoryItem[](outItems.length);

    for (uint i = 0; i < outItems.length; i++) {
      InventoryItem memory item = outItems[i];
      if (InventoryItemTable.get(smartObjectId, item.inventoryItemId).quantity < item.quantity) {
        revert IInventoryErrors.Inventory_InvalidItemQuantity(
          "InventoryInteract: Not enough items to transfer",
          item.inventoryItemId,
          item.quantity
        );
      }

      // Ephemeral Inventory Owner is the address of the caller of this function to whom the items are being transferred
      inItems[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: ephemeralInventoryOwner,
        itemId: item.itemId,
        typeId: item.typeId,
        volume: item.volume,
        quantity: item.quantity
      });

      // Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      //   ItemTransferOffchainTable.set(
      //     smartObjectId,
      //     item.inventoryItemId,
      //     owner,
      //     ephemeralInventoryOwner,
      //     item.quantity,
      //     block.timestamp
      //   );
    }

    // withdraw the items from inventory and deposit to ephemeral table

    ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
    world().call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, outItems)));

    // transfer the items to ephemeral owner who is the caller of this function

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world().call(
      ephemeralInventorySystemId,
      abi.encodeCall(
        EphemeralInventorySystem.depositToEphemeralInventory,
        (smartObjectId, ephemeralInventoryOwner, inItems)
      )
    );
  }

  /**
   * @notice Transfer items from inventory to ephemeral
   * @dev transfer items from inventory to ephemeral
   * @param smartObjectId is the smart object id
   * @param ephemeralInventoryOwner is the ephemeral inventory owner
   * @param outItems is the array of items to transfer
   */
  function inventoryToEphemeralTransferWithParam(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory outItems
  ) public {
    // address owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);
    InventoryItem[] memory inItems = new InventoryItem[](outItems.length);

    for (uint i = 0; i < outItems.length; i++) {
      InventoryItem memory item = outItems[i];
      if (InventoryItemTable.get(smartObjectId, item.inventoryItemId).quantity < item.quantity) {
        revert IInventoryErrors.Inventory_InvalidItemQuantity(
          "InventoryInteract: Not enough items to transfer",
          item.inventoryItemId,
          item.quantity
        );
      }

      //Ephemeral Inventory Owner is the address of the caller of this function to whom the items are being transferred
      inItems[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: ephemeralInventoryOwner,
        itemId: item.itemId,
        typeId: item.typeId,
        volume: item.volume,
        quantity: item.quantity
      });

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      //   ItemTransferOffchainTable.set(
      //     smartObjectId,
      //     item.inventoryItemId,
      //     owner,
      //     ephemeralInventoryOwner,
      //     item.quantity,
      //     block.timestamp
      //   );
    }

    // withdraw the items from inventory and deposit to ephemeral table
    ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
    world().call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, outItems)));

    // transfer the items to ephemeral owner who is the caller of this function
    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world().call(
      ephemeralInventorySystemId,
      abi.encodeCall(
        EphemeralInventorySystem.depositToEphemeralInventory,
        (smartObjectId, ephemeralInventoryOwner, inItems)
      )
    );
  }

  /**
   * @notice Transfer items from ephemeral to inventory
   * @dev transfer items from ephemeral to inventory
   * @param smartObjectId is the smart object id
   * @param items is the array of items to transfer
   */
  function ephemeralToInventoryTransfer(uint256 smartObjectId, InventoryItem[] memory items) public {
    // address owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);
    address ephemeralInventoryOwner = msg.sender; // TODO: check new _initialMsgSender() implementation();

    //check the caller of this function has enough items to transfer to the inventory
    for (uint i = 0; i < items.length; i++) {
      InventoryItem memory item = items[i];

      if (EphemeralInvItem.get(smartObjectId, item.inventoryItemId, ephemeralInventoryOwner).quantity < item.quantity) {
        revert IInventoryErrors.Inventory_InvalidItemQuantity(
          "InventoryInteract: Not enough items to transfer",
          item.inventoryItemId,
          item.quantity
        );
      }

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      //   ItemTransferOffchainTable.set(
      //     smartObjectId,
      //     item.inventoryItemId,
      //     ephemeralInventoryOwner,
      //     owner,
      //     item.quantity,
      //     block.timestamp
      //   );
    }
    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world().call(
      ephemeralInventorySystemId,
      abi.encodeCall(
        EphemeralInventorySystem.withdrawFromEphemeralInventory,
        (smartObjectId, ephemeralInventoryOwner, items)
      )
    );

    ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
    world().call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
  }

  /**
   * // TODO configure the interaction handler
   * // Configure the systemId which is allowed to call the interaction handler
   * // TODO this should be restricted to the owner of the SSU
   * @notice Configure the interaction handler to restrict access
   * @dev configure the interaction handler by systemId and smartObject to interact with this system
   * @param smartObjectId is the smart object id
   * @param interactionParams is the interaction params
   */
  function configureInteractionHandler(uint256 smartObjectId, bytes memory interactionParams) public {}
}
