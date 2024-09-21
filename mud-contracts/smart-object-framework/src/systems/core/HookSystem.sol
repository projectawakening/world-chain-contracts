// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { EntityMap } from "../../codegen/tables/EntityMap.sol";
import { EntityAssociation } from "../../codegen/tables/EntityAssociation.sol";
import { HookTable } from "../../codegen/tables/HookTable.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { HookTargetBefore } from "../../codegen/tables/HookTargetBefore.sol";
import { HookTargetAfter } from "../../codegen/tables/HookTargetAfter.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { HookType } from "../../types.sol";

import { Utils } from "../../utils.sol";

contract HookSystem is EveSystem {
  using Utils for bytes14;

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
  function addHook(
    uint256 hookId,
    HookType hookType,
    ResourceId systemId,
    bytes4 functionSelector
  ) external hookable(uint256(keccak256(abi.encodePacked(systemId, functionSelector))), _systemId()) {
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
  function removeHook(
    uint256 hookId,
    HookType hookType,
    ResourceId systemId,
    bytes4 functionSelector
  ) external hookable(uint256(keccak256(abi.encodePacked(systemId, functionSelector))), _systemId()) {
    _removeHook(hookId, hookType, systemId, functionSelector);
  }

  /**
   * @notice Associate a hook id to an entity
   * @param entityId is the id of the entity (Class/Object)
   * @param hookId is the id of the hook function
   */
  function associateHook(uint256 entityId, uint256 hookId) external hookable(entityId, _systemId()) {
    _associateHook(entityId, hookId);
  }

  /**
   * @notice Associate multiple hook ids to an entity
   */
  function associateHooks(uint256 entityId, uint256[] memory hookIds) external hookable(entityId, _systemId()) {
    for (uint256 i = 0; i < hookIds.length; i++) {
      _associateHook(entityId, hookIds[i]);
    }
  }

  /**
   * @notice Remove the association of a hook id with an entity
   * @param entityId is the id of the entity (Class/Object)
   * @param hookId is the id of the hook function
   */
  function removeEntityHookAssociation(uint256 entityId, uint256 hookId) external hookable(entityId, _systemId()) {
    _removeEntityHookAssociation(entityId, hookId);
  }

  //TODO Add a function to change the order of hook execution for a target function

  function _registerHook(ResourceId systemId, bytes4 functionId) internal {
    uint256 hookId = uint256(keccak256(abi.encodePacked(systemId, functionId)));
    if (HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookAlreadyRegistered(hookId, "HookSystem: Hook already registered");

    HookTable.set(hookId, true, systemId, functionId);
  }

  function _addHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookSystem: Hook not registered");

    uint256 targetId = uint256(keccak256(abi.encodePacked(systemId, functionSelector)));
    if (hookType == HookType.BEFORE) {
      HookTargetBefore.set(hookId, targetId, true, systemId, functionSelector);
    } else if (hookType == HookType.AFTER) {
      HookTargetAfter.set(hookId, targetId, true, systemId, functionSelector);
    }
  }

  function _removeHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) internal {
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookSystem: Hook not registered");

    uint256 targetId = uint256(keccak256(abi.encodePacked(systemId, functionSelector)));
    if (hookType == HookType.BEFORE) {
      HookTargetBefore.deleteRecord(hookId, targetId);
    } else if (hookType == HookType.AFTER) {
      HookTargetAfter.deleteRecord(hookId, targetId);
    }
  }

  function _associateHook(uint256 entityId, uint256 hookId) internal {
    _requireEntityRegistered(entityId);
    if (!HookTable.getIsHook(hookId))
      revert ICustomErrorSystem.HookNotRegistered(hookId, "HookSystem: Hook not registered");

    if (EntityMap.get(entityId).length > 0) {
      uint256[] memory taggedEntityIds = EntityMap.get(entityId);
      for (uint256 i = 0; i < taggedEntityIds.length; i++) {
        _requireHookeNotAssociated(taggedEntityIds[i], hookId);
      }
    } else {
      _requireHookeNotAssociated(entityId, hookId);
    }

    EntityAssociation.pushHookIds(entityId, hookId);
  }

  function _requireHookeNotAssociated(uint256 entityId, uint256 hookId) internal view {
    uint256[] memory hookIds = EntityAssociation.getHookIds(entityId);
    (, bool exists) = findIndex(hookIds, hookId);
    if (exists)
      revert ICustomErrorSystem.EntityAlreadyAssociated(
        entityId,
        hookId,
        "HookSystem: Hook already associated with the entity"
      );
  }

  function _removeEntityHookAssociation(uint256 entityId, uint256 hookId) internal {
    uint256[] memory hookIds = EntityAssociation.getHookIds(entityId);
    (uint256 index, bool exists) = findIndex(hookIds, hookId);
    if (exists) {
      //Swap the last element to the index and pop the last element
      uint256 lastIndex = hookIds.length - 1;
      if (index != lastIndex) {
        EntityAssociation.updateHookIds(entityId, index, hookIds[lastIndex]);
      }
      EntityAssociation.popModuleIds(entityId);
    }
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().hookSystemId();
  }
}
