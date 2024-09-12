// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { EntityAssociation } from "../../codegen/tables/EntityAssociation.sol";
import { EntityMap } from "../../codegen/tables/EntityMap.sol";
import { ModuleTable } from "../../codegen/tables/ModuleTable.sol";
import { ModuleSystemLookup } from "../../codegen/tables/ModuleSystemLookup.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { EveSystem } from "../internal/EveSystem.sol";

import { Utils } from "../../utils.sol";

contract ModuleSystem is EveSystem {
  using Utils for bytes14;

  /**
   * @notice Registers a system
   * @param moduleId The identifier for the module
   * @param moduleName The name of the module
   * @param systemId The identifier for the system being called
   */
  function registerEVEModule(
    uint256 moduleId,
    bytes16 moduleName,
    ResourceId systemId
  ) external hookable(moduleId, _systemId()) {
    _requireResourceRegistered(moduleId, systemId);
    _registerEVEModule(moduleId, systemId, moduleName);
  }

  /**
   * @notice Overloaded funciton for registerEVEModule
   */
  function registerEVEModules(
    uint256 moduleId,
    bytes16 moduleName,
    ResourceId[] memory systemIds
  ) external hookable(moduleId, _systemId()) {
    for (uint256 i = 0; i < systemIds.length; i++) {
      _requireResourceRegistered(moduleId, systemIds[i]);
      _registerEVEModule(moduleId, systemIds[i], moduleName);
    }
  }

  /**
   * @notice Associates a module with an entity
   * @param entityId id of the class or object
   * @param moduleId The identifier for the module
   */
  function associateModule(uint256 entityId, uint256 moduleId) external hookable(entityId, _systemId()) {
    _associateModule(entityId, moduleId);
  }

  /**
   * @notice Overloaded function for associateModule
   */
  function associateModules(uint256 entityId, uint256[] memory moduleIds) external hookable(entityId, _systemId()) {
    for (uint256 i = 0; i < moduleIds.length; i++) {
      _associateModule(entityId, moduleIds[i]);
    }
  }

  /**
   * @notice Removes the association of a module with an entity
   * @param entityId id of the class or object
   * @param moduleId The identifier for the module
   */
  function removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) external hookable(entityId, _systemId()) {
    _removeEntityModuleAssociation(entityId, moduleId);
  }

  // TODO Figure our data dependency and data corruption problems
  /**
   * @notice Removes the association of a system with a module
   * @param systemId The identifier of the system
   * @param moduleId The identifier for the module
   */
  function removeSystemModuleAssociation(
    ResourceId systemId,
    uint256 moduleId
  ) external hookable(moduleId, _systemId()) {
    _removeSystemModuleAssociation(systemId, moduleId);
  }

  function _requireResourceRegistered(uint256 moduleId, ResourceId systemId) internal view {
    if (ResourceIds.getExists(systemId) == false)
      revert ICustomErrorSystem.ResourceNotRegistered(systemId, "ModuleSystem: System is not registered");

    //TODO - check if the moduleId is registered
  }

  function _registerEVEModule(uint256 moduleId, ResourceId systemId, bytes16 moduleName) internal {
    if (ModuleTable.getDoesExists(moduleId, systemId))
      revert ICustomErrorSystem.SystemAlreadyAssociatedWithModule(
        moduleId,
        systemId,
        "ModuleSystem: System already associated with the module"
      );

    ModuleTable.set(moduleId, systemId, moduleName, true);
    ModuleSystemLookup.pushSystemIds(moduleId, ResourceId.unwrap(systemId));
  }

  function _associateModule(uint256 entityId, uint256 moduleId) internal {
    _requireEntityRegistered(entityId);
    _requireModuleRegistered(moduleId);

    //Check if the entity is tagged to a taggedEntityType,
    //if yes then the check module is already part of the taggedEntityType to ensure unique moduleId association
    //If no then associate the entity with the module
    if (EntityMap.get(entityId).length > 0) {
      uint256[] memory taggedEntityIds = EntityMap.get(entityId);
      for (uint256 i = 0; i < taggedEntityIds.length; i++) {
        _requireModuleNotAssociated(taggedEntityIds[i], moduleId);
      }
    } else {
      _requireModuleNotAssociated(entityId, moduleId);
    }

    EntityAssociation.pushModuleIds(entityId, moduleId);
  }

  function _requireModuleNotAssociated(uint256 entityId, uint256 moduleId) internal view {
    uint256[] memory moduleIds = EntityAssociation.getModuleIds(entityId);
    (, bool exists) = findIndex(moduleIds, moduleId);
    if (exists)
      revert ICustomErrorSystem.EntityAlreadyAssociated(
        entityId,
        moduleId,
        "ModuleSystem: Module already associated with the entity"
      );
  }

  function _removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) internal {
    uint256[] memory moduleIds = EntityAssociation.getModuleIds(entityId);
    (uint256 index, bool exists) = findIndex(moduleIds, moduleId);

    if (exists) {
      //Swap the last element to the index and pop the last element
      uint256 lastIndex = moduleIds.length - 1;
      if (index != lastIndex) {
        EntityAssociation.updateModuleIds(
          entityId,
          index,
          moduleIds[lastIndex]
        );
      }
      EntityAssociation.popModuleIds(entityId);
    }
  }

  function _removeSystemModuleAssociation(ResourceId systemId, uint256 moduleId) internal {
    bytes32 unwrappedSystemId = ResourceId.unwrap(systemId);
    require(
      ModuleTable.getDoesExists(moduleId, systemId),
      "ModuleSystem: Module not registered"
    );
    ModuleTable.deleteRecord(moduleId, systemId);

    //update lookup table
    //TODO remove this after discussion
    bytes32[] memory systemIds = ModuleSystemLookup.getSystemIds(moduleId);
    (uint256 index, bool exists) = findIndex(systemIds, unwrappedSystemId);
    if (exists) {
      //Swap the last element to the index and pop the last element
      uint256 lastIndex = systemIds.length - 1;
      if (index != lastIndex) {
        ModuleSystemLookup.updateSystemIds(
          moduleId,
          index,
          unwrappedSystemId
        );
      }
      ModuleSystemLookup.popSystemIds(moduleId);
    }
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().moduleSystemId();
  }
}
