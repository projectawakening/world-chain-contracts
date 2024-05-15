// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { MODULE_NAME, MODULE_NAMESPACE, MODULE_NAMESPACE_ID } from "./constants.sol";
import { _hasRoleTableId, _roleAdminTableId, _accessControlSystemId } from "./utils.sol";
import { AccessControlSystem } from "./AccessControlSystem.sol";

import { HasRole } from "../codegen/tables/HasRole.sol";
import { RoleAdmin } from "../codegen/tables/RoleAdmin.sol";

contract AccessControlModule is Module {
  error AccessControlModule_InvalidNamespace(bytes14 namespace);
  error AccessControlModule_RegistrationFailed(bytes returnValue);

  address immutable registrationLibrary = address(new AccessControlModuleRegistrationLibrary());

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
      revert AccessControlModule_InvalidNamespace(namespace);
    }

    // Require dependencies
    _requireDependencies();

    // Register the access control tables and system
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(abi.encodeCall(AccessControlModuleRegistrationLibrary.register, (world, namespace)));
    require(success, string(returnedData));

    // Transfer ownership of the namespace to the caller
    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract AccessControlModuleRegistrationLibrary {
  /**
   * Register systems and tables for a new access control in a given namespace
   */
  function register(IBaseWorld world, bytes14 namespace) public {
    // Register the namespace
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Register the tables
    HasRole.register(_hasRoleTableId(namespace));
    RoleAdmin.register(_roleAdminTableId(namespace));

    // Register a new AccessControl System
    world.registerSystem(_accessControlSystemId(namespace), new AccessControlSystem(), true);
  }
}
