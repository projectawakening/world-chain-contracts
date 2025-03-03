// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { entitySystem } from "../../src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { tagSystem } from "../../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { roleManagementSystem } from "../../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

import { TagId } from "../../src/libs/TagId.sol";
import { TagParams } from "../../src/namespaces/evefrontier/systems/tag-system/types.sol";

import { SmartObjectFramework } from "../../src/inherit/SmartObjectFramework.sol";

contract UnscopedMock is SmartObjectFramework {
  // TagSystem.sol
  function callSetTag(uint256 entityId, TagParams memory tagParams) public {
    tagSystem.setTag(entityId, tagParams);
  }

  function callRemoveTag(uint256 entityId, TagId tagId) public {
    tagSystem.removeTag(entityId, tagId);
  }

  // EntitySystem.sol
  function callSetClassAccessRole(uint256 classId, bytes32 newAccessRole) public {
    entitySystem.setClassAccessRole(classId, newAccessRole);
  }

  function callSetObjectAccessRole(uint256 objectId, bytes32 newAccessRole) public {
    entitySystem.setObjectAccessRole(objectId, newAccessRole);
  }

  function callInstantiate(uint256 classId, uint256 objectId, address account) public {
    entitySystem.instantiate(classId, objectId, account);
  }

  function callDeleteClass(uint256 classId) public {
    entitySystem.deleteClass(classId);
  }

  function callDeleteObject(uint256 objectId) public {
    entitySystem.deleteObject(objectId);
  }

  // RoleManagement.sol
  function callScopedCreateRole(uint256 objectId, bytes32 role, bytes32 admin, address account) public {
    roleManagementSystem.scopedCreateRole(objectId, role, admin, account);
  }

  function callScopedTransferRoleAdmin(uint256 objectId, bytes32 role, bytes32 newAdmin) public {
    roleManagementSystem.scopedTransferRoleAdmin(objectId, role, newAdmin);
  }

  function callScopedGrantRole(uint256 objectId, bytes32 role, address account) public {
    roleManagementSystem.scopedGrantRole(objectId, role, account);
  }

  function callScopedRevokeRole(uint256 objectId, bytes32 role, address account) public {
    roleManagementSystem.scopedRevokeRole(objectId, role, account);
  }

  function callScopedRenounceRole(uint256 objectId, bytes32 role, address account) public {
    roleManagementSystem.scopedRenounceRole(objectId, role, account);
  }

  function callScopedRevokeAll(uint256 objectId, bytes32 role) public {
    roleManagementSystem.scopedRevokeAll(objectId, role);
  }
}
