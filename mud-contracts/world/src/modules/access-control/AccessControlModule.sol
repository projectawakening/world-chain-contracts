//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { ACCESS_CONTROL_MODULE_NAME as MODULE_NAME, ACCESS_CONTROL_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { Role } from "../../codegen/tables/Role.sol";
import { HasRole } from "../../codegen/tables/HasRole.sol";
import { RoleAdminChanged } from "../../codegen/tables/RoleAdminChanged.sol";
import { RoleCreated } from "../../codegen/tables/RoleCreated.sol";
import { RoleGranted } from "../../codegen/tables/RoleGranted.sol";
import { RoleRevoked } from "../../codegen/tables/RoleRevoked.sol";
import { AccessConfig } from "../../codegen/tables/AccessConfig.sol";

import { AccessControl } from "./systems/AccessControl.sol";
import { AccessRulesConfig } from "./systems/AccessRulesConfig.sol";

import { Utils } from "./Utils.sol";

contract AccessControlModule is Module {
  error AccessControlModule_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new AccessControlModuleRegistrationLibrary());

  function getName() public pure returns (bytes16) {
    return MODULE_NAME;
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _requireDependencies() internal view {
    //Require other dependant modules to be registered
  }

  // TODO: right now it needs to receive each system address as parameters (because of contract size limit), but there is no type checking
  // fix it
  function install(bytes memory encodeArgs) public {
    // Require the module to be installed with the args
    requireNotInstalled(__self, encodeArgs);

    //Extract args
    (bytes14 namespace, address accessControlSystem, address accessRulesConfig) = abi.decode(
      encodeArgs,
      (bytes14, address, address)
    );

    //Require the namespace to not be the module's namespace
    if (namespace == MODULE_NAMESPACE) {
      revert AccessControlModule_InvalidNamespace(namespace);
    }

    //Require the dependencies to be installed
    _requireDependencies();

    //Register Inventory module's tables and systems
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(
        AccessControlModuleRegistrationLibrary.register,
        (world, namespace, accessControlSystem, accessRulesConfig)
      )
    );
    if (!success) revertWithBytes(returnedData);
    
    //Transfer the ownership of the namespace to the caller
    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract AccessControlModuleRegistrationLibrary {
  using Utils for bytes14;

  function register(
    IBaseWorld world,
    bytes14 namespace,
    address accessControlSystem,
    address accessRulesConfig
  ) public {
    //Register the namespace
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace)))
      world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    
    //Register the tables and systems for inventory namespace
    if (!ResourceIds.getExists(namespace.roleTableId())) 
      Role.register(namespace.roleTableId());
    if (!ResourceIds.getExists(namespace.hasRoleTableId()))
      HasRole.register(namespace.hasRoleTableId());
    if (!ResourceIds.getExists(namespace.accessConfigTableId()))
      AccessConfig.register(namespace.accessConfigTableId());
    if (!ResourceIds.getExists(namespace.roleAdminChangedTableId()))
      RoleAdminChanged.register(namespace.roleAdminChangedTableId());
    if (!ResourceIds.getExists(namespace.roleCreatedTableId()))
      RoleCreated.register(namespace.roleCreatedTableId());
    if (!ResourceIds.getExists(namespace.roleGrantedTableId()))
      RoleGranted.register(namespace.roleGrantedTableId());
    if (!ResourceIds.getExists(namespace.roleRevokedTableId()))
      RoleRevoked.register(namespace.roleRevokedTableId());

    //Register the systems
    if (!ResourceIds.getExists(namespace.accessControlSystemId()))
      world.registerSystem(namespace.accessControlSystemId(), System(accessControlSystem), true);
    if (!ResourceIds.getExists(namespace.accessRulesConfigSystemId()))
      world.registerSystem(namespace.accessRulesConfigSystemId(), System(accessRulesConfig), true);
  }
}
