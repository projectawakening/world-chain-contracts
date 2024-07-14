// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Id, IdLib } from "../../libs/Id.sol";
import { TAG_SYSTEM } from "../../types/tagTypes.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../../types/entityTypes.sol";
import { Objects } from "../../codegen/tables/Objects.sol";
import { ClassSystemTagMap } from "../../codegen/tables/ClassSystemTagMap.sol";

import { IErrors } from "../../interfaces/IErrors.sol";

/**
 * @title SmartObjectSystem
 * @author CCP Games
 * @dev Extends the standard MUD System.sol with Smart Object Framework functionality
 */
contract SmartObjectSystem is System {

/**
 * @dev A modifier to enforce Entity based System accessibility scope
 * @param entityId The Object (or Class) Entity to enforce System accessibility for
 * Expected behaviour:
 * if `entityId` is passed as a zero value - system scope enforcement is ignored
 * if `entityId` is passed as an ENTITY_CLASS type ID - system scope enforcement for that Class is applied
 * if `entityId` is passed as an ENTITY_OBJECT type ID - system scope enforcement for the Object's inherited Class is applied
 * if `entityId` is passed as some other (non-Entity) type of ID - revert with an InvalidEntityType error
 */
  modifier scope(Id entityId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    _scope(entityId, systemId);
    _;
  }

  function _scope(Id entityId, ResourceId systemId) private view {
    if (Id.unwrap(entityId) != bytes32(0)) {
      bool classHasTag;
      if(entityId.getType() == ENTITY_CLASS) {
        classHasTag = ClassSystemTagMap.getHasTag(entityId, Id.wrap(ResourceId.unwrap(systemId)));
        if(!classHasTag) {
          revert IErrors.InvalidSystemCall(entityId, systemId);
        }
      } else if (entityId.getType() == ENTITY_OBJECT) {
        Id classId = Objects.getClass(entityId);
        classHasTag = ClassSystemTagMap.getHasTag(classId, Id.wrap(ResourceId.unwrap(systemId)));
        if(!(classHasTag)) {
          revert IErrors.InvalidSystemCall(entityId, systemId);
        }
      } else {
        revert IErrors.InvalidEntityType(entityId.getType());
      }
    }
  }
}
