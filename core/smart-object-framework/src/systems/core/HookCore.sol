// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { ObjectClassMap } from "../../codegen/tables/ObjectClassMap.sol";
import { HookTable } from "../../codegen/tables/HookTable.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { HookTargetBeforeTable } from "../../codegen/tables/HookTargetBeforeTable.sol";
import { HookTargetAfterTable } from "../../codegen/tables/HookTargetAfterTable.sol";
import { ClassAssociationTable } from "../../codegen/tables/ClassAssociationTable.sol";
import { ObjectAssociationTable } from "../../codegen/tables/ObjectAssociationTable.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { HookType, EntityType } from "../../types.sol";

contract HookCore is EveSystem {
  /**
   * @notice Register the hook function to execute before or after a EVE function
   * @param namespace is the namespace where the hook function exists
   * @param name is the name of the hook function
   * @param functionId is the function selector of the hook function
   */
  function registerHook(bytes14 namespace, bytes16 name, bytes4 functionId) external {
    _registerHook(namespace, name, functionId);
  }

  /**
   * @notice Add the hook id to execute before or after a EVE function
   * @param hookId is the id of the hook function
   * @param hookType is the type of the hook function
   * @param systemSelector is the selector of the target system
   * @param functionSelector is the function selector of the target hook function
   */
  function addHook(uint256 hookId, HookType hookType, bytes32 systemSelector, bytes4 functionSelector) external {
    _addHook(hookId, hookType, systemSelector, functionSelector);
  }

  /**
   * @notice Remove the hook id added to a target function
   * @param hookId is the id of the hook function
   * @param hookType is the type Before/After a target function
   * @param systemSelector is the selector of the target system
   * @param functionSelector is the function selector of the target hook function
   */
  //TODO - instead of systemSelector and functionSelector, should we use targetId ?
  function removeHook(uint256 hookId, HookType hookType, bytes32 systemSelector, bytes4 functionSelector) external {
    _removeHook(hookId, hookType, systemSelector, functionSelector);
  }

  /**
   * @notice Associate a hook id to an entity
   * @param entityId is the id of the entity (Class/Object)
   * @param hookId is the id of the hook function
   */
  function associateHook(uint256 entityId, uint256 hookId) external {
    _associateHook(entityId, hookId);
  }

  //TODO Add a function to change the order of hook execution for a target function

  function _registerHook(bytes14 namespace, bytes16 name, bytes4 functionId) internal {
    bytes32 systemId = bytes32(abi.encodePacked(RESOURCE_SYSTEM, namespace, name));
    uint256 hookId = uint256(keccak256(abi.encodePacked(systemId, functionId)));
    if (HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookAlreadyRegistered(hookId, "HookCore: Hook already registered");

    HookTable.set(hookId, true, namespace, name, systemId, functionId);
  }

  function _addHook(uint256 hookId, HookType hookType, bytes32 systemSelector, bytes4 functionSelector) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookCore: Hook not registered");

    uint256 targetId = uint256(keccak256(abi.encodePacked(systemSelector, functionSelector)));
    if (hookType == HookType.BEFORE) {
      HookTargetBeforeTable.set(hookId, targetId, true, systemSelector, functionSelector);
    } else if (hookType == HookType.AFTER) {
      HookTargetAfterTable.set(hookId, targetId, true, systemSelector, functionSelector);
    }
  }

  //TODO -
  function _removeHook(uint256 hookId, HookType hookType, bytes32 systemSelector, bytes4 functionSelector) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookCore: Hook not registered");

    uint256 targetId = uint256(keccak256(abi.encodePacked(systemSelector, functionSelector)));
    if (hookType == HookType.BEFORE) {
      HookTargetBeforeTable.deleteRecord(hookId, targetId);
    } else if (hookType == HookType.AFTER) {
      HookTargetAfterTable.deleteRecord(hookId, targetId);
    }
  }

  function _associateHook(uint256 entityId, uint256 hookId) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookCore: Hook not registered");

    if (!EntityTable.getDoesExists(entityId))
      revert ICustomErrorSystem.EntityNotRegistered(entityId, "HookCore: Entity is not registered");

    if (EntityTable.getEntityType(entityId) == uint256(EntityType.Class)) {
      (uint256 index, bool exists) = findIndex(ClassAssociationTable.getHookIds(entityId), hookId);
      //TODO Do we need to revert ?
      if (!exists) {
        ClassAssociationTable.pushHookIds(entityId, hookId);
      }
    } else if (EntityTable.getEntityType(entityId) == uint256(EntityType.Object)) {
      (uint256 index, bool exists) = findIndex(ObjectAssociationTable.getHookIds(entityId), hookId);
      if (!exists) {
        ObjectAssociationTable.pushHookIds(entityId, hookId);
      }
    }
  }
}
