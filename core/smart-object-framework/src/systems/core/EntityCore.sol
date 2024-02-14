// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { EntityTable } from "../../codegen/tables/EntityTable.sol";
import { EntityType } from "../../codegen/tables/EntityType.sol";
import { EntityTypeAssociation } from "../../codegen/tables/EntityTypeAssociation.sol";
import { EntityMapTable } from "../../codegen/tables/EntityMapTable.sol";
import { ICustomErrorSystem } from "../../codegen/world/ICustomErrorSystem.sol";
import { EveSystem } from "../internal/EveSystem.sol";
import { INVALID_ID } from "../../constants.sol";

/**
 * @title EntityCore
 * @dev EntityCore is a system that manages entities such as Classes and objects.
 *
 */
contract EntityCore is EveSystem {
  // Modifiers
  modifier validEntityId(uint256 entityId) {
    if (entityId == INVALID_ID) revert ICustomErrorSystem.InvalidEntityId();
    _;
  }

  modifier entityTypeExists(uint8 entityType) {
    if (EntityType.getDoesExists(entityType) == false)
      revert ICustomErrorSystem.EntityTypeNotRegistered(entityType, "EntityCore: EntityType not registered");
    _;
  }

  /**
   * @notice Registers an entity type
   * @param entityTypeId is the id of a entityType
   * @param entityType is the name of the entityType
   */
  function registerEntityType(uint8 entityTypeId, bytes32 entityType) external validEntityId(entityTypeId) {
    _registerEntityType(entityTypeId, entityType);
  }

  /**
   * @notice Registers an entity by its type
   * @param entityId is the id of the entity
   * @param entityType is the type of the entity
   */
  function registerEntity(uint256 entityId, uint8 entityType) external {
    _registerEntity(entityId, entityType);
  }

  function registerEntity(uint256[] memory entityId, uint8[] memory entityType) external {
    if (entityId.length != entityType.length)
      revert ICustomErrorSystem.InvalidArrayLength(
        entityId.length,
        entityType.length,
        "EntityCore: Array length mismatch"
      );
    for (uint256 i = 0; i < entityId.length; i++) {
      _registerEntity(entityId[i], entityType[i]);
    }
  }

  /**
   * @notice Defines a parent-child association enforcement between two entity types
   * @param childEntityType is the id of the child entity type
   * @param parentEntityType is the id of the parent entity type
   */
  function registerEntityTypeAssociation(
    uint8 childEntityType,
    uint8 parentEntityType
  ) external entityTypeExists(childEntityType) entityTypeExists(parentEntityType) {
    _registerEntityTypeAssociation(childEntityType, parentEntityType);
  }

  /**
   * @notice Tags/Groups a child entities to a parent entity
   * @dev Similar Objects can be tagged under a Class and associate modules to the class, so that all the objects under the class can inherit the modules.
   * @param entityId is the id of the child entity
   * @param parentEntityId is the id of the parent entity which the child belongs to
   */
  function tagEntity(uint256 entityId, uint256 parentEntityId) external {
    _tagEntity(entityId, parentEntityId);
  }

  /**
   * @notice Overloaded function to tagEntity under multiple parent entities
   */
  function tagEntity(uint256 entityId, uint256[] memory _parentEntityIds) external {
    for (uint256 i = 0; i < _parentEntityIds.length; i++) {
      _tagEntity(entityId, _parentEntityIds[i]);
    }
  }

  /**
   * @notice Removes the parent entity tag from a child entity
   * @param entityId is the id of the child entity
   * @param parentEntityId is the id of the parent entity
   */
  function removeEntityTag(uint256 entityId, uint256 parentEntityId) external {
    _removeEntityTag(entityId, parentEntityId);
  }

  function _registerEntityType(uint8 entityTypeId, bytes32 entityType) internal {
    if (EntityType.getDoesExists(entityTypeId) == true)
      revert ICustomErrorSystem.EntityTypeAlreadyRegistered(entityTypeId, "EntityCore: EntityType already registered");

    EntityType.set(entityTypeId, true, entityType);
  }

  function _registerEntity(
    uint256 entityId,
    uint8 entityType
  ) internal validEntityId(entityId) entityTypeExists(entityType) {
    if (EntityTable.getDoesExists(entityId) == true)
      revert ICustomErrorSystem.EntityAlreadyRegistered(entityId, "EntityCore: Entity already registered");

    EntityTable.set(entityId, true, entityType);
  }

  function _registerEntityTypeAssociation(uint8 childEntityType, uint8 parentEntityType) internal {
    EntityTypeAssociation.set(childEntityType, parentEntityType, true);
  }

  function _tagEntity(uint256 entityId, uint256 parentEntityId) internal {
    _requireEntityRegistered(entityId);
    _requireEntityRegistered(parentEntityId);
    _requireAssociationAllowed(entityId, parentEntityId);

    uint256[] memory parentEntityIds = EntityMapTable.get(entityId);
    (, bool exists) = findIndex(parentEntityIds, parentEntityId);
    if (exists)
      revert ICustomErrorSystem.EntityAlreadyTagged(entityId, parentEntityId, "EntityCore: Entity already tagged");

    EntityMapTable.pushTaggedParentEntityIds(entityId, parentEntityId);
  }

  function _removeEntityTag(uint256 entityId, uint256 parentEntityId) internal {
    //TODO Have to figure out a clean way to remove an element from an array
    uint256[] memory taggedParentEntities = EntityMapTable.get(entityId);
    (uint256 index, bool exists) = findIndex(taggedParentEntities, parentEntityId);
    if (exists) {
      // Swap the element with the last one and pop the last element
      uint256 lastIndex = taggedParentEntities.length - 1;
      if (index != lastIndex) {
        EntityMapTable.update(entityId, index, taggedParentEntities[lastIndex]);
      }
      EntityMapTable.pop(entityId);
    }
  }

  function _requireAssociationAllowed(uint256 childEntityId, uint256 parentEntityId) internal view {
    uint8 childEntityType = EntityTable.getEntityType(childEntityId);
    uint8 parentEntityType = EntityTable.getEntityType(parentEntityId);

    if (EntityTypeAssociation.get(childEntityType, parentEntityType) == false)
      revert ICustomErrorSystem.EntityTypeAssociationNotAllowed(
        childEntityType,
        parentEntityType,
        "EntityCore: EntityType association not allowed"
      );
  }
}
