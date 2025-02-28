// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// External imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Project imports - types and interfaces
import { State } from "../../../../codegen/common.sol";
import { IERC721 } from "../eve-erc721-puppet/IERC721.sol";

// Project imports - tables
import { DeployableState } from "../../codegen/index.sol";
import { DeployableToken } from "../../codegen/index.sol";

// Project imports - utilities and systems
import { InventoryUtils } from "../inventory/InventoryUtils.sol";
import { inventoryInteractSystem } from "../../codegen/systems/InventoryInteractSystemLib.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";

contract AccessSystem is SmartObjectFramework {
  error Access_NotAdmin(address caller);
  error Access_NotDeployableOwner(address caller, uint256 objectId);
  error Access_NotAdminOrOwner(address caller, uint256 objectId);
  error Access_NotOwnerOrCanWithdrawFromInventory(address caller, uint256 objectId);
  error Access_NotOwnerOrCanDepositToInventory(address caller, uint256 objectId);
  error Access_NotDeployableOwnerOrInventoryInteractSystem(address caller, uint256 objectId);
  error Access_NotInventoryAdmin(address caller, uint256 smartObjectId);
  error Access_NotAdminOrDeployableSystem(address caller, uint256 objectId);

  function onlyOwnerOrCanWithdrawFromInventory(uint256 objectId, bytes memory data) public view {
    if (isOwner(_callMsgSender(1), objectId)) {
      return;
    }

    if (canWithdrawFromInventory(objectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwnerOrCanWithdrawFromInventory(_callMsgSender(1), objectId);
  }

  function onlyOwnerOrCanDepositToInventory(uint256 objectId, bytes memory data) public view {
    if (isOwner(_callMsgSender(1), objectId)) {
      return;
    }

    if (canDepositToInventory(objectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwnerOrCanDepositToInventory(_callMsgSender(1), objectId);
  }

  function onlyDeployableOwner(uint256 objectId, bytes memory data) public view {
    if (isOwner(_callMsgSender(1), objectId)) {
      return;
    }

    revert Access_NotDeployableOwner(_callMsgSender(1), objectId);
  }

  function onlyAdmin(uint256 objectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    revert Access_NotAdmin(_callMsgSender(1));
  }

  function onlyAdminOrDeployableOwner(uint256 objectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isOwner(_callMsgSender(1), objectId)) {
      return;
    }

    revert Access_NotAdminOrOwner(_callMsgSender(1), objectId);
  }

  function onlyDeployableOwnerOrInventoryInteractSystem(uint256 objectId, bytes memory data) public view {
    if (isOwner(_callMsgSender(1), objectId)) {
      return;
    }

    if (isInventoryInteractSystem(_callMsgSender())) {
      return;
    }

    revert Access_NotDeployableOwnerOrInventoryInteractSystem(_callMsgSender(1), objectId);
  }

  function onlyInventoryAdmin(uint256 smartObjectId, bytes memory data) public view {
    if (isInventoryAdmin(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotInventoryAdmin(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminOrDeployableSystem(uint256 objectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isDeployableSystem(_callMsgSender())) {
      return;
    }

    revert Access_NotAdminOrDeployableSystem(_callMsgSender(1), objectId);
  }

  function isAdmin(address caller) public view returns (bool) {
    bytes32 adminRole = bytes32("admin");
    return HasRole.getIsMember(adminRole, caller);
  }

  function isOwner(address caller, uint256 objectId) public view returns (bool) {
    bool isDeployable = DeployableState.getCreatedAt(objectId) != 0;
    if (!isDeployable) {
      return true;
    }

    address erc721Address = DeployableToken.getErc721Address();
    address owner = IERC721(erc721Address).ownerOf(objectId);
    return owner == caller;
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
