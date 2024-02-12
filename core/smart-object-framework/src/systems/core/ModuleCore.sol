// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { ClassAssociationTable } from "../../codegen/tables/ClassAssociationTable.sol";
import { ObjectAssociationTable } from "../../codegen/tables/ObjectAssociationTable.sol";
import { ObjectClassMap } from "../../codegen/tables/ObjectClassMap.sol";
import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { ModuleTable } from "../../codegen/tables/ModuleTable.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { EntityType } from "../../types.sol";
import { EMPTY_MODULE_ID } from "../../constants.sol";

contract ModuleCore is EveSystem {
  /**
   * @notice Registers a system
   * @param systemId The identifier for the system being called
   * @param moduleId The identifier for the module
   * @param moduleName The name of the module
   */
  //TODO refactor required
  function registerModule(ResourceId systemId, uint256 moduleId, bytes16 moduleName) external {
    _requireResourceRegistered(moduleName, systemId);
    _registerModule(moduleId, systemId, moduleName);
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
   * @notice Removes the association of a module with an entity
   * @param entityId id of the class or object
   * @param moduleId The identifier for the module
   */
  function removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) external {
    _removeEntityModuleAssociation(entityId, moduleId);
  }

  /**
   * @notice Removes the association of a module with an entity
   * @param entityId id of the class or object
   * @param moduleId The identifier for the module to remove from the array
   */
  function removeModule(uint256 entityId, uint256 moduleId) external {
    _removeModule(entityId, moduleId);
  }

  /**
   * @notice Removes the association of a system with a module
   * @param systemId The identifier of the system
   * @param moduleId The identifier for the module
   */
  function removeSystemModuleAssociation(ResourceId systemId, uint256 moduleId) external {
    _removeSystemModuleAssociation(systemId, moduleId);
  }

  function _requireResourceRegistered(bytes16 moduleName, ResourceId systemId) internal view {
    require(ResourceIds.getExists(systemId), "ModuleCore: System is not registered");
    //check weather the moduleName is registered
  }

  function _registerModule(uint256 moduleId, ResourceId systemId, bytes16 moduleName) internal {
    bytes32 unwrappedSystemId = ResourceId.unwrap(systemId);
    require(moduleId != 0, "ModuleCore: Invalid moduleId");
    require(!ModuleTable.getDoesExists(moduleId, unwrappedSystemId), "ModuleCore: Module already registered");
    ModuleTable.set(moduleId, unwrappedSystemId, moduleName, true);
  }

  // TODO - reverse lookups
  function _associateModule(uint256 entityId, uint256 moduleId) internal {
    require(moduleId != 0, "ModuleCore: Invalid moduleId");
    require(entityId != 0, "ModuleCore: Invalid entityId");
    require(EntityTable.getEntityType(entityId) != uint256(EntityType.Unknown), "ModuleCore: Unknown entity type");

    uint256 entityType = EntityTable.getEntityType(entityId);

    if (
      entityType == uint256(EntityType.Class) ||
      (entityType == uint256(EntityType.Object) && ObjectClassMap.get(entityId) != 0) // TODO Wrong logic : Check is this object associated with the class which inherits the same module
    ) {
      (uint256 index, bool exists) = findIndex(ClassAssociationTable.getModuleIds(entityId), moduleId);
      if (!exists) {
        ClassAssociationTable.setIsAssociated(entityId, true);
        ClassAssociationTable.pushModuleIds(entityId, moduleId);
      }
    } else if (entityType == uint256(EntityType.Object)) {
      (uint256 index, bool exists) = findIndex(ObjectAssociationTable.getModuleIds(entityId), moduleId);
      if (!exists) {
        ObjectAssociationTable.setIsAssociated(entityId, true);
        ObjectAssociationTable.pushModuleIds(entityId, moduleId);
      }
    }
  }

  function _removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) internal {
    require(
      ClassAssociationTable.getIsAssociated(entityId) || ObjectAssociationTable.getIsAssociated(entityId),
      "ModuleCore: Entity not associated"
    );

    uint256 entityType = EntityTable.getEntityType(entityId);
    if (
      entityType == uint256(EntityType.Class) ||
      (entityType == uint256(EntityType.Object) && ObjectClassMap.get(entityId) != 0)
    ) {
      ClassAssociationTable.setIsAssociated(entityId, false);
    } else if (entityType == uint256(EntityType.Object)) {
      ObjectAssociationTable.setIsAssociated(entityId, false);
    }
  }

  function _removeModule(uint256 entityId, uint256 moduleId) internal {
    uint256[] memory moduleIds;
    uint256 entityType = EntityTable.getEntityType(entityId);

    uint256 index;
    bool exists;
    if (entityType == uint256(EntityType.Class)) {
      moduleIds = ClassAssociationTable.getModuleIds(entityId);
      (index, exists) = findIndex(moduleIds, moduleId);
      //TODO Not sure whats the best way to remove, this is a temporary solution
      if (exists) {
        ClassAssociationTable.updateModuleIds(entityId, index, EMPTY_MODULE_ID);
      }
    } else if (entityType == uint256(EntityType.Object)) {
      moduleIds = ObjectAssociationTable.getModuleIds(entityId);
      (index, exists) = findIndex(moduleIds, moduleId);
      if (exists) {
        ObjectAssociationTable.updateModuleIds(entityId, index, EMPTY_MODULE_ID);
      }
    }
  }

  function _removeSystemModuleAssociation(ResourceId systemId, uint256 moduleId) internal {
    bytes32 unwrappedSystemId = ResourceId.unwrap(systemId);
    require(ModuleTable.getDoesExists(moduleId, unwrappedSystemId), "ModuleCore: Module not registered");
    ModuleTable.deleteRecord(moduleId, unwrappedSystemId);
  }
}
