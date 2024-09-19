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

  modifier onlyEphInvOwnerOrSystemApproved(uint256 smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    
    // check enforcement
    if (_isEnforced(smartObjectId)) {
      bool ephInvOwnerAccess;
      if (ResourceId.unwrap(SystemRegistry.get(_msgSender())) == bytes32(0)) {
        ephInvOwnerAccess = true;
      }
      address[] memory accessListApproved = AccessRolePerObject.get(smartObjectId, APPROVED);
      bool approvedAccess;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          approvedAccess = true;
          break;
        }
      }

      if (!(ephInvOwnerAccess || approvedAccess)) {
        if (!ephInvOwnerAccess && ResourceId.unwrap(SystemRegistry.get(_msgSender())) == bytes32(0)) {
          revert IAccessSystemErrors.AccessSystem_NoPermission(_initialMsgSender(), bytes32("OWNER"));
        } else {
          revert IAccessSystemErrors.AccessSystem_NoPermission(_msgSender(), APPROVED);
        }
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
  ) public onlyEphInvOwnerOrSystemApproved(smartObjectId) {
    InventoryItem[] memory ephInvOut = new InventoryItem[](items.length);
    InventoryItem[] memory invIn = new InventoryItem[](items.length);
    
    for (uint i = 0; i < items.length; i++) {
      TransferItem memory item = items[i];
      //check the _initialMsgSender() has enough items to transfer to the inventory
      if (
        EphemeralInvItemTable.get(smartObjectId, item.inventoryItemId, _initialMsgSender()).quantity < item.quantity
      ) {
        revert IInventoryErrors.Inventory_InvalidItemQuantity(
          "InventoryInteractSystem: not enough items to transfer",
          item.inventoryItemId,
          item.quantity
        );
      }
      EntityRecordTableData memory itemRecord = EntityRecordTable.get(item.inventoryItemId);
      if(!itemRecord.recordExists) {
        revert IInventoryErrors.Inventory_InvalidItem(
          "InventoryInteractSystem: item is not created on-chain",
          itemRecord.typeId
        );
      }

      ephInvOut[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: _initialMsgSender(),
        itemId: itemRecord.itemId,
        typeId: itemRecord.typeId,
        volume: itemRecord.volume,
        quantity: item.quantity
      });

      invIn[i] = ephInvOut[i];
      invIn[i].owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);

      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchainTable.set(
        smartObjectId,
        item.inventoryItemId,
        _initialMsgSender(),
        IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId),
        item.quantity,
        block.timestamp
      );
    }
    //withdraw the items from ephemeral and deposit to inventory table
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, _initialMsgSender(), ephInvOut);
    //transfer items to the ssu owner
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

    for (uint i = 0; i < items.length; i++) {
      TransferItem memory item = items[i];
      if (InventoryItemTable.get(smartObjectId, item.inventoryItemId).quantity < item.quantity) {
        revert IInventoryErrors.Inventory_InvalidItemQuantity(
          "InventoryInteractSystem: not enough items to transfer",
          item.inventoryItemId,
          item.quantity
        );
      }
      
      EntityRecordTableData memory itemRecord = EntityRecordTable.get(item.inventoryItemId);
      if(!itemRecord.recordExists) {
        revert IInventoryErrors.Inventory_InvalidItem(
          "InventoryInteractSystem: item is not created on-chain",
          itemRecord.typeId
        );
      }

      invOut[i] = InventoryItem({
        inventoryItemId: item.inventoryItemId,
        owner: IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId),
        itemId: itemRecord.itemId,
        typeId: itemRecord.typeId,
        volume: itemRecord.volume,
        quantity: item.quantity
      });

      ephInvIn[i] = invOut[i];
      ephInvIn[i].owner = _initialMsgSender();


      //Emitting the event before the transfer to reduce loop execution, might need to consider security implications later
      ItemTransferOffchainTable.set(
        smartObjectId,
        item.inventoryItemId,
        IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId),
        _initialMsgSender(),
        item.quantity,
        block.timestamp
      );
    }

    //withdraw the items from inventory and deposit to ephemeral table
    _inventoryLib().withdrawFromInventory(smartObjectId, invOut);
    //transfer the items to ephemeral owner who is the caller of this function
    _inventoryLib().depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephInvIn);
  }

  function setApprovedAccessList(
    uint256 smartObjectId,
    address[] memory accessList
  ) public onlyOwner(smartObjectId) {
    AccessRolePerObject.set(smartObjectId, APPROVED, accessList);
  }

  function setAllTransferAccess(
    uint256 smartObjectId,
    bool isEnforced
  ) public onlyOwner(smartObjectId) {
    setEphToInvTransferAccess(smartObjectId, isEnforced);
    setInvToEphTransferAccess(smartObjectId, isEnforced);
  }

  function setEphToInvTransferAccess(
    uint256 smartObjectId,
    bool isEnforced
  ) public onlyOwner(smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    bytes32 target = keccak256(abi.encodePacked(systemId, this.ephemeralToInventoryTransfer.selector));
    AccessEnforcePerObject.set(smartObjectId, target, isEnforced);
  }

  function setInvToEphTransferAccess(
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
