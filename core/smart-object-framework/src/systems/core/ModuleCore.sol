// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { EntityAssociationTable } from "../../codegen/tables/EntityAssociationTable.sol";
import { EntityMapTable } from "../../codegen/tables/EntityMapTable.sol";
import { ModuleTable } from "../../codegen/tables/ModuleTable.sol";
import { ModuleSystemLookupTable } from "../../codegen/tables/ModuleSystemLookupTable.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { INVALID_ID } from "../../constants.sol";

contract ModuleCore is EveSystem {
  /**
   * @notice Registers a system
   * @param moduleId The identifier for the module
   * @param moduleName The name of the module
   * @param systemId The identifier for the system being called
   */
  function registerModule(uint256 moduleId, bytes16 moduleName, ResourceId systemId) external {
    _requireResourceRegistered(moduleId, systemId);
    _registerModule(moduleId, systemId, moduleName);
  }

  /**
   * @notice Overloaded funciton for registerModule
   */
  function registerModule(uint256 moduleId, bytes16 moduleName, ResourceId[] memory systemIds) external {
    for (uint256 i = 0; i < systemIds.length; i++) {
      _requireResourceRegistered(moduleId, systemIds[i]);
      _registerModule(moduleId, systemIds[i], moduleName);
    }
  }

  /**
   * @notice Associates a module with an entity
   * @param entityId id of the class or object
   * @param moduleId The identifier for the module
   */
  function associateModule(uint256 entityId, uint256 moduleId) external {
    _associateModule(entityId, moduleId);
  }

  /**
   * @notice Overloaded function for associateModule
   */
  function associateModules(uint256 entityId, uint256[] memory moduleIds) external {
    for (uint256 i = 0; i < moduleIds.length; i++) {
      _associateModule(entityId, moduleIds[i]);
    }
  }

  /**
   * @notice Removes the association of a module with an entity
   * @param entityId id of the class or object
   * @param moduleId The identifier for the module
   */
  function removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) external {
    _removeEntityModuleAssociation(entityId, moduleId);
  }

  // TODO Figure our data dependency and data corruption problems
  /**
   * @notice Removes the association of a system with a module
   * @param systemId The identifier of the system
   * @param moduleId The identifier for the module
   */
  function removeSystemModuleAssociation(ResourceId systemId, uint256 moduleId) external {
    _removeSystemModuleAssociation(systemId, moduleId);
  }

  function _requireResourceRegistered(uint256 moduleId, ResourceId systemId) internal view {
    if (ResourceIds.getExists(systemId) == false)
      revert ICustomErrorSystem.ResourceNotRegistered(systemId, "ModuleCore: System is not registered");
  }

  function _registerModule(uint256 moduleId, ResourceId systemId, bytes16 moduleName) internal {
    if (ModuleTable.getDoesExists(moduleId, systemId))
      revert ICustomErrorSystem.SystemAlreadyAssociatedWithModule(
        moduleId,
        systemId,
        "ModuleCore: System already associated with the module"
      );

    ModuleTable.set(moduleId, systemId, moduleName, true);
    ModuleSystemLookupTable.pushSystemIds(moduleId, ResourceId.unwrap(systemId));
  }

  function _associateModule(uint256 entityId, uint256 moduleId) internal {
    _requireEntityRegistered(entityId);
    _requireModuleRegistered(moduleId);

    //Check if the entity is tagged to a parentEntityType,
    //if yes then the check module is already part of the parentEntityType to ensure unique moduleId association
    //If no then associate the entity with the module
    if (EntityMapTable.get(entityId).length > 0) {
      uint256[] memory parentEntityIds = EntityMapTable.get(entityId);
      for (uint256 i = 0; i < parentEntityIds.length; i++) {
        _requireModuleNotAssociated(parentEntityIds[i], moduleId);
      }
    } else {
      _requireModuleNotAssociated(entityId, moduleId);
    }

    EntityAssociationTable.pushModuleIds(entityId, moduleId);
  }

  function _requireModuleNotAssociated(uint256 entityId, uint256 moduleId) internal view {
    uint256[] memory moduleIds = EntityAssociationTable.getModuleIds(entityId);
    (, bool exists) = findIndex(moduleIds, moduleId);
    if (exists)
      revert ICustomErrorSystem.EntityAlreadyAssociated(
        entityId,
        moduleId,
        "ModuleCore: Module already associated with the entity"
      );
  }

  function _removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) internal {
    uint256[] memory moduleIds = EntityAssociationTable.getModuleIds(entityId);
    (uint256 index, bool exists) = findIndex(moduleIds, moduleId);

    if (exists) {
      //Swap the last element to the index and pop the last element
      uint256 lastIndex = moduleIds.length - 1;
      if (index != lastIndex) {
        EntityAssociationTable.updateModuleIds(entityId, index, moduleIds[lastIndex]);
      }
      EntityAssociationTable.popModuleIds(entityId);
    }
  }

  function _removeSystemModuleAssociation(ResourceId systemId, uint256 moduleId) internal {
    bytes32 unwrappedSystemId = ResourceId.unwrap(systemId);
    require(ModuleTable.getDoesExists(moduleId, systemId), "ModuleCore: Module not registered");
    ModuleTable.deleteRecord(moduleId, systemId);

    //update lookup table
    //TODO remove this after discussion
    bytes32[] memory systemIds = ModuleSystemLookupTable.getSystemIds(moduleId);
    (uint256 index, bool exists) = findIndex(systemIds, unwrappedSystemId);
    if (exists) {
      //Swap the last element to the index and pop the last element
      uint256 lastIndex = systemIds.length - 1;
      if (index != lastIndex) {
        ModuleSystemLookupTable.updateSystemIds(moduleId, index, unwrappedSystemId);
      }
      ModuleSystemLookupTable.popSystemIds(moduleId);
    }
  }
}
