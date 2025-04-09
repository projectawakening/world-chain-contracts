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
import { InventoryByEphemeral } from "../../codegen/tables/InventoryByEphemeral.sol";
import { EntityRecord } from "../../codegen/tables/EntityRecord.sol";
import { InventoryByEphemeral } from "../../codegen/tables/InventoryByEphemeral.sol";

// Local namespace system imports
import { OwnershipSystem, ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { SmartCharacterSystem, smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

// params
import { EntityRecordParams } from "../entity-record/types.sol";

contract AccessSystem is SmartObjectFramework {
  error Access_NotDirectAdmin(address caller);
  error Access_NotOwner(address caller, uint256 smartObjectId);
  error Access_NotDirectOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminOrOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminOrOwnerSupported(address caller, uint256 smartObjectId);
  error Access_NotDirectOwnerOrCanTransferToEphemeral(address caller, uint256 smartObjectId);
  error Access_CannotTransferFromEphemeral(address caller, uint256 smartObjectId);
  error Access_NotDirectEphemeralOwnerOrCanCrossTransferToEphemeral(address caller, uint256 smartObjectId);
  error Access_NotDirectOwnerOrCanTransferToInventory(address caller, uint256 smartObjectId);
  error Access_NotAdminSupportedOwnerOrCallAccess(address caller, uint256 smartObjectId);
  error Access_NotAdminOrCallAccess(address caller, uint256 smartObjectId);
  error Access_NotDirectAdminOrCallAccess(address caller, uint256 smartObjectId);
  error Access_NotOwnerWithAdminSupportAccess(address caller, uint256 smartObjectId);
  error Access_NotClassScoped(address caller, uint256 smartObjectId);
  error Access_NotCallAccess(address caller, uint256 smartObjectId);
  error Access_NotAdminSupported(address caller, uint256 smartObjectId);
  error Access_NotClassScopedAccess(address caller, uint256 smartObjectId);
  error Access_NotAdminOrClassScoped(address caller, uint256 smartObjectId);
  error Access_NotEphemeralOwnerOrCallAccess(address caller, uint256 smartObjectId);
  error Access_NotEphemeralOwnerOrCallAccessWithEphemeralOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminSupportedOrDirectOwner(address caller, uint256 smartObjectId);
  error Access_NotAdminSupportedOrDirectOwnerGates(address caller, uint256 smartObjectId);

  function onlyOwnerOrEphemeralTransferRole(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isOwner(smartObjectId, caller)) {
      return;
    }
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (canTransferToEphemeral(smartObjectId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotDirectOwnerOrCanTransferToEphemeral(caller, smartObjectId);
  }

  function onlyOwnerOrEphemeralCrossTransferRole(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    (, address fromEphemeralOwner, , ) = abi.decode(data, (uint256, address, address, bytes));
    if (callCount == 1 && caller == fromEphemeralOwner) {
      return;
    }

    if (canCrossTransferToEphemeral(smartObjectId, _callMsgSender())) {
      return;
    } else {
      caller = _callMsgSender();
    }

    revert Access_NotDirectEphemeralOwnerOrCanCrossTransferToEphemeral(caller, smartObjectId);
  }

  function onlyEphemeralOwnerOrTransferRole(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isEphemeralOwner(smartObjectId, caller, data)) {
      return;
    }
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (canTransferFromEphemeral(smartObjectId, msgSender)) {
      return;
    }

    revert Access_CannotTransferFromEphemeral(msgSender, smartObjectId);
  }

  function onlyOwnerOrInventoryTransferRole(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isOwner(smartObjectId, caller)) {
      return;
    }
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    if (canTransferToInventory(smartObjectId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotDirectOwnerOrCanTransferToInventory(caller, smartObjectId);
  }

  function onlyOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyDirectOwner(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    if (callCount == 1 && isOwner(smartObjectId, _callMsgSender(1))) {
      return;
    }

    revert Access_NotDirectOwner(_callMsgSender(1), smartObjectId);
  }

  function onlyDirectAdmin(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    if (callCount == 1 && isAdmin(_callMsgSender(1))) {
      return;
    }

    revert Access_NotDirectAdmin(_callMsgSender(1));
  }

  function onlyAdminSupportedAccess(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(tx.origin)) {
      return;
    }

    revert Access_NotAdminSupported(_callMsgSender(1), smartObjectId);
  }

  function adminSupportOrDirectOwner(uint256 smartObjectId, bytes memory data) public view {
    if (isOwner(smartObjectId, _callMsgSender(1)) || isAdmin(tx.origin)) {
      return;
    }

    revert Access_NotAdminSupportedOrDirectOwner(_callMsgSender(1), smartObjectId);
  }

  function adminSupportOrDirectOwnerGates(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isOwnerOfBothGates(_callMsgSender(1), data) && isAdmin(tx.origin)) {
      return;
    }

    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
    if (isClassScoped(classId, callingSystemId)) {
      return;
    }
    caller = msgSender;

    revert Access_NotAdminSupportedOrDirectOwnerGates(caller, smartObjectId);
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

  function onlyAdminOrOwnerSupported(uint256 smartObjectId, bytes memory data) public view {
    if (isAdmin(_callMsgSender(1))) {
      return;
    }

    if (isOwner(smartObjectId, _callMsgSender(1)) && isAdmin(tx.origin)) {
      return;
    }

    revert Access_NotAdminOrOwnerSupported(_callMsgSender(1), smartObjectId);
  }

  function onlyClassScopedOrCharAdminOrOwner(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    address caller = msgSender;
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
    if (callCount > 1 && isClassScoped(classId, callingSystemId)) {
      return;
    }

    caller = _callMsgSender(1);

    if (isAdmin(caller)) {
      return;
    }

    if (msgSender != smartCharacterSystem.getAddress()) {
      if (isOwner(smartObjectId, caller)) {
        return;
      }
    }

    revert Access_NotAdminOrOwner(caller, smartObjectId);
  }

  function onlyCallAccess(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    if (callCount > 1 && CallAccess.get(systemId, functionId, msgSender)) {
      return;
    }

    revert Access_NotCallAccess(msgSender, smartObjectId);
  }

  function onlyAdminSupportedOwnerOrCall(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isOwner(smartObjectId, caller) && isAdmin(tx.origin)) {
      return;
    }

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext();
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotAdminSupportedOwnerOrCallAccess(caller, smartObjectId);
  }

  function onlyDirectEphemeralOwnerOrCall(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isEphemeralOwner(smartObjectId, caller, data) && isAdmin(tx.origin)) {
      return;
    }

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotEphemeralOwnerOrCallAccess(caller, smartObjectId);
  }

  function onlyCallAccessOrDirectEphemeralOwner(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    address caller = _callMsgSender(1);
    if (callCount == 1 && isEphemeralOwner(smartObjectId, caller, data) && isAdmin(tx.origin)) {
      return;
    }

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    if (CallAccess.get(systemId, functionId, msgSender) && isEphemeralOwner(smartObjectId, caller, data)) {
      return;
    } else {
      caller = msgSender;
    }

    revert Access_NotEphemeralOwnerOrCallAccessWithEphemeralOwner(caller, smartObjectId);
  }

  function onlyAdminOrCallAccess(uint256 smartObjectId, bytes memory data) public view {
    address caller = _callMsgSender(1);
    if (isAdmin(caller)) {
      return;
    }
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else {
      caller = msgSender;
    }
    revert Access_NotAdminOrCallAccess(caller, smartObjectId);
  }

  function onlyCallAccessWithScopeEnforced(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    uint256 associatedObject = InventoryByEphemeral.getSmartObjectId(smartObjectId);
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

  function onlyAdminOrScopeEnforcedCall(uint256 smartObjectId, bytes memory data) public view {
    uint256 associatedObject = InventoryByEphemeral.getSmartObjectId(smartObjectId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
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

    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
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
    (ResourceId systemId, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
    if (callCount > 1 && isClassScoped(classId, callingSystemId)) {
      return;
    }

    revert Access_NotClassScoped(msgSender, smartObjectId);
  }

  function onlyAdminOrClassScopedAccess(uint256 smartObjectId, bytes memory data) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
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
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    (, , EntityRecordParams memory entityRecordParams) = abi.decode(data, (uint256, string, EntityRecordParams));
    uint256 classId = uint256(keccak256(abi.encodePacked(entityRecordParams.tenantId, entityRecordParams.typeId)));
    if (callCount > 1 && isClassScoped(classId, callingSystemId)) {
      return;
    }

    revert Access_NotClassScoped(msgSender, smartObjectId);
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
      ),
      (address)
    );
    return caller == owner;
  }

  function isEphemeralOwner(uint256 smartObjectId, address caller, bytes memory data) public view returns (bool) {
    (, address ephemeralOwner, ) = abi.decode(data, (uint256, address, bytes));
    if (caller == ephemeralOwner) {
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

  function isOwnerOfBothGates(address caller, bytes memory data) public view returns (bool) {
    (uint256 sourceGateId, uint256 destinationGateId) = abi.decode(data, (uint256, uint256));
    if (isOwner(sourceGateId, caller) && isOwner(destinationGateId, caller)) {
      return true;
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

  function canCrossTransferToEphemeral(uint256 smartObjectId, address caller) public view returns (bool) {
    bytes32 accessRole = keccak256(abi.encodePacked("CROSS_TRANSFER_TO_EPHEMERAL_ROLE", smartObjectId));
    return HasRole.getIsMember(accessRole, caller);
  }
}
