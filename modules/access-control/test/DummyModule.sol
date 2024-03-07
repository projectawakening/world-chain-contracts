// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";

import "./constants.sol";


contract DummySystem is EveSystem {
  function echoFoo(uint256 entityId) public 
    hookable(entityId, _systemId(), abi.encode(entityId)) 
    returns (uint256)
  {
    return entityId;
  }

  function echoBar(uint256 entityId, uint256 someNumber) public 
    hookable(entityId, _systemId(), abi.encode(entityId)) 
    returns (bytes memory)
  {
    return msg.data;
  }

  function _systemId() internal view returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: _namespace(), name: DUMMY_SYSTEM_NAME });
  }
}

contract DummyModule is Module {
  error DummyModule_InvalidNamespace(bytes14 namespace);
  error DummyModule_RegistrationFailed(bytes returnValue);

  address immutable registrationLibrary = address(new DummyModuleRegistrationLibrary());

  function getName() public pure returns (bytes16) {
    return DUMMY_MODULE_NAME;
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
    if (namespace == DUMMY_MODULE_NAMESPACE) {
      revert DummyModule_InvalidNamespace(namespace);
    }

    // Require dependencies
    _requireDependencies();

    // Register the access control tables and system
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(abi.encodeCall(DummyModuleRegistrationLibrary.register, (world, namespace)));
    require(success, string(returnedData));

    // Transfer ownership of the namespace to the caller
    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract DummyModuleRegistrationLibrary {
  /**
   * Register systems and tables for a new access control in a given namespace
   */
  function register(IBaseWorld world, bytes14 namespace) public {
    // Register the namespace
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Register the tables
    // TODO...
    ResourceId resourceId = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: DUMMY_SYSTEM_NAME });
    // Register a new DummySystem
    world.registerSystem(resourceId, new DummySystem(), true);
  }
}
