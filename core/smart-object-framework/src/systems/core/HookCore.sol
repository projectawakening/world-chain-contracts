// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { EntityMapTable } from "../../codegen/tables/EntityMapTable.sol";
import { EntityAssociationTable } from "../../codegen/tables/EntityAssociationTable.sol";
import { HookTable } from "../../codegen/tables/HookTable.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { HookTargetBeforeTable } from "../../codegen/tables/HookTargetBeforeTable.sol";
import { HookTargetAfterTable } from "../../codegen/tables/HookTargetAfterTable.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { HookType } from "../../types.sol";

contract HookCore is EveSystem {
  /**
   * @notice Register the hook function to execute before or after a EVE function
   * @param systemId is the ResourceId of the system
   * @param functionId is the function selector of the hook function
   */
  function registerHook(ResourceId systemId, bytes4 functionId) external {
    _registerHook(systemId, functionId);
  }

  /**
   * @notice Add the hook id to execute before or after a EVE function
   * @param hookId is the id of the hook function
   * @param hookType is the type of the hook function
   * @param systemId is the id of the target system
   * @param functionSelector is the function selector of the target hook function
   */
  function addHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) external {
    _addHook(hookId, hookType, systemId, functionSelector);
  }

  /**
   * @notice Remove the hook id added to a target function
   * @param hookId is the id of the hook function
   * @param hookType is the type Before/After a target function
   * @param systemId is the selector of the target system
   * @param functionSelector is the function selector of the target hook function
   */
  //TODO - instead of systemSelector and functionSelector, should we use targetId ?
  function removeHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) external {
    _removeHook(hookId, hookType, systemId, functionSelector);
  }

  /**
   * @notice Associate a hook id to an entity
   * @param entityId is the id of the entity (Class/Object)
   * @param hookId is the id of the hook function
   */
  function associateHook(uint256 entityId, uint256 hookId) external {
    _associateHook(entityId, hookId);
  }

  /**
   * @notice Associate multiple hook ids to an entity
   */
  function associateHooks(uint256 entityId, uint256[] memory hookIds) external {
    for (uint256 i = 0; i < hookIds.length; i++) {
      _associateHook(entityId, hookIds[i]);
    }
  }

  /**
   * @notice Remove the association of a hook id with an entity
   * @param entityId is the id of the entity (Class/Object)
   * @param hookId is the id of the hook function
   */
  function removeEntityHookAssociation(uint256 entityId, uint256 hookId) external {
    _removeEntityHookAssociation(entityId, hookId);
  }

  //TODO Add a function to change the order of hook execution for a target function

  function _registerHook(ResourceId systemId, bytes4 functionId) internal {
    uint256 hookId = uint256(keccak256(abi.encodePacked(systemId, functionId)));
    if (HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookAlreadyRegistered(hookId, "HookCore: Hook already registered");

    HookTable.set(hookId, true, systemId, functionId);
  }

  function _addHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookCore: Hook not registered");

    uint256 targetId = uint256(keccak256(abi.encodePacked(systemId, functionSelector)));
    if (hookType == HookType.BEFORE) {
      HookTargetBeforeTable.set(hookId, targetId, true, systemId, functionSelector);
    } else if (hookType == HookType.AFTER) {
      HookTargetAfterTable.set(hookId, targetId, true, systemId, functionSelector);
    }
  }

  function _removeHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookCore: Hook not registered");

    uint256 targetId = uint256(keccak256(abi.encodePacked(systemId, functionSelector)));
    if (hookType == HookType.BEFORE) {
      HookTargetBeforeTable.deleteRecord(hookId, targetId);
    } else if (hookType == HookType.AFTER) {
      HookTargetAfterTable.deleteRecord(hookId, targetId);
    }
  }

  function _associateHook(uint256 entityId, uint256 hookId) internal {
    _requireEntityRegistered(entityId);
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookCore: Hook not registered");

    if (EntityMapTable.get(entityId).length > 0) {
      uint256[] memory taggedEntityIds = EntityMapTable.get(entityId);
      for (uint256 i = 0; i < taggedEntityIds.length; i++) {
        _requireHookeNotAssociated(taggedEntityIds[i], hookId);
      }
    } else {
      _requireHookeNotAssociated(entityId, hookId);
    }

    EntityAssociationTable.pushHookIds(entityId, hookId);
  }

  function _requireHookeNotAssociated(uint256 entityId, uint256 hookId) internal view {
    uint256[] memory hookIds = EntityAssociationTable.getHookIds(entityId);
    (, bool exists) = findIndex(hookIds, hookId);
    if (exists)
      revert ICustomErrorSystem.EntityAlreadyAssociated(
        entityId,
        hookId,
        "HookCore: Hook already associated with the entity"
      );
  }

  function _removeEntityHookAssociation(uint256 entityId, uint256 hookId) internal {
    uint256[] memory hookIds = EntityAssociationTable.getHookIds(entityId);
    (uint256 index, bool exists) = findIndex(hookIds, hookId);
    if (exists) {
      //Swap the last element to the index and pop the last element
      uint256 lastIndex = hookIds.length - 1;
      if (index != lastIndex) {
        EntityAssociationTable.updateHookIds(entityId, index, hookIds[lastIndex]);
      }
      EntityAssociationTable.popModuleIds(entityId);
    }
  }
}
