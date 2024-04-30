// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";

import { SMART_OBJECT_MODULE_NAME as MODULE_NAME, SMART_OBJECT_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { Utils } from "./utils.sol";

import { EntityCore } from "./systems/core/EntityCore.sol";
import { ModuleCore } from "./systems/core/ModuleCore.sol";
import { HookCore } from "./systems/core/HookCore.sol";

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

  function install(bytes memory encodedArgs) public {
    // Require the module to not be installed with these args yet
    requireNotInstalled(__self, encodedArgs);

    // Extract args
    bytes14 namespace = abi.decode(encodedArgs, (bytes14));

    // Require the namespace to not be the module's namespace
    if (namespace == MODULE_NAMESPACE) {
      revert SmartObjectFrameworkModule_InvalidNamespace(namespace);
    }

    // Require dependencies
    _requireDependencies();

    // Register the smart object framework's tables and systems
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(SmartObjectFrameworkModuleRegistrationLibrary.register, (world, namespace))
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
  function register(IBaseWorld world, bytes14 namespace) public {
    // Register the namespace
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Register the tables
    EntityAssociation.register(namespace.entityAssociationTableId());
    EntityMap.register(namespace.entityMapTableId());
    EntityTable.register(namespace.entityTableTableId());
    EntityType.register(namespace.entityTypeTableId());
    EntityTypeAssociation.register(namespace.entityTypeAssociationTableId());
    HookTable.register(namespace.hookTableTableId());
    HookTargetAfter.register(namespace.hookTargetAfterTableId());
    HookTargetBefore.register(namespace.hookTargetBeforeTableId());
    ModuleSystemLookup.register(namespace.moduleSystemLookupTableId());
    ModuleTable.register(namespace.moduleTableTableId());

    // Register a new Systems suite
    world.registerSystem(namespace.entityCoreSystemId(), new EntityCore(), true);
    world.registerSystem(namespace.moduleCoreSystemId(), new ModuleCore(), true);
    world.registerSystem(namespace.hookCoreSystemId(), new HookCore(), true);
  }
}
