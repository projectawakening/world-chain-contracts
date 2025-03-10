// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace system imports
import { inventoryInteractSystem } from "../../codegen/systems/InventoryInteractSystemLib.sol";
import { ephemeralInteractSystem } from "../../codegen/systems/EphemeralInteractSystemLib.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";

contract AccessSystem is SmartObjectFramework {
  error Access_NotAdmin(address caller);
  error Access_NotDeployableOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminOrOwner(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanTransferToEphemeral(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanTransferFromEphemeral(address caller, uint256 smartObjectId);
  error Access_NotDeployableOwnerOrInventoryInteractSystem(address caller, uint256 smartObjectId);
  error Access_NotInventoryAdmin(address caller, uint256 smartObjectId);
  error Access_NotAdminOrDeployableSystem(address caller, uint256 smartObjectId);

  function onlyOwnerOrCanTransferToEphemeral(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender())) {
      return;
    }

    if (canTransferToEphemeral(smartObjectId, _callMsgSender())) {
      return;
    }

    revert Access_NotOwnerOrCanTransferToEphemeral(_callMsgSender(), smartObjectId);
  }

  function onlyOwnerOrCanTransferFromEphemeral(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender())) {
      return;
    }

    if (canTransferFromEphemeral(smartObjectId, _callMsgSender())) {
      return;
    }

    revert Access_NotOwnerOrCanTransferFromEphemeral(_callMsgSender(), smartObjectId);
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
    address owner = ownershipSystem.owner(smartObjectId);
    return caller == owner;
  }

  function canTransferFromEphemeral(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_FROM_EPHEMERAL_ROLE", smartObjectId));
    return HasRole.getIsMember(accessRole, caller);
  }

  function canTransferToEphemeral(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_TO_EPHEMERAL_ROLE", smartObjectId));
    return HasRole.getIsMember(accessRole, caller);
  }

  function canTransferToInventory(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_TO_INVENTORY_ROLE", smartObjectId));
    return HasRole.getIsMember(accessRole, caller);
  }

  function isInventoryInteractSystem(address caller) public view returns (bool) {
    return caller == inventoryInteractSystem.getAddress();
  }

  function isEphemeralInteractSystem(address caller) public view returns (bool) {
    return caller == ephemeralInteractSystem.getAddress();
  }

  function isDeployableSystem(address caller) public view returns (bool) {
    return caller == deployableSystem.getAddress();
  }
}
