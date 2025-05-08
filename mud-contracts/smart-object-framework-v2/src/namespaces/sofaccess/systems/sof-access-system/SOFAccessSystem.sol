// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

import { Entity } from "../../../evefrontier/codegen/tables/Entity.sol";
import { EntityTagMap } from "../../../evefrontier/codegen/tables/EntityTagMap.sol";

import { Role } from "../../../evefrontier/codegen/tables/Role.sol";
import { HasRole } from "../../../evefrontier/codegen/tables/HasRole.sol";
import { CallAccess } from "../../../evefrontier/codegen/tables/CallAccess.sol";

import { TagId, TagIdLib } from "../../../../libs/TagId.sol";

import { TAG_TYPE_PROPERTY, TAG_TYPE_ENTITY_RELATION, TAG_TYPE_RESOURCE_RELATION, TAG_IDENTIFIER_CLASS, TagParams, EntityRelationValue, ResourceRelationValue } from "../../../evefrontier/systems/tag-system/types.sol";

import { IWorldWithContext } from "../../../../IWorldWithContext.sol";

import { SmartObjectFramework } from "../../../../inherit/SmartObjectFramework.sol";

/**
 * @title SOFAccessSystem
 * @author CCP Games
 * @dev Handles access control logic for SOF Systems (EntitySystem and TagSystem)
 */
