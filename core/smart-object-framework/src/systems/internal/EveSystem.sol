// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "../../codegen/world/IWorld.sol";
import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { ModuleTable } from "../../codegen/tables/ModuleTable.sol";
import { EntityMapTable } from "../../codegen/tables/EntityMapTable.sol";
import { EntityAssociationTable } from "../../codegen/tables/EntityAssociationTable.sol";
import { HookTargetBeforeTable } from "../../codegen/tables/HookTargetBeforeTable.sol";
import { HookTargetAfterTable } from "../../codegen/tables/HookTargetAfterTable.sol";
import { ModuleSystemLookupTable } from "../../codegen/tables/ModuleSystemLookupTable.sol";
import { HookTable } from "../../codegen/tables/HookTable.sol";
import { ICustomErrorSystem } from "../../codegen/world//ICustomErrorSystem.sol";
import { HookTableData } from "../../codegen/tables/HookTable.sol";

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
    ResourceId systemId,
    bytes memory hookArgs
  ) {
    bytes4 functionSelector = bytes4(msg.data[:4]);
    uint256[] memory hookIds = _getHookIds(entityId);
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

  function _requireModuleRegistered(uint256 moduleId) internal view {
    //check if the module is registered
    if (ModuleSystemLookupTable.getSystemIds(moduleId).length == 0)
      revert ICustomErrorSystem.ModuleNotRegistered(moduleId, "EveSystem: Module not registered");
  }

  function _requireSystemAssociatedWithModule(
    uint256 entityId,
    ResourceId systemId,
    bytes4 functionSelector
  ) internal view {
    //Get the moduleIds for the entity
    uint256[] memory moduleIds = _getModuleIds(entityId);

    //Check if the entity is tagged to a parentEntityType and get the moduleIds for the parentEntityType
    bool isEntityTagged = EntityMapTable.get(entityId).length > 0;
    if (isEntityTagged) {
      uint256[] memory parentEntityIds = EntityMapTable.get(entityId);
      for (uint256 i = 0; i < parentEntityIds.length; i++) {
        uint256[] memory parentModuleIds = _getModuleIds(parentEntityIds[i]);
        moduleIds = appendUint256Arrays(moduleIds, parentModuleIds);
      }
    }
    if (moduleIds.length == 0)
      revert ICustomErrorSystem.EntityNotAssociatedWithModule(
        entityId,
        "EveSystem: Entity is not associated with any module"
      );
    _validateModules(moduleIds, systemId, functionSelector);

    //TODO Add logic for more granularity by function selectors.
  }

  function _getModuleIds(uint256 entityId) internal view returns (uint256[] memory) {
    return EntityAssociationTable.getModuleIds(entityId);
  }

  function _validateModules(uint256[] memory moduleIds, ResourceId systemId, bytes4 functionSelector) internal view {
    bytes32 unwrappedSystemId = ResourceId.unwrap(systemId);
    bool isModuleFound = false;

    //TODO Below logic can be optimized by using supportsInterface as well
    for (uint256 i = 0; i < moduleIds.length; i++) {
      bool systemExists = ModuleTable.getDoesExists(moduleIds[i], systemId);
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

    if (!isModuleFound)
      revert ICustomErrorSystem.ModuleNotFound("EveSystem: Module associated with the system is not found");
  }

  function _getHookIds(uint256 entityId) internal view returns (uint256[] memory hookIds) {
    hookIds = EntityAssociationTable.getHookIds(entityId);

    //Check if the entity is tagged to a parentEntityType and get the moduleIds for the parentEntityType
    bool isEntityTagged = EntityMapTable.get(entityId).length > 0;
    if (isEntityTagged) {
      uint256[] memory parentEntityIds = EntityMapTable.get(entityId);
      for (uint256 i = 0; i < parentEntityIds.length; i++) {
        uint256[] memory parentHookIds = EntityAssociationTable.getHookIds(parentEntityIds[i]);
        hookIds = appendUint256Arrays(hookIds, parentHookIds);
      }
    }
  }

  function _executeBeforeHooks(
    uint256 hookId,
    ResourceId systemId,
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
    ResourceId systemId,
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
    ResourceId systemId = hookData.systemId;
    //TODO replace with callFrom ? and get the delegator address from the hookrgs ?
    world().call(systemId, funcSelectorAndArgs);
  }

  /**
   * @notice Returns the world address
   * @return worldAddress_ The world address
   */
  function world() internal view returns (IWorld) {
    return IWorld(_world());
  }

  //ARRAY UTILS

  /**
   * @notice A helper function to find the index of a value in an array
   */
  //TODO This function can be replaced by storing the index in a MUD table
  function findIndex(uint256[] memory array, uint256 value) internal pure returns (uint256, bool) {
    for (uint256 i = 0; i < array.length; i++) {
      if (array[i] == value) {
        return (i, true);
      }
    }
    return (0, false);
  }

  function findIndex(bytes32[] memory array, bytes32 value) internal pure returns (uint256, bool) {
    for (uint256 i = 0; i < array.length; i++) {
      if (array[i] == value) {
        return (i, true);
      }
    }
    return (0, false);
  }

  /**
   * @notice A helper function to append two uint256 arrays
   */
  function appendUint256Arrays(
    uint256[] memory array1,
    uint256[] memory array2
  ) internal pure returns (uint256[] memory) {
    uint256 totalLength = array1.length + array2.length;
    uint256[] memory newArray = new uint256[](totalLength);

    for (uint256 i = 0; i < array1.length; i++) {
      newArray[i] = array1[i];
    }

    for (uint256 i = 0; i < array2.length; i++) {
      newArray[array1.length + i] = array2[i];
    }

    return newArray;
  }
}
