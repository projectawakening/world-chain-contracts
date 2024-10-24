// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";

import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";

import { IWorldWithContext } from "../IWorldWithContext.sol";
import { Id, IdLib } from "../libs/Id.sol";
import { Bytes } from "../libs/Bytes.sol";
import { TAG_SYSTEM } from "../types/tagTypes.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../types/entityTypes.sol";
import { Objects } from "../namespaces/evefrontier/codegen/tables/Objects.sol";
import { ClassSystemTagMap } from "../namespaces/evefrontier/codegen/tables/ClassSystemTagMap.sol";

import { IEntitySystem } from "../namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { ITagSystem } from "../namespaces/evefrontier/interfaces/ITagSystem.sol";

/**
 * @title SmartObjectFramework
 * @author CCP Games
 * @dev Extends the standard MUD System.sol with Smart Object Framework functionality
 */
contract SmartObjectFramework is System {
  error SOF_InvalidCall();
  error SOF_UnscopedSystemCall(Id entityId, ResourceId systemId);

  uint256 constant MUD_CONTEXT_BYTES = 20 + 32;

  /**
   * @dev A modifier to capture (and enforce) Execution Context for Smart Object Framework integrated Systems
   */
  modifier context() {
    ResourceId systemId = _contextGuard();
    _;
  }

  function _contextGuard() internal view returns (ResourceId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    (ResourceId trackedSystemId, bytes4 trackedFunctionSelector, , ) = IWorldWithContext(_world()).getWorldCallContext(
      IWorldWithContext(_world()).getWorldCallCount()
    );
    if (
      ResourceId.unwrap(systemId) != ResourceId.unwrap(trackedSystemId) || bytes4(msg.data) != trackedFunctionSelector
    ) {
      revert SOF_InvalidCall();
    }
    return systemId;
  }

  function _callMsgSender() internal view returns (address) {
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(
      IWorldWithContext(_world()).getWorldCallCount()
    );
    return msgSender;
  }

  function _callMsgSender(uint256 callCount) internal view returns (address) {
    (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    return msgSender;
  }

  function _callMsgValue() internal view returns (uint256) {
    (, , , uint256 msgValue) = IWorldWithContext(_world()).getWorldCallContext(
      IWorldWithContext(_world()).getWorldCallCount()
    );
    return msgValue;
  }

  function _callMsgValue(uint256 callCount) internal view returns (uint256) {
    (, , , uint256 msgValue) = IWorldWithContext(_world()).getWorldCallContext(callCount);
    return msgValue;
  }

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
      if (entityId.getType() == ENTITY_CLASS) {
        classHasTag = ClassSystemTagMap.getHasTag(entityId, Id.wrap(ResourceId.unwrap(systemId)));
        if (!classHasTag) {
          revert SOF_UnscopedSystemCall(entityId, systemId);
        }
      } else if (entityId.getType() == ENTITY_OBJECT) {
        Id classId = Objects.getClass(entityId);
        classHasTag = ClassSystemTagMap.getHasTag(classId, Id.wrap(ResourceId.unwrap(systemId)));
        if (!(classHasTag)) {
          revert SOF_UnscopedSystemCall(entityId, systemId);
        }
      } else {
        revert IEntitySystem.InvalidEntityType(entityId.getType());
      }
    }
  }

  function _callDataWithoutContext(bytes memory callDataWithContext) internal pure returns (bytes memory) {
    return Bytes.slice(callDataWithContext, 0, callDataWithContext.length - MUD_CONTEXT_BYTES);
  }
}
