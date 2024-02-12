// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "../../codegen/world/IWorld.sol";
import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { ModuleTable } from "../../codegen/tables/ModuleTable.sol";
import { ClassAssociationTable } from "../../codegen/tables/ClassAssociationTable.sol";
import { ObjectAssociationTable } from "../../codegen/tables/ObjectAssociationTable.sol";
import { HookTargetBeforeTable } from "../../codegen/tables/HookTargetBeforeTable.sol";
import { HookTargetAfterTable } from "../../codegen/tables/HookTargetAfterTable.sol";
import { HookTable } from "../../codegen/tables/HookTable.sol";
import { ObjectClassMap } from "../../codegen/tables/ObjectClassMap.sol";
import { ICustomErrorSystem } from "../../codegen/world//ICustomErrorSystem.sol";
import { HookTableData } from "../../codegen/tables/HookTable.sol";
import { EntityType } from "../../types.sol";
import { EMPTY_MODULE_ID } from "../../constants.sol";

/**
 * @title EveSystem
 * @notice This is the base system which has all the helper functions for the other systems to inherit
 */
contract EveSystem is System {
  /**
   * @notice Executes the function only if the entity is associated with the module
   * @dev Module association is defined by the systems registered in the ModuleTable
   * @param entityId is the id of an object or class
   * @param functionSelector is the function selector of the function to be executed
   */
  modifier onlyAssociatedModule(
    uint256 entityId,
    ResourceId systemId,
    bytes4 functionSelector
  ) {
    _requireEntityRegistered(entityId);
    _requireSystemAssociatedWithModule(entityId, systemId, functionSelector);
    _;
  }

  /**
   * @notice Allows a function to be hooked before or after a function
   * @param entityId is the id of an object or class
   */
  modifier hookable(
    uint256 entityId,
    bytes32 systemId,
    bytes memory hookArgs
  ) {
    bytes4 functionSelector = bytes4(msg.data[:4]);
    uint256[] memory hookIds = _getEntityHooks(entityId);
    for (uint256 i = 0; i < hookIds.length; i++) {
      _executeBeforeHooks(hookIds[i], systemId, functionSelector, hookArgs);
    }
    _;
    for (uint256 i = 0; i < hookIds.length; i++) {
      _executeAfterHooks(hookIds[i], systemId, functionSelector, hookArgs);
    }
  }

  /**
   * @notice Reverts if the entity is not registered
   * @param entityId is the id of an object or class
   */
  function _requireEntityRegistered(uint256 entityId) internal view {
    if (!EntityTable.getDoesExists(entityId))
      revert ICustomErrorSystem.EntityNotRegistered(entityId, "EveSystem: Entity is not registered");
  }

  function _requireSystemAssociatedWithModule(
    uint256 entityId,
    ResourceId systemId,
    bytes4 functionSelector
  ) internal view {
    bool isAssociated = ClassAssociationTable.getIsAssociated(entityId) ||
      (ObjectAssociationTable.getIsAssociated(entityId) ||
        ClassAssociationTable.getIsAssociated(ObjectClassMap.get(entityId)));
    if (!isAssociated)
      revert ICustomErrorSystem.EntityNotAssociatedWithModule(
        entityId,
        "EveSystem: Entity is not associated with any module"
      );

    uint256 entityType = EntityTable.getEntityType(entityId);
    uint256[] memory moduleIds = _getModuleIds(entityId, entityType);
    _validateModules(moduleIds, systemId, functionSelector);

    //TODO Add logic for more granularity by function selectors.
  }

  function _getModuleIds(uint256 entityId, uint256 entityType) internal view returns (uint256[] memory) {
    if (entityType == uint256(EntityType.Class)) {
      return ClassAssociationTable.getModuleIds(entityId);
    } else if (entityType == uint256(EntityType.Object)) {
      uint256 classId = ObjectClassMap.get(entityId);
      return classId != 0 ? ClassAssociationTable.getModuleIds(classId) : ObjectAssociationTable.getModuleIds(entityId);
    }
  }

  function _validateModules(uint256[] memory moduleIds, ResourceId systemId, bytes4 functionSelector) internal view {
    bytes32 unwrappedSystemId = ResourceId.unwrap(systemId);
    bool isModuleFound = false;

    //TODO Below logic can be optimized by using supportsInterface as well
    for (uint256 i = 0; i < moduleIds.length; i++) {
      if (moduleIds[i] != EMPTY_MODULE_ID) {
        bool systemExists = ModuleTable.getDoesExists(moduleIds[i], unwrappedSystemId);
        if (systemExists) {
          isModuleFound = true;
          bytes32 registeredSystemId = ResourceId.unwrap(FunctionSelectors.getSystemId(functionSelector));
          if (registeredSystemId != unwrappedSystemId)
            revert ICustomErrorSystem.FunctionSelectorNotRegistered(
              functionSelector,
              "EveSystem: Function selector is not registered in the system"
            );
          break;
        }
      }
    }

    if (!isModuleFound)
      revert ICustomErrorSystem.ModuleNotFound("EveSystem: Module associated with the system is not found");
  }

  function _getEntityHooks(uint256 entityId) internal view returns (uint256[] memory) {
    uint256 entityType = EntityTable.getEntityType(entityId);
    if (entityType == uint256(EntityType.Class)) {
      return ClassAssociationTable.getHookIds(entityId);
    } else if (entityType == uint256(EntityType.Object)) {
      uint256 classId = ObjectClassMap.get(entityId);
      return classId != 0 ? ClassAssociationTable.getHookIds(classId) : ObjectAssociationTable.getHookIds(entityId);
    }
  }

  function _executeBeforeHooks(
    uint256 hookId,
    bytes32 systemId,
    bytes4 functionSelector,
    bytes memory hookArgs
  ) internal {
    uint256 targetId = uint256(keccak256(abi.encodePacked(systemId, functionSelector)));
    bool hasHook = HookTargetBeforeTable.getHasHook(hookId, targetId);
    if (hasHook) {
      _executeHook(hookId, hookArgs);
    }
  }

  function _executeAfterHooks(
    uint256 hookId,
    bytes32 systemId,
    bytes4 functionSelector,
    bytes memory hookArgs
  ) internal {
    uint256 targetId = uint256(keccak256(abi.encodePacked(systemId, functionSelector)));
    bool hasHook = HookTargetAfterTable.getHasHook(hookId, targetId);
    if (hasHook) {
      _executeHook(hookId, hookArgs);
    }
  }

  function _executeHook(uint256 hookId, bytes memory hookArgs) internal {
    HookTableData memory hookData = HookTable.get(hookId);
    bytes memory funcSelectorAndArgs = abi.encodePacked(hookData.functionSelector, hookArgs);

    ResourceId systemId = ResourceId.wrap(
      (bytes32(abi.encodePacked(RESOURCE_SYSTEM, hookData.namespace, hookData.hookName)))
    );
    //TODO replace with callFrom ? and get the delegator address from the hookrgs ?
    world().call(systemId, funcSelectorAndArgs);
  }

  //TODO This function can be replaced by storing the index in a MUD table
  function findIndex(uint256[] memory array, uint256 value) internal pure returns (uint256, bool) {
    for (uint256 i = 0; i < array.length; i++) {
      if (array[i] == value) {
        return (i, true);
      }
    }
    return (0, false);
  }

  /**
   * @notice Returns the world address
   * @return worldAddress_ The world address
   */
  function world() internal view returns (IWorld) {
    return IWorld(_world());
  }
}
