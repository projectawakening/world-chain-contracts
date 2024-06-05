// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { IERC721 } from "../../eve-erc721-puppet/IERC721.sol";
import { ItemTransferOffchainTable } from "../../../codegen/tables/ItemTransferOffchainTable.sol";
import { EphemeralInvItemTable } from "../../../codegen/tables/EphemeralInvItemTable.sol";
import { DeployableTokenTable } from "../../../codegen/tables/DeployableTokenTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";

import { Utils as InventoryUtils } from "../../../modules/inventory/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";
import { Utils } from "../Utils.sol";

import { InventoryLib } from "../InventoryLib.sol";
import { InventoryItem } from "../types.sol";

contract InventoryInteract is EveSystem {
  using Utils for bytes14;
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryLib for InventoryLib.World;

  /**
   * @notice Transfer items from inventory to ephemeral
   * @dev transfer items from inventory to ephemeral
   * //TODO this function should be restricted to be called by a systemId that is configured only the owner of the SSU
   * @param smartObjectId is the smart object id
   * @param outItems is the array of items to transfer
   */
  function inventoryToEphemeralTransfer(
    uint256 smartObjectId,
    InventoryItem[] memory outItems
  ) public hookable(smartObjectId, _systemId()) {
    address owner = IERC721(DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId())).ownerOf(
      smartObjectId
    );
    address ephemeralInventoryOwner = _initialMsgSender();
    InventoryItem[] memory inItems = new InventoryItem[](outItems.length);

    for (uint i = 0; i < outItems.length; i++) {
      InventoryItem memory item = outItems[i];
      if (
        InventoryItemTable.get(_namespace().inventoryItemTableId(), smartObjectId, item.inventoryItemId).quantity <
        item.quantity
      ) {
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
      ItemTransferOffchainTable.set(
        _namespace().itemTransferTableId(),
        smartObjectId,
        item.inventoryItemId,
        owner,
        ephemeralInventoryOwner,
        item.quantity,
        block.timestamp
      );
    }

    //withdraw the items from inventory and deposit to ephemeral table
    _inventoryLib().withdrawFromInventory(smartObjectId, outItems);
    //transfer the items to ephemeral owner who is the caller of this function
    _inventoryLib().depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, inItems);
  }

  /**
   * @notice Transfer items from ephemeral to inventory
   * @dev transfer items from ephemeral to inventory
   * @param smartObjectId is the smart object id
   * @param ephemeralInventoryOwner is the ephemeral inventory owner
   * @param outItems is the array of items to transfer
   */
  function inventoryToEphemeralTransferWithParam(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory outItems
  ) public hookable(smartObjectId, _systemId()) {
    address owner = IERC721(DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId())).ownerOf(
      smartObjectId
    );
    InventoryItem[] memory inItems = new InventoryItem[](outItems.length);

    for (uint i = 0; i < outItems.length; i++) {
      InventoryItem memory item = outItems[i];
      if (
        InventoryItemTable.get(_namespace().inventoryItemTableId(), smartObjectId, item.inventoryItemId).quantity <
        item.quantity
      ) {
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
      ItemTransferOffchainTable.set(
        _namespace().itemTransferTableId(),
        smartObjectId,
        item.inventoryItemId,
        owner,
        ephemeralInventoryOwner,
        item.quantity,
        block.timestamp
      );
    }

    //withdraw the items from inventory and deposit to ephemeral table
    _inventoryLib().withdrawFromInventory(smartObjectId, outItems);
    //transfer the items to ephemeral owner who is the caller of this function
    _inventoryLib().depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, inItems);
  }

  /**
   * @notice Transfer items from ephemeral to inventory
   * @dev transfer items from ephemeral to inventory
   * @param smartObjectId is the smart object id
   * @param items is the array of items to transfer
   */
  function ephemeralToInventoryTransfer(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public hookable(smartObjectId, _systemId()) {
    address owner = IERC721(DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId())).ownerOf(
      smartObjectId
    );
    address ephemeralInventoryOwner = _initialMsgSender();

    //check the caller of this function has enough items to transfer to the inventory
    for (uint i = 0; i < items.length; i++) {
      InventoryItem memory item = items[i];

      if (
        EphemeralInvItemTable
          .get(
            _namespace().ephemeralInventoryItemTableId(),
            smartObjectId,
            item.inventoryItemId,
            ephemeralInventoryOwner
          )
          .quantity < item.quantity
      ) {
        revert IInventoryErrors.Inventory_InvalidItemQuantity(
          "InventoryInteract: Not enough items to transfer",
          item.inventoryItemId,
          item.quantity
        );
      }

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchainTable.set(
        _namespace().itemTransferTableId(),
        smartObjectId,
        item.inventoryItemId,
        ephemeralInventoryOwner,
        owner,
        item.quantity,
        block.timestamp
      );
    }

    //withdraw the items from ephemeral and deposit to inventory table
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
    //transfer items to the ssu owner
    _inventoryLib().depositToInventory(smartObjectId, items);
  }

  /**
   * @notice Configure the interaction handler to restrict access
   * @dev configure the interaction handler by systemId and smartObject to interact with this system
   * @param smartObjectId is the smart object id
   * @param interactionParams is the interaction params
   */
  function configureInteractionHandler(
    uint256 smartObjectId,
    bytes memory interactionParams
  ) public hookable(smartObjectId, _systemId()) {
    //TODO configure the interaction handler
    //Configure the systemId which is allowed to call the interaction handler
    //TODO this should be restricted to the owner of the SSU
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().ephemeralInventorySystemId();
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: INVENTORY_DEPLOYMENT_NAMESPACE });
  }
}
