// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./utils.sol";
import { HookType } from "./types.sol";

/**
 * @title IEntityCoreSystem
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 * Needs to match corresponding System exhaustively
 */
interface IEntityCoreSystem {
  function registerEntityType(uint8 entityTypeId, bytes32 entityType) external;

  function registerEntity(uint256 entityId, uint8 entityType) external;

  function registerEntities(uint256[] memory entityId, uint8[] memory entityType) external;

  function registerEntityTypeAssociation(uint8 entityType, uint8 tagEntityType) external;

  function tagEntity(uint256 entityId, uint256 entityTagId) external;

  function tagEntities(uint256 entityId, uint256[] memory entityTagIds) external;

  function removeEntityTag(uint256 entityId, uint256 entityTagId) external;
}

/**
 * @title IHookCoreSystem
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 * Needs to match corresponding System exhaustively
 */
interface IHookCoreSystem {
  function registerHook(ResourceId systemId, bytes4 functionId) external;

  function addHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) external;

  function removeHook(uint256 hookId, HookType hookType, ResourceId systemId, bytes4 functionSelector) external;

  function associateHook(uint256 entityId, uint256 hookId) external;

  function associateHooks(uint256 entityId, uint256[] memory hookIds) external;

  function removeEntityHookAssociation(uint256 entityId, uint256 hookId) external;
}

/**
 * @title IModuleCoreSystem
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 * Needs to match corresponding System exhaustively
 */
interface IModuleCoreSystem {
  function registerEVEModule(uint256 moduleId, bytes16 moduleName, ResourceId systemId) external;

  function registerEVEModules(uint256 moduleId, bytes16 moduleName, ResourceId[] memory systemIds) external;

  function associateModule(uint256 entityId, uint256 moduleId) external;

  function associateModules(uint256 entityId, uint256[] memory moduleIds) external;

  function removeEntityModuleAssociation(uint256 entityId, uint256 moduleId) external;

  function removeSystemModuleAssociation(ResourceId systemId, uint256 moduleId) external;
}

/**
 * @title Smart Object Framework Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
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
      abi.encodeCall(IEntityCoreSystem.registerEntityType, (entityTypeId, entityType))
    );
  }

  function registerEntity(World memory world, uint256 entityId, uint8 entityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCoreSystem.registerEntity, (entityId, entityType))
    );
  }

  function registerEntities(World memory world, uint256[] memory entityId, uint8[] memory entityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCoreSystem.registerEntities, (entityId, entityType))
    );
  }

  function registerEntityTypeAssociation(World memory world, uint8 entityType, uint8 tagEntityType) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCoreSystem.registerEntityTypeAssociation, (entityType, tagEntityType))
    );
  }

  function tagEntity(World memory world, uint256 entityId, uint256 entityTagId) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCoreSystem.tagEntity, (entityId, entityTagId))
    );
  }

  function tagEntities(World memory world, uint256 entityId, uint256[] memory entityTagIds) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCoreSystem.tagEntities, (entityId, entityTagIds))
    );
  }

  function removeEntityTag(World memory world, uint256 entityId, uint256 entityTagId) internal {
    world.iface.call(
      world.namespace.entityCoreSystemId(),
      abi.encodeCall(IEntityCoreSystem.removeEntityTag, (entityId, entityTagId))
    );
  }

  // HookCore methods
  function registerHook(World memory world, ResourceId systemId, bytes4 functionId) internal {
    world.iface.call(
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCoreSystem.registerHook, (systemId, functionId))
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
      abi.encodeCall(IHookCoreSystem.addHook, (hookId, hookType, systemId, functionSelector))
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
      abi.encodeCall(IHookCoreSystem.removeHook, (hookId, hookType, systemId, functionSelector))
    );
  }

  function associateHook(World memory world, uint256 entityId, uint256 hookId) internal {
    world.iface.call(
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCoreSystem.associateHook, (entityId, hookId))
    );
  }

  function associateHooks(World memory world, uint256 entityId, uint256[] memory hookIds) internal {
    world.iface.call(
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCoreSystem.associateHooks, (entityId, hookIds))
    );
  }

  function removeEntityHookAssociation(World memory world, uint256 entityId, uint256 hookId) internal {
    world.iface.call(
      world.namespace.hookCoreSystemId(),
      abi.encodeCall(IHookCoreSystem.removeEntityHookAssociation, (entityId, hookId))
    );
  }

  // ModuleCore methods
  function registerEVEModule(World memory world, uint256 moduleId, bytes16 moduleName, ResourceId systemId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCoreSystem.registerEVEModule, (moduleId, moduleName, systemId))
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
      abi.encodeCall(IModuleCoreSystem.registerEVEModules, (moduleId, moduleName, systemIds))
    );
  }

  function associateModule(World memory world, uint256 entityId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCoreSystem.associateModule, (entityId, moduleId))
    );
  }

  function associateModules(World memory world, uint256 entityId, uint256[] memory moduleIds) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCoreSystem.associateModules, (entityId, moduleIds))
    );
  }

  function removeEntityModuleAssociation(World memory world, uint256 entityId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCoreSystem.removeEntityModuleAssociation, (entityId, moduleId))
    );
  }

  function removeSystemModuleAssociation(World memory world, ResourceId systemId, uint256 moduleId) internal {
    world.iface.call(
      world.namespace.moduleCoreSystemId(),
      abi.encodeCall(IModuleCoreSystem.removeSystemModuleAssociation, (systemId, moduleId))
    );
  }
}
