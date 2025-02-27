// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";
import { InventoryUtils } from "../inventory/InventoryUtils.sol";
import { inventoryInteractSystem } from "../../codegen/systems/InventoryInteractSystemLib.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";

contract AccessSystem is SmartObjectFramework {
  error Access_NotAdmin(address caller);
  error Access_NotDeployableOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminOrOwner(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanWithdrawFromInventory(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanDepositToInventory(address caller, uint256 smartObjectId);
  error Access_NotDeployableOwnerOrInventoryInteractSystem(address caller, uint256 smartObjectId);
  error Access_NotInventoryAdmin(address caller, uint256 smartObjectId);
  error Access_NotAdminOrDeployableSystem(address caller, uint256 smartObjectId);

  function onlyOwnerOrCanWithdrawFromInventory(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    if (canWithdrawFromInventory(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwnerOrCanWithdrawFromInventory(_callMsgSender(1), smartObjectId);
  }

  function onlyOwnerOrCanDepositToInventory(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    if (canDepositToInventory(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwnerOrCanDepositToInventory(_callMsgSender(1), smartObjectId);
  }

  function onlyDeployableOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotDeployableOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyAdmin(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    revert Access_NotAdmin(_callMsgSender(1));
  }

  function onlyAdminOrDeployableOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotAdminOrOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyDeployableOwnerOrInventoryInteractSystem(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    if (isInventoryInteractSystem(_callMsgSender())) {
      return;
    }

    revert Access_NotDeployableOwnerOrInventoryInteractSystem(_callMsgSender(1), smartObjectId);
  }

  function onlyInventoryAdmin(uint256 smartObjectId, bytes memory data) public view {
    if (isInventoryAdmin(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotInventoryAdmin(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminOrDeployableSystem(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isDeployableSystem(_callMsgSender())) {
      return;
    }

    revert Access_NotAdminOrDeployableSystem(_callMsgSender(1), smartObjectId);
  }

  function isAdmin(address caller) public view returns (bool) {
    bytes32 adminRole = bytes32("admin");
    return HasRole.getIsMember(adminRole, caller);
  }

  function isOwner(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 ownerRole = keccak256(abi.encodePacked("OWNER_ROLE", smartObjectId));
    return HasRole.getIsMember(ownerRole, caller);
  }

  function canWithdrawFromInventory(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 accessRole = InventoryUtils.getInventoryToEphemeralTransferAccessRole(smartObjectId);
    return HasRole.getIsMember(accessRole, caller);
  }

  function canDepositToInventory(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 accessRole = InventoryUtils.getEphemeralToInventoryTransferAccessRole(smartObjectId);
    return HasRole.getIsMember(accessRole, caller);
  }

  function isInventoryInteractSystem(address caller) public view returns (bool) {
    return caller == inventoryInteractSystem.getAddress();
  }

  function isInventoryAdmin(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 adminAccessRole = InventoryUtils.getAdminAccessRole(smartObjectId);
    return HasRole.getIsMember(adminAccessRole, caller);
  }

  function isDeployableSystem(address caller) public view returns (bool) {
    return caller == deployableSystem.getAddress();
  }
}
