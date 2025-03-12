// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

// Local namespace tables
import { ObjectByEphemeral } from "../../codegen/tables/ObjectByEphemeral.sol";

// Local namespace system imports

import { OwnershipSystem, ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

contract AccessSystem is SmartObjectFramework {
  error Access_NotAdmin(address caller);
  error Access_NotOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminOrOwner(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanTransferToEphemeral(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanTransferFromEphemeral(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCanTransferToInventory(address caller, uint256 smartObjectId);
  error Access_NotOwnerOrCallAccess(address caller, uint256 smartObjectId);
  error Access_NotAdminOrCallAccess(address caller, uint256 smartObjectId);
  error Access_NotDirectAdminOrCallAccess(address caller, uint256 smartObjectId);
  
  function onlyOwnerOrCanTransferToEphemeralRole(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isOwner(smartObjectId, caller)) {
      return;
    }

    if (canTransferToEphemeral(smartObjectId, _callMsgSender())) {
      return;
    } else {
      caller = _callMsgSender();
    }

    revert Access_NotOwnerOrCanTransferToEphemeral(caller, smartObjectId);
  }

  function onlyOwnerOrCanTransferFromEphemeralRole(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isOwner(smartObjectId, caller)) {
      return;
    }

    if (canTransferFromEphemeral(smartObjectId, caller)) {
      return;
    } else {
      caller = _callMsgSender();
    }

    revert Access_NotOwnerOrCanTransferFromEphemeral(caller, smartObjectId);
  }

  function onlyOwnerOrCanTransferToInventoryRole(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isOwner(smartObjectId, caller)) {
      return;
    }

    if (canTransferToInventory(smartObjectId, caller)) {
      return;
    } else {
      caller = _callMsgSender();
    }

    revert Access_NotOwnerOrCanTransferToInventory(caller, smartObjectId);
  }

  function onlyOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyAdmin(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    revert Access_NotAdmin(_callMsgSender(1));
  }

  function onlyAdminOrOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotAdminOrOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminForCharactersOtherwiseAlsoOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (_callMsgSender() != smartCharacterSystem.getAddress()) {
      if (isOwner(smartObjectId, _callMsgSender(1))) {
        return;
      }
    }

    revert Access_NotAdminOrOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyOwnerOrCallAccess(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isOwner(smartObjectId, caller) && isAdmin(tx.origin)) {
      return;
    }

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotOwnerOrCallAccess(caller, smartObjectId);
  }

  function onlyAdminOrCallAccess(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isAdmin(caller)) {
      return;
    }
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }
    revert Access_NotAdminOrCallAccess(caller, smartObjectId);
  }

  function onlyAdminOrCallAccessWithScopeEnforced(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isAdmin(caller)) {
      return;
    }
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }
    uint256 associatedObject = ObjectByEphemeral.getSmartObjectId(smartObjectId);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    if (associatedObject == 0) {
      _scope(smartObjectId, callingSystemId);
    } else {
      _scope(associatedObject, callingSystemId);
    }

    revert Access_NotAdminOrCallAccess(caller, smartObjectId);
  }

    function onlyDirectAdminOrCallAccess(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    if (isAdmin(caller) && callCount == 1) {
      return;
    }

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotDirectAdminOrCallAccess(caller, smartObjectId);
  }

  function isAdmin(address caller) public view returns (bool) {
    bytes32 adminRole = bytes32("admin");
    return HasRole.getIsMember(adminRole, caller);
  }

  function isOwner(uint256 smartObjectId, address caller) public view returns (bool) {
    address owner = abi.decode(
      IWorldWithContext(_world()).callStatic(
        ownershipSystem.toResourceId(),
        abi.encodeWithSelector(OwnershipSystem.owner.selector, smartObjectId)
      ), (address));
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

}
