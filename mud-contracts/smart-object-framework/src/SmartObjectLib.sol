// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./utils.sol";
import { HookType } from "./types.sol";

import { IEntitySystem } from "./interfaces/IEntitySystem.sol";
import { IHookSystem } from "./interfaces/IHookSystem.sol";
import { IModuleSystem } from "./interfaces/IModuleSystem.sol";

/**
 * @title Smart Object Framework Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 *
 * TODO: the way we generate the interfaces used below is brittle; it's a semi-manual process
 * (generate with `worldgen` while setting `namespace` in `mud.config.ts` to "")
 * changes to any Core contract won't reflect in either the library, or the interfaces it imports
 */
library SmartObjectLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  // EntitySystem methods
  function registerEntityType(World memory world, uint8 entityTypeId, bytes32 entityType) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.registerEntityType, (entityTypeId, entityType))
    );
  }

  function registerEntity(World memory world, uint256 entityId, uint8 entityType) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.registerEntity, (entityId, entityType))
    );
  }

  function registerEntities(World memory world, uint256[] memory entityId, uint8[] memory entityType) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.registerEntities, (entityId, entityType))
    );
  }

  function registerEntityTypeAssociation(World memory world, uint8 entityType, uint8 tagEntityType) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.registerEntityTypeAssociation, (entityType, tagEntityType))
    );
  }

  function tagEntity(World memory world, uint256 entityId, uint256 entityTagId) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.tagEntity, (entityId, entityTagId))
    );
  }

  function tagEntities(World memory world, uint256 entityId, uint256[] memory entityTagIds) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.tagEntities, (entityId, entityTagIds))
    );
  }

  function removeEntityTag(World memory world, uint256 entityId, uint256 entityTagId) internal {
    world.iface.call(
      world.namespace.entitySystemId(),
      abi.encodeCall(IEntitySystem.removeEntityTag, (entityId, entityTagId))
    );
  }

  // HookSystem methods
  function registerHook(World memory world, ResourceId systemId, bytes4 functionId) internal {
    world.iface.call(
      world.namespace.hookSystemId(),
      abi.encodeCall(IHookSystem.registerHook, (systemId, functionId))
    );
  }

  function addHook(
    World memory world,
    uint256 hookId,
    HookType hookType,
    ResourceId systemId,
    bytes4 functionSelector
  ) internal {
    world.iface.call(
      world.namespace.hookSystemId(),
      abi.encodeCall(IHookSystem.addHook, (hookId, hookType, systemId, functionSelector))
    );
  }

  function removeHook(
    World memory world,
    uint256 hookId,
    HookType hookType,
    ResourceId systemId,
    bytes4 functionSelector
  ) internal {
    world.iface.call(
      world.namespace.hookSystemId(),
      abi.encodeCall(IHookSystem.removeHook, (hookId, hookType, systemId, functionSelector))
    );
  }

  function associateHook(World memory world, uint256 entityId, uint256 hookId) internal {
    world.iface.call(world.namespace.hookSystemId(), abi.encodeCall(IHookSystem.associateHook, (entityId, hookId)));
  }

  function associateHooks(World memory world, uint256 entityId, uint256[] memory hookIds) internal {
    world.iface.call(world.namespace.hookSystemId(), abi.encodeCall(IHookSystem.associateHooks, (entityId, hookIds)));
  }

  function removeEntityHookAssociation(World memory world, uint256 entityId, uint256 hookId) internal {
    world.iface.call(
      world.namespace.hookSystemId(),
      abi.encodeCall(IHookSystem.removeEntityHookAssociation, (entityId, hookId))
    );
  }

  // ModuleSystem methods
  function registerEVEModule(World memory world, uint256 moduleId, bytes16 moduleName, ResourceId systemId) internal {
    world.iface.call(
      world.namespace.moduleSystemId(),
      abi.encodeCall(IModuleSystem.registerEVEModule, (moduleId, moduleName, systemId))
    );
  }

  function registerEVEModules(
    World memory world,
    uint256 moduleId,
    bytes16 moduleName,
    ResourceId[] memory systemIds
  ) internal {
    world.iface.call(
      world.namespace.moduleSystemId(),
      abi.encodeCall(IModuleSystem.registerEVEModules, (moduleId, moduleName, systemIds))
    );
  }

  function associateModule(World memory world, uint256 entityId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleSystemId(),
      abi.encodeCall(IModuleSystem.associateModule, (entityId, moduleId))
    );
  }

  function associateModules(World memory world, uint256 entityId, uint256[] memory moduleIds) internal {
    world.iface.call(
      world.namespace.moduleSystemId(),
      abi.encodeCall(IModuleSystem.associateModules, (entityId, moduleIds))
    );
  }

  function removeEntityModuleAssociation(World memory world, uint256 entityId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleSystemId(),
      abi.encodeCall(IModuleSystem.removeEntityModuleAssociation, (entityId, moduleId))
    );
  }

  function removeSystemModuleAssociation(World memory world, ResourceId systemId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleSystemId(),
      abi.encodeCall(IModuleSystem.removeSystemModuleAssociation, (systemId, moduleId))
    );
  }
}