contract SOFAccessSystem is SmartObjectFramework {
  using WorldResourceIdInstance for ResourceId;

  error SOFAccess_AccessDenied(uint256 entityId, address caller);

  /**
   * @notice Validates if caller has the required role to access an entity (and is directly calling)
   * @param entityId The ID of the entity to check access for
   * @param targetCallData The calldata of the target function
   * @dev Reverts if caller doesn't have the required role
   */
  function allowDirectAccessRoleOnly(uint256 entityId, bytes memory targetCallData) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    if (callCount == 1 && _checkAccessRole(entityId, _callMsgSender(1))) {
      return;
    }

    revert SOFAccess_AccessDenied(entityId, _callMsgSender(1));
  }

  /**
   * @notice Validates if caller has the required class access role for an entity AND if the call is direct to the target function
   * @param entityId The ID of the entity to check access for
   * @param targetCallData The calldata of the target function
   * @dev Reverts if caller doesn't have the required class access role, if this is a system-to-system call, or if somone called this access logic directly
   */
  function allowDirectClassAccessRoleOnly(uint256 entityId, bytes memory targetCallData) public view {
    uint256 classId = _getClassId(entityId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext();

    if (callCount == 1 && _checkAccessRole(classId, msgSender)) {
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for only class-scoped system-to-system calls only (no direct calls)
   * @param entityId The ID of the entity (class or object) to check
   * @param targetCallData The calldata of the target function
   */
  function allowClassScopedSystemOnly(uint256 entityId, bytes memory targetCallData) public view {
    uint256 classId = _getClassId(entityId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    if (callCount > 1 && _checkClassScopedSystem(classId, callingSystemId)) {
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for class-scoped systems or direct class access role membership (for a class if a classId is passed, or the object's class if an objectId is passed)
   * @param entityId The ID of the entity (class or object) to check
   * @param targetCallData The calldata of the target function
   * @dev Handles both direct calls (call depth 1) and class system-scoped calls (call depth > 1)
   */
  function allowClassScopedSystemOrDirectAccessRole(uint256 entityId, bytes memory targetCallData) public view {
    uint256 classId = _getClassId(entityId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    if (callCount > 1 && _checkClassScopedSystem(classId, callingSystemId)) {
      // system-to-system call case
      return;
    } else if (callCount == 1 && _checkAccessRole(entityId, msgSender)) {
      // entry point direct call case
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for class-scoped systems or direct access role membership
   * @param entityId The ID of the entity (class or object) to check
   * @param targetCallData The calldata of the target function
   * @dev Handles both direct calls (call depth 1) and class system-scoped calls (call depth > 1)
   */
  function allowClassScopedSystemOrDirectClassAccessRole(uint256 entityId, bytes memory targetCallData) public view {
    uint256 classId = _getClassId(entityId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    if (callCount > 1 && _checkClassScopedSystem(classId, callingSystemId)) {
      // system-to-system call case
      return;
    } else if (callCount == 1 && _checkAccessRole(classId, msgSender)) {
      // entry point direct call case
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates CallAccess only
   * @param entityId The ID of the entity to check access for (object or class)
   * @param targetCallData The calldata of the target function
   * @dev Currently handles access control for EntitySystem.scopedRegisterClass, allowing calls from EveSystem, InventorySystem, and EphemeralInventorySystem
   */
  function allowCallAccessOnly(uint256 entityId, bytes memory targetCallData) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );

    if (callCount > 1 && CallAccess.get(systemId, functionId, msgSender)) {
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for EntitySystem or direct role access
   * @param entityId The ID of the entity to check access for (object or class)
   * @param targetCallData The calldata of the target function
   * @dev Handles access control for explictly set CallAccess System calls or directly via a role member)
   * @dev TODO: Add HookSystem.sol access to this when implemented
   */
  function allowCallAccessOrDirectAccessRole(uint256 entityId, bytes memory targetCallData) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );

    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else if (callCount == 1 && _checkAccessRole(entityId, msgSender)) {
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for EntitySystem or class-scoped system
   * @param entityId The ID of the entity to check access for (object or class)
   * @param targetCallData The calldata of the target function
   * @dev Currently handles access control for RoleManagementSystem.sol scoped functions, allowing for flexible class scoped System call and CallAccess defined calls
   */
  function allowCallAccessOrClassScopedSystem(uint256 entityId, bytes memory targetCallData) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    uint256 classId = _getClassId(entityId);

    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else if (callCount > 1 && _checkClassScopedSystem(classId, callingSystemId)) {
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for class-scoped systems or direct access role (for class access role if a classId was passed, or an object access role if an objectId was passed)
   * @param entityId The ID of the object to check access for
   * @param targetCallData The calldata of the target function
   * @dev Handles both direct calls (call depth 1) and class system-scoped calls (call depth > 1)
   */
  function allowCallAccessOrClassScopedSystemOrDirectAccessRole(
    uint256 entityId,
    bytes memory targetCallData
  ) public view {
    uint256 classId = _getClassId(entityId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else if (_checkClassScopedSystem(classId, callingSystemId)) {
      // system-to-system call case
      return;
    } else if (callCount == 1 && _checkAccessRole(entityId, msgSender)) {
      // entry point direct call case
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Validates access for class-scoped systems or direct class access role membership (for a class if a classId is passed, or the object's class if an objectId is passed)
   * @param entityId The ID of the entity (class or object) to check
   * @param targetCallData The calldata of the target function
   * @dev Handles both direct calls (call depth 1) and class system-scoped calls (call depth > 1) and CallAccess defined calls
   */
  function allowCallAccessOrClassScopedSystemOrDirectClassAccessRole(
    uint256 entityId,
    bytes memory targetCallData
  ) public view {
    uint256 classId = _getClassId(entityId);
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (ResourceId systemId, bytes4 functionId, address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      callCount
    );
    ResourceId callingSystemId = SystemRegistry.get(msgSender);

    if (CallAccess.get(systemId, functionId, msgSender)) {
      return;
    } else if (callCount > 1 && _checkClassScopedSystem(classId, callingSystemId)) {
      // system-to-system call case
      return;
    } else if (callCount == 1 && _checkAccessRole(classId, msgSender)) {
      // entry point direct call case
      return;
    }

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  /**
   * @notice Blocks all calls
   * @param entityId The ID of the entity (class or object) to check
   * @param targetCallData The calldata of the target function
   * @dev Handles calls to EntitySystem.deleteClass, currently there are too many un-resolved data dependencies to allow for any access to this function
   */
  function noAllowances(uint256 entityId, bytes memory targetCallData) public view {
    uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);

    revert SOFAccess_AccessDenied(entityId, msgSender);
  }

  function _getClassId(uint256 entityId) private view returns (uint256) {
    uint256 classId;
    if (entityId != 0) {
      // entityRelationValue requires an entry in EntityTagMap and entityId 0 cannot have an entry
      if (EntityTagMap.getHasTag(entityId, TagIdLib.encode(TAG_TYPE_PROPERTY, TAG_IDENTIFIER_CLASS))) {
        classId = entityId;
      } else {
        EntityRelationValue memory entityRelationValue = abi.decode(
          EntityTagMap.getValue(entityId, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(entityId)))),
          (EntityRelationValue)
        );
        classId = entityRelationValue.relatedEntityId;
      }
    }
    return classId;
  }

  function _checkClassScopedSystem(uint256 classId, ResourceId callingSystemId) private view returns (bool) {
    return
      EntityTagMap.getHasTag(
        classId,
        TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(callingSystemId)))
      );
  }

  function _checkAccessRole(uint256 entityId, address caller) private view returns (bool) {
    return HasRole.getIsMember(Entity.getAccessRole(entityId), caller);
  }
}
