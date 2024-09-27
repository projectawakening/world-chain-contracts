// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { IERC721 } from "../../eve-erc721-puppet/IERC721.sol";
import { ItemTransferOffchainTable } from "../../../codegen/tables/ItemTransferOffchainTable.sol";
import { EphemeralInvItemTable } from "../../../codegen/tables/EphemeralInvItemTable.sol";
import { DeployableTokenTable } from "../../../codegen/tables/DeployableTokenTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";

import { Utils as InventoryUtils } from "../../../modules/inventory/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";
import { IAccessSystemErrors } from "../../access/interfaces/IAccessSystemErrors.sol";
import { Utils } from "../Utils.sol";

import { InventoryLib } from "../InventoryLib.sol";
import { InventoryItem, TransferItem } from "../types.sol";

import { AccessRolePerObject } from "../../../codegen/tables/AccessRolePerObject.sol";
import { AccessEnforcePerObject } from "../../../codegen/tables/AccessEnforcePerObject.sol";

contract InventoryInteractSystem is EveSystem {
  using Utils for bytes14;
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryLib for InventoryLib.World;

  bytes32 constant APPROVED = bytes32("APPROVED_ACCESS_ROLE");

  modifier onlyOwner(uint256 smartObjectId) {
    // check enforcement
    if (!(IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId) == _initialMsgSender())) {
      revert IAccessSystemErrors.AccessSystem_NoPermission(_initialMsgSender(), bytes32("OWNER"));
    }
    _;
  }

  modifier onlyOwnerOrSystemApproved(uint256 smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));

    // check enforcement
    if (_isEnforced(smartObjectId)) {
      bool ownerAccess;
      if (IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId) == _initialMsgSender()) {
        ownerAccess = true;
      }
      address[] memory accessListApproved = AccessRolePerObject.get(smartObjectId, APPROVED);
      bool approvedAccess;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          approvedAccess = true;
          break;
        }
      }

      if (!(ownerAccess || approvedAccess)) {
        if (!ownerAccess && ResourceId.unwrap(SystemRegistry.get(_msgSender())) == bytes32(0)) {
          revert IAccessSystemErrors.AccessSystem_NoPermission(_initialMsgSender(), bytes32("OWNER"));
        } else {
          revert IAccessSystemErrors.AccessSystem_NoPermission(_msgSender(), APPROVED);
        }
      }
    }
    _;
  }

  modifier onlySystemApproved(uint256 smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));

    // check enforcement
    if (_isEnforced(smartObjectId)) {
      address[] memory accessListApproved = AccessRolePerObject.get(smartObjectId, APPROVED);
      bool approvedAccess;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          approvedAccess = true;
          break;
        }
      }

      if (!approvedAccess) {
        revert IAccessSystemErrors.AccessSystem_NoPermission(_msgSender(), APPROVED);
      }
    }
    _;
  }

  /**
   * @notice Transfer items from ephemeral to inventory
   * @dev transfer items from ephemeral to inventory
   * @param smartObjectId is the smart object id
   * @param items is the array of items to transfer
   */
  function ephemeralToInventoryTransfer(
    uint256 smartObjectId,
    TransferItem[] memory items
  ) public onlySystemApproved(smartObjectId) {
    InventoryItem[] memory ephInvOut = new InventoryItem[](items.length);
    InventoryItem[] memory invIn = new InventoryItem[](items.length);
    address ephInvOwner = _initialMsgSender();
    address objectInvOwner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);
    for (uint i = 0; i < items.length; i++) {
      TransferItem memory item = items[i];
      //check the ephInvOwner has enough items to transfer to the inventory
      if (EphemeralInvItemTable.get(smartObjectId, item.inventoryItemId, ephInvOwner).quantity < item.quantity) {
        revert IInventoryErrors.Inventory_InvalidTransferItemQuantity(
          "InventoryInteractSystem: not enough items to transfer",
          smartObjectId,
          "EPHEMERAL",
          ephInvOwner,
          item.inventoryItemId,
          item.quantity
        );
      }
      EntityRecordTableData memory itemRecord = EntityRecordTable.get(item.inventoryItemId);

      ephInvOut[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: ephInvOwner,
        itemId: itemRecord.itemId,
        typeId: itemRecord.typeId,
        volume: itemRecord.volume,
        quantity: item.quantity
      });

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchainTable.set(
        smartObjectId,
        item.inventoryItemId,
        ephInvOwner,
        objectInvOwner,
        item.quantity,
        block.timestamp
      );
    }
    // withdraw the items from ephemeral and deposit to inventory table
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, ephInvOwner, ephInvOut);
    for (uint i = 0; i < items.length; i++) {
      invIn[i] = ephInvOut[i];
      invIn[i].owner = objectInvOwner;
    }
    _inventoryLib().depositToInventory(smartObjectId, invIn);
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
  ) public onlyOwnerOrSystemApproved(smartObjectId) {
    InventoryItem[] memory invOut = new InventoryItem[](items.length);
    InventoryItem[] memory ephInvIn = new InventoryItem[](items.length);
    address objectInvOwner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);

    for (uint i = 0; i < items.length; i++) {
      TransferItem memory item = items[i];
      if (InventoryItemTable.get(smartObjectId, item.inventoryItemId).quantity < item.quantity) {
        revert IInventoryErrors.Inventory_InvalidTransferItemQuantity(
          "InventoryInteractSystem: not enough items to transfer",
          smartObjectId,
          "OBJECT",
          objectInvOwner,
          item.inventoryItemId,
          item.quantity
        );
      }

      EntityRecordTableData memory itemRecord = EntityRecordTable.get(item.inventoryItemId);

      invOut[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: objectInvOwner,
        itemId: itemRecord.itemId,
        typeId: itemRecord.typeId,
        volume: itemRecord.volume,
        quantity: item.quantity
      });

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchainTable.set(
        smartObjectId,
        item.inventoryItemId,
        objectInvOwner,
        ephemeralInventoryOwner,
        item.quantity,
        block.timestamp
      );
    }

    //withdraw the items from inventory and deposit to ephemeral inventory
    _inventoryLib().withdrawFromInventory(smartObjectId, invOut);
    for (uint i = 0; i < items.length; i++) {
      ephInvIn[i] = invOut[i];
      ephInvIn[i].owner = ephemeralInventoryOwner;
    }
    _inventoryLib().depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephInvIn);
  }

  function setApprovedAccessList(uint256 smartObjectId, address[] memory accessList) public onlyOwner(smartObjectId) {
    AccessRolePerObject.set(smartObjectId, APPROVED, accessList);
  }

  function setAllInventoryTransferAccess(uint256 smartObjectId, bool isEnforced) public onlyOwner(smartObjectId) {
    setEphemeralToInventoryTransferAccess(smartObjectId, isEnforced);
    setInventoryToEphemeralTransferAccess(smartObjectId, isEnforced);
  }

  function setEphemeralToInventoryTransferAccess(
    uint256 smartObjectId,
    bool isEnforced
  ) public onlyOwner(smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    bytes32 target = keccak256(abi.encodePacked(systemId, this.ephemeralToInventoryTransfer.selector));
    AccessEnforcePerObject.set(smartObjectId, target, isEnforced);
  }

  function setInventoryToEphemeralTransferAccess(
    uint256 smartObjectId,
    bool isEnforced
  ) public onlyOwner(smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    bytes32 target = keccak256(abi.encodePacked(systemId, this.inventoryToEphemeralTransfer.selector));
    AccessEnforcePerObject.set(smartObjectId, target, isEnforced);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().inventoryInteractSystemId();
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: INVENTORY_DEPLOYMENT_NAMESPACE });
  }

  function _isEnforced(uint256 smartObjectId) private view returns (bool) {
    ResourceId systemId = SystemRegistry.get(address(this));
    bytes32 target = keccak256(abi.encodePacked(systemId, msg.sig));
    return AccessEnforcePerObject.get(smartObjectId, target);
  }
}
