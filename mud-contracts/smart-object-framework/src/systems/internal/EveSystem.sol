// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { IWorld } from "../../codegen/world/IWorld.sol";
import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { ModuleTable } from "../../codegen/tables/ModuleTable.sol";
import { EntityMap } from "../../codegen/tables/EntityMap.sol";
import { EntityAssociation } from "../../codegen/tables/EntityAssociation.sol";
import { HookTargetBefore } from "../../codegen/tables/HookTargetBefore.sol";
import { HookTargetAfter } from "../../codegen/tables/HookTargetAfter.sol";
import { ModuleSystemLookup } from "../../codegen/tables/ModuleSystemLookup.sol";
import { HookTable } from "../../codegen/tables/HookTable.sol";
import { ICustomErrorSystem } from "../../codegen/world//ICustomErrorSystem.sol";
import { HookTableData } from "../../codegen/tables/HookTable.sol";

import { Utils } from "../../utils.sol";
import { SMART_OBJECT_DEPLOYMENT_NAMESPACE as CORE_NAMESPACE } from "@eve/common-constants/src/constants.sol";

/**
 * @title EveSystem
 * @notice This is the base system which has all the helper functions for the other systems to inherit
 *
 * TODO: the references to `CORE_NAMESPACE` are kind of an anti-pattern because the whole point is to not rely on hard-coded values
 * Once that contract is inherited to non-core Systems, there's currently no satisfying way to dynamically retrieve that namespace
 * ideally, this would be some global constant set at Core Systems' deployment,
 * Or, contracts inheriting from EveSystem would need to explicitely target a deployed Core Systems' namespace
 */
contract EveSystem is System {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;

  /** TODO: Should we filter by allowed function selectors too ?
   * @notice Executes the function only if the entity is associated with the module
   * @dev Module association is defined by the systems registered in the ModuleTable
   * @param entityId is the id of an object or class
   * @param systemId is the systemId of the originating call
   */
  modifier onlyAssociatedModule(
    uint256 entityId,
    ResourceId systemId
  ) {
    _requireEntityRegistered(entityId);
    _requireSystemAssociatedWithModule(entityId, systemId);
    _;
  }

  /**
   * @notice Allows a function to be hooked before or after a function
   * @param entityId is the id of an object or class
   */
  modifier hookable(uint256 entityId, ResourceId systemId) {
    bytes4 functionSelector = bytes4(msg.data[:4]);
    uint256[] memory hookIds = _getHookIds(entityId);
    for (uint256 i = 0; i < hookIds.length; i++) {
      _executeBeforeHooks(hookIds[i], systemId, functionSelector, msg.data[4:]);
    }
    _;
    for (uint256 i = 0; i < hookIds.length; i++) {
      _executeAfterHooks(hookIds[i], systemId, functionSelector, msg.data[4:]);
    }
  }

  /**
   * @notice Reverts if the entity is not registered
   * @param entityId is the id of an object or class
   */
  function _requireEntityRegistered(uint256 entityId) internal view {
    if (!EntityTable.getDoesExists(_coreNamespace().entityTableTableId(), entityId))
      revert ICustomErrorSystem.EntityNotRegistered(entityId, "EveSystem: Entity is not registered");
  }

  function _requireModuleRegistered(uint256 moduleId) internal view {
    //check if the module is registered
    if (ModuleSystemLookup.getSystemIds(_coreNamespace().moduleSystemLookupTableId(), moduleId).length == 0)
      revert ICustomErrorSystem.ModuleNotRegistered(moduleId, "EveSystem: Module not registered");
  }

  //TODO optimize this function by removing array concatenation
  function _requireSystemAssociatedWithModule(
    uint256 entityId,
    ResourceId systemId
  ) internal view {
    //Get the moduleIds for the entity
    uint256[] memory moduleIds = _getModuleIds(entityId);

    //Check if the entity is tagged to a entityType and get the moduleIds for the entity
    bool isEntityTagged = EntityMap.get(_coreNamespace().entityMapTableId(), entityId).length > 0;
    if (isEntityTagged) {
      uint256[] memory taggedEntityIds = EntityMap.get(_coreNamespace().entityMapTableId(), entityId);
      for (uint256 i = 0; i < taggedEntityIds.length; i++) {
        uint256[] memory taggedModuleIds = _getModuleIds(taggedEntityIds[i]);
        moduleIds = appendUint256Arrays(moduleIds, taggedModuleIds);
      }
    }
    if (moduleIds.length == 0)
      revert ICustomErrorSystem.EntityNotAssociatedWithModule(
        entityId,
        "EveSystem: Entity is not associated with any module"
      );
    _validateModules(moduleIds, systemId);

    //TODO Add logic for more granularity by function selectors.
  }

  function _getModuleIds(uint256 entityId) internal view returns (uint256[] memory) {
    return EntityAssociation.getModuleIds(_coreNamespace().entityAssociationTableId(), entityId);
  }

  function _validateModules(uint256[] memory moduleIds, ResourceId systemId) internal view {
    bool isModuleFound = false;

    //TODO Below logic can be optimized by using supportsInterface as well
    for (uint256 i = 0; i < moduleIds.length; i++) {
      bool systemExists = ModuleTable.getDoesExists(_coreNamespace().moduleTableTableId(), moduleIds[i], systemId);
      if (systemExists) {
        isModuleFound = true;
        break;
      }
    }

    if (!isModuleFound)
      revert ICustomErrorSystem.ModuleNotFound("EveSystem: Module associated with the system is not found");
  }

  function _getHookIds(uint256 entityId) internal view returns (uint256[] memory hookIds) {
    hookIds = EntityAssociation.getHookIds(_coreNamespace().entityAssociationTableId(), entityId);

    //Check if the entity is tagged to a entity and get the moduleIds for the taggedEntity
    bool isEntityTagged = EntityMap.get(_coreNamespace().entityMapTableId(), entityId).length > 0;
    if (isEntityTagged) {
      uint256[] memory entityTagIds = EntityMap.get(_coreNamespace().entityMapTableId(), entityId);
      for (uint256 i = 0; i < entityTagIds.length; i++) {
        uint256[] memory taggedHookIds = EntityAssociation.getHookIds(
          _coreNamespace().entityAssociationTableId(),
          entityTagIds[i]
        );
        hookIds = appendUint256Arrays(hookIds, taggedHookIds);
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
    bool hasHook = HookTargetBefore.getHasHook(_coreNamespace().hookTargetBeforeTableId(), hookId, targetId);
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
    bool hasHook = HookTargetAfter.getHasHook(_coreNamespace().hookTargetAfterTableId(), hookId, targetId);
    if (hasHook) {
      _executeHook(hookId, hookArgs);
    }
  }

  function _executeHook(uint256 hookId, bytes memory hookArgs) internal {
    HookTableData memory hookData = HookTable.get(_coreNamespace().hookTableTableId(), hookId);
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

  // this is a bit messy... but in line with other Utils subroutines to ward off bad namespacing configs
  // TODO: refactor this
  function _coreNamespace() internal pure returns (bytes14) {
    return CORE_NAMESPACE;
  }

  function _namespace() internal view returns (bytes14 namespace) {
    ResourceId systemId = SystemRegistry.get(address(this));
    return systemId.getNamespace();
  }
}
