// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { SMART_OBJECT_MODULE_NAME as MODULE_NAME, SMART_OBJECT_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { Utils } from "./utils.sol";

import { EntitySystem } from "./systems/core/EntitySystem.sol";
import { ModuleSystem } from "./systems/core/ModuleSystem.sol";
import { HookSystem } from "./systems/core/HookSystem.sol";

import { EntityAssociation } from "./codegen/tables/EntityAssociation.sol";
import { EntityMap } from "./codegen/tables/EntityMap.sol";
import { EntityTable } from "./codegen/tables/EntityTable.sol";
import { EntityType } from "./codegen/tables/EntityType.sol";
import { EntityTypeAssociation } from "./codegen/tables/EntityTypeAssociation.sol";
import { HookTable } from "./codegen/tables/HookTable.sol";
import { HookTargetAfter } from "./codegen/tables/HookTargetAfter.sol";
import { HookTargetBefore } from "./codegen/tables/HookTargetBefore.sol";
import { ModuleSystemLookup } from "./codegen/tables/ModuleSystemLookup.sol";
import { ModuleTable } from "./codegen/tables/ModuleTable.sol";

contract SmartObjectFrameworkModule is Module {
  error SmartObjectFrameworkModule_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new SmartObjectFrameworkModuleRegistrationLibrary());

  function getName() public pure returns (bytes16) {
    return MODULE_NAME;
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _requireDependencies() internal view {
    // Require other modules to be installed
    // (not the case here)
    //
    // if (!isInstalled(bytes16("MODULE_NAME"), new bytes(0))) {
    //   revert Module_MissingDependency(string(bytes.concat("MODULE_NAME")));
    // }
  }

  // TODO: For now, this method expect four encoded args, but there's no check to verify the contracts behind those address are any valid
  // (bytes14,address,address,address) -> (namespace, entitySystem, hookSystem, moduleSystem)
  function install(bytes memory encodedArgs) public {
    // Require the module to not be installed with these args yet
    requireNotInstalled(__self, encodedArgs);

    // Extract args
    // TODO doing so means we have to "trust" whoever calls the `install` method to forward the right contracts
    // needs a re-think at some point
    (bytes14 namespace, address entitySystem, address hookSystem, address moduleSystem) = abi.decode(
      encodedArgs,
      (bytes14, address, address, address)
    );

    // Require the namespace to not be the module's namespace
    if (namespace == MODULE_NAMESPACE) {
      revert SmartObjectFrameworkModule_InvalidNamespace(namespace);
    }

    // Require dependencies
    _requireDependencies();

    // Register the smart object framework's tables and systems
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(
        SmartObjectFrameworkModuleRegistrationLibrary.register,
        (world, namespace, entitySystem, hookSystem, moduleSystem)
      )
    );
    if (!success) revertWithBytes(returnedData);

    // Transfer ownership of the namespace to the caller
    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  // would be a very bad idea (see issue #5 on Github)
  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract SmartObjectFrameworkModuleRegistrationLibrary {
  using Utils for bytes14;

  /**
   * Register systems and tables for a new smart object framework in a given namespace
   */
  function register(
    IBaseWorld world,
    bytes14 namespace,
    address entitySystem,
    address hookSystem,
    address moduleSystem
  ) public {
    // Register the namespace
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace)))
      world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Register the tables
    if (!ResourceIds.getExists(EntityAssociation._tableId))
      EntityAssociation.register();
    if (!ResourceIds.getExists(EntityMap._tableId)) EntityMap.register();
    if (!ResourceIds.getExists(EntityTable._tableId)) EntityTable.register();
    if (!ResourceIds.getExists(EntityType._tableId)) EntityType.register();
    if (!ResourceIds.getExists(EntityTypeAssociation._tableId))
      EntityTypeAssociation.register();
    if (!ResourceIds.getExists(HookTable._tableId)) HookTable.register();
    if (!ResourceIds.getExists(HookTargetAfter._tableId))
      HookTargetAfter.register();
    if (!ResourceIds.getExists(HookTargetBefore._tableId))
      HookTargetBefore.register();
    if (!ResourceIds.getExists(ModuleSystemLookup._tableId))
      ModuleSystemLookup.register();
    if (!ResourceIds.getExists(ModuleTable._tableId)) ModuleTable.register();

    // Register a new Systems suite
    if (!ResourceIds.getExists(namespace.entitySystemId()))
      world.registerSystem(namespace.entitySystemId(), System(entitySystem), true);
    if (!ResourceIds.getExists(namespace.moduleSystemId()))
      world.registerSystem(namespace.moduleSystemId(), System(moduleSystem), true);
    if (!ResourceIds.getExists(namespace.hookSystemId()))
      world.registerSystem(namespace.hookSystemId(), System(hookSystem), true);
  }
}
