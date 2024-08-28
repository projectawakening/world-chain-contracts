// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { SMART_TURRET_MODULE_NAME as MODULE_NAME, SMART_TURRET_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { Utils } from "./Utils.sol";

import { SmartTurret } from "./systems/SmartTurret.sol";

import { SmartTurretConfigTable } from "../../codegen/tables/SmartTurretConfigTable.sol";

contract SmartTurretModule is Module {
  error SmartTurretModule_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new SmartTurretModuleRegistrationLibrary());

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
      revert SmartTurretModule_InvalidNamespace(namespace);
    }

    // Require dependencies
    _requireDependencies();

    // Register the smart turret's tables and systems
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(SmartTurretModuleRegistrationLibrary.register, (world, namespace))
    );
    require(success, string(returnedData));

    // Transfer ownership of the namespace to the caller
    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  // would be a very bad idea (see issue #5 on Github)
  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract SmartTurretModuleRegistrationLibrary {
  using Utils for bytes14;

  /**
   * Register systems and tables for a new smart turret in a given namespace
   */
  function register(IBaseWorld world, bytes14 namespace) public {
    // Register the namespace
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace)))
      world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Register the tables
    if (!ResourceIds.getExists(namespace.smartTurretConfigTableId()))
      SmartTurretConfigTable.register(namespace.smartTurretConfigTableId());

    // Register a new Systems suite
    if (!ResourceIds.getExists(namespace.smartTurretSystemId()))
      world.registerSystem(namespace.smartTurretSystemId(), new SmartTurret(), true);
  }
}
