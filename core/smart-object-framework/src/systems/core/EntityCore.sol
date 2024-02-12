// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { ObjectClassMap } from "../../codegen/tables/ObjectClassMap.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { EntityType } from "../../types.sol";
import { DEFAULT_CLASS_TAG } from "../../constants.sol";

/**
 * @title EntityCore
 * @dev EntityCore is a system that manages entities such as Classes and objects.
 *
 */
contract EntityCore is EveSystem {
  /**
   * @notice Registers an entity as a class and object
   * @param _entityId is the id of the entity
   * @param _entityType is the type of the entity
   */
  function registerEntity(uint256 _entityId, EntityType _entityType) public {
    _registerEntity(_entityId, _entityType);
  }

  /**
   * @notice Tags an object to a class
   * @param _entityId is the id of the object
   * @param _classId is the id of the class
   */
  function tagEntity(uint256 _entityId, uint256 _classId) public {
    _tagEntity(_entityId, _classId);
  }

  /**
   * @notice Removes an entity
   * @param _entityId is the id of the entity
   */
  function removeEntity(uint256 _entityId) public {
    _removeEntity(_entityId);
  }

  /**
   * @notice Removes the class tag from an object
   * @param _entityId is the id of the object
   */
  function removeClassTag(uint256 _entityId) public {
    _removeClassTag(_entityId);
  }

  function _registerEntity(uint256 _entityId, EntityType _entityType) internal {
    if (_entityId == 0) revert ICustomErrorSystem.InvalidEntityId();
    if (EntityTable.getEntityType(_entityId) != uint256(EntityType.Unknown))
      revert ICustomErrorSystem.EntityAlreadyRegistered(_entityId, "EntityCore: Entity already registered");

    EntityTable.set(_entityId, true, uint8(_entityType));
  }

  function _tagEntity(uint256 _entityId, uint256 _classId) internal {
    uint256 entityType = EntityTable.getEntityType(_entityId);
    if (entityType != uint256(EntityType.Object))
      revert ICustomErrorSystem.EntityTypeMismatch(_entityId, uint256(EntityType.Object), entityType);

    ObjectClassMap.setClassId(_entityId, _classId);
  }

  //TODO make sure there is no data dependency
  function _removeEntity(uint256 _entityId) internal {
    uint256 entityType = EntityTable.getEntityType(_entityId);
    if (EntityTable.getEntityType(_entityId) == uint256(EntityType.Unknown))
      revert ICustomErrorSystem.EntityNotRegistered(_entityId, "EntityCore: Entity not registered");

    EntityTable.set(_entityId, false, uint8(EntityType.Unknown));
  }

  function _removeClassTag(uint256 _entityId) internal {
    uint256 classId = ObjectClassMap.get(_entityId);
    if (ObjectClassMap.get(_entityId) == DEFAULT_CLASS_TAG) revert ICustomErrorSystem.NoClassTag(_entityId);
    ObjectClassMap.setClassId(_entityId, DEFAULT_CLASS_TAG);
  }
}
