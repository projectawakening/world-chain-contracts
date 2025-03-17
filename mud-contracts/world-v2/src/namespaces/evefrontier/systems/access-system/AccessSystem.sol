// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { EntityTagMap } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/EntityTagMap.sol";
import { TagId, TagIdLib } from "@eveworld/smart-object-framework-v2/src/libs/TagId.sol";
import { TAG_TYPE_PROPERTY, TAG_TYPE_RESOURCE_RELATION, TAG_IDENTIFIER_CLASS } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/types.sol";
import { HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

// Local namespace tables
import { ObjectByEphemeral } from "../../codegen/tables/ObjectByEphemeral.sol";
import { EntityRecord } from "../../codegen/tables/EntityRecord.sol";

// Local namespace system imports
import { OwnershipSystem, ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

// params
import { EntityRecordParams } from "../entity-record/types.sol";

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
  error Access_NotOwnerWithAdminSupportAccess(address caller, uint256 smartObjectId);
  error Access_NotClassScoped(address caller, uint256 smartObjectId);
  error Access_NotCallAccess(address caller, uint256 smartObjectId);
  error Access_NotAdminSupported(address caller, uint256 smartObjectId);
  error Access_NotClassScopedAccess(address caller, uint256 smartObjectId);
  error Access_NotAdminOrClassScoped(address caller, uint256 smartObjectId);
  error Access_NotEphemeralOwnerOrCallAccess(address caller, uint256 smartObjectId);

  function onlyOwnerOrCanTransferToEphemeralRoleAccess(uint256 smartObjectId, bytes memory data) public view {
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

  function onlyOwnerOrCanTransferFromEphemeralRoleAccess(uint256 smartObjectId, bytes memory data) public view {
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

  function onlyOwnerOrCanTransferToInventoryRoleAccess(uint256 smartObjectId, bytes memory data) public view {
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

  function onlyOwnerAccess(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminAccess(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    revert Access_NotAdmin(_callMsgSender(1));
  }

  function onlyAdminSupportedAccess(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(tx.origin)) {
      return;
    }

    revert Access_NotAdminSupported(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminOrOwnerAccess(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotAdminOrOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminForCharactersOtherwiseAlsoOwnerAccess(uint256 smartObjectId, bytes memory data) public view {
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

  function onlyCallAccess(uint256 smartObjectId, bytes memory data) public view {

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (callCount > 1 && CallAccess.get(systemId, functionId, msgSender)) {
      return;
    }

    revert Access_NotCallAccess(msgSender, smartObjectId);
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

  function onlyDirectEphemeralOwnerOrCallAccess(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isEphemeralOwner(smartObjectId, caller, data) && isAdmin(tx.origin)) {
      return;
    }

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotEphemeralOwnerOrCallAccess(caller, smartObjectId);
  }

  function onlyDirectEphemeralOwnerOrCallAccessWithOwner(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isEphemeralOwner(smartObjectId, caller, data) && isAdmin(tx.origin)) {
      return;
    }

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (CallAccess.get(systemId, functionId, msgSender) && isEphemeralOwner(smartObjectId, caller, data)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotEphemeralOwnerOrCallAccess(caller, smartObjectId);
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

  function onlyCallAccessWithScopeEnforced(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    uint256 associatedObject = ObjectByEphemeral.getSmartObjectId(smartObjectId);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    if (associatedObject == 0) {
      _scope(smartObjectId, callingSystemId);
    } else {
      _scope(associatedObject, callingSystemId);
    }

    if (callCount > 1 && CallAccess.get(systemId, functionId, msgSender)) {
      return;
    }

    revert Access_NotCallAccess(msgSender, smartObjectId);
  }

  function onlyAdminOrCallAccessWithScopeEnforced(uint256 smartObjectId, bytes memory data) public view {
    uint256 associatedObject = ObjectByEphemeral.getSmartObjectId(smartObjectId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    if (associatedObject == 0) {
      _scope(smartObjectId, callingSystemId);
    } else {
      _scope(associatedObject, callingSystemId);
    }

    address caller = _callMsgSender(1);
    if (isAdmin(caller)) {
      return;
    }

    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
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

  function onlyOwnerWithAdminSupportAccess(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1)) && isAdmin(tx.origin)) {
      return;
    }

    revert Access_NotOwnerWithAdminSupportAccess(_callMsgSender(1), smartObjectId);
  }

  function onlyClassScopedAccess(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    uint256 classId = uint256(keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId))));
    if (callCount > 1 && isClassScoped(classId, callingSystemId)) {
      return;
    }

    revert Access_NotClassScoped(_callMsgSender(1), smartObjectId);
  }

  function onlyAdminOrClassScopedAccess(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    uint256 classId = uint256(keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId))));
    if (callCount > 1 && isClassScoped(classId, callingSystemId)) {
      return;
    }

    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    revert Access_NotAdminOrClassScoped(_callMsgSender(1), smartObjectId);
  }

  function onlySmartAssemblyClassScopedAccess(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    (, , EntityRecordParams memory entityRecordParams) = abi.decode(data, (uint256, string, EntityRecordParams));
    uint256 classId = uint256(keccak256(abi.encodePacked(entityRecordParams.tenantId, entityRecordParams.typeId)));
    if (callCount > 1 && isClassScoped(classId, callingSystemId)) {
      return;
    }

    revert Access_NotClassScoped(_callMsgSender(1), smartObjectId);
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

  function isEphemeralOwner(uint256 smartObjectId, address caller, bytes memory data) public view returns (bool) {
    (, address ephemeralOwner, ) = abi.decode(data, (uint256, address, bytes));
    if ( caller == ephemeralOwner) {
      return true;
    }
    return false;
  }

  function isClassScoped(uint256 classId, ResourceId systemId) public view returns (bool) {
    TagId systemTagId = TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(systemId)));
    if (EntityTagMap.getHasTag(classId, TagIdLib.encode(TAG_TYPE_PROPERTY, TAG_IDENTIFIER_CLASS))) {
      if (EntityTagMap.getHasTag(classId, systemTagId)) {
        return true;
      }
    }
    return false;
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
