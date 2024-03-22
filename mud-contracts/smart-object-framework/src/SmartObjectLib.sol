// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./utils.sol";
import { HookType } from "./types.sol";

import { IEntityCore } from "./interfaces/IEntityCore.sol";
import { IHookCore } from "./interfaces/IHookCore.sol";
import { IModuleCore } from "./interfaces/IModuleCore.sol";

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

  // EntityCore methods
  function registerEntityType(World memory world, uint8 entityTypeId, bytes32 entityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.registerEntityType, (entityTypeId, entityType))
    );
  }

  function registerEntity(World memory world, uint256 entityId, uint8 entityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.registerEntity, (entityId, entityType))
    );
  }

  function registerEntities(World memory world, uint256[] memory entityId, uint8[] memory entityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.registerEntities, (entityId, entityType))
    );
  }

  function registerEntityTypeAssociation(World memory world, uint8 entityType, uint8 tagEntityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.registerEntityTypeAssociation, (entityType, tagEntityType))
    );
  }

  function tagEntity(World memory world, uint256 entityId, uint256 entityTagId) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.tagEntity, (entityId, entityTagId))
    );
  }

  function tagEntities(World memory world, uint256 entityId, uint256[] memory entityTagIds) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.tagEntities, (entityId, entityTagIds))
    );
  }

  function removeEntityTag(World memory world, uint256 entityId, uint256 entityTagId) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCore.removeEntityTag, (entityId, entityTagId))
    );
  }

  // HookCore methods
  function registerHook(World memory world, ResourceId systemId, bytes4 functionId) internal {
    world.iface.call(
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCore.registerHook, (systemId, functionId))
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
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCore.addHook, (hookId, hookType, systemId, functionSelector))
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
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCore.removeHook, (hookId, hookType, systemId, functionSelector))
    );
  }

  function associateHook(World memory world, uint256 entityId, uint256 hookId) internal {
    world.iface.call(world.namespace.hookCoreSystemId(), abi.encodeCall(IHookCore.associateHook, (entityId, hookId)));
  }

  function associateHooks(World memory world, uint256 entityId, uint256[] memory hookIds) internal {
    world.iface.call(world.namespace.hookCoreSystemId(), abi.encodeCall(IHookCore.associateHooks, (entityId, hookIds)));
  }

  function removeEntityHookAssociation(World memory world, uint256 entityId, uint256 hookId) internal {
    world.iface.call(
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCore.removeEntityHookAssociation, (entityId, hookId))
    );
  }

  // ModuleCore methods
  function registerEVEModule(World memory world, uint256 moduleId, bytes16 moduleName, ResourceId systemId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCore.registerEVEModule, (moduleId, moduleName, systemId))
    );
  }

  function registerEVEModules(
    World memory world,
    uint256 moduleId,
    bytes16 moduleName,
    ResourceId[] memory systemIds
  ) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCore.registerEVEModules, (moduleId, moduleName, systemIds))
    );
  }

  function associateModule(World memory world, uint256 entityId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCore.associateModule, (entityId, moduleId))
    );
  }

  function associateModules(World memory world, uint256 entityId, uint256[] memory moduleIds) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCore.associateModules, (entityId, moduleIds))
    );
  }

  function removeEntityModuleAssociation(World memory world, uint256 entityId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCore.removeEntityModuleAssociation, (entityId, moduleId))
    );
  }

  function removeSystemModuleAssociation(World memory world, ResourceId systemId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCore.removeSystemModuleAssociation, (systemId, moduleId))
    );
  }
}
