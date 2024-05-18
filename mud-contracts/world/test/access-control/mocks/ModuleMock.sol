//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { 
  MODULE_MOCK_NAME as MODULE_NAME,
  MODULE_MOCK_NAMESPACE as MODULE_NAMESPACE,
  FORWARD_MOCK_SYSTEM_ID,
  HOOKABLE_MOCK_SYSTEM_ID,
  ACCESS_RULE_MOCK_SYSTEM_ID } from "./mockconstants.sol";

import { ForwardMock } from "./ForwardMock.sol";
import { HookableMock } from "./HookableMock.sol";

contract ModuleMock is Module {

  error ModuleMock_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new ModuleMockRegistrationLibrary());

  function getName() public pure returns (bytes16) {
    return MODULE_NAME;
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _requireDependencies() internal view {
    //Require other dependant modules to be registered
  }

  function install(bytes memory encodeArgs) public {
    // Require the module to be installed with the args
    requireNotInstalled(__self, encodeArgs);

    //Extract args
    (bytes14 namespace, address forwardMockSystem, address hookableMockSystem, address accessRuleMockSystem) = abi.decode(
      encodeArgs,
      (bytes14, address, address, address)
    );

    //Require the namespace to not be the module's namespace
    if (namespace == MODULE_NAMESPACE) {
      revert ModuleMock_InvalidNamespace(namespace);
    }

    //Require the dependencies to be installed
    _requireDependencies();

    //Register Inventory module's tables and systems
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(
        ModuleMockRegistrationLibrary.register,
        (world, namespace, forwardMockSystem, hookableMockSystem, accessRuleMockSystem)
      )
    );
    if (!success) revertWithBytes(returnedData);
    
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) != _msgSender()) {
      // Transfer the ownership of the namespace to the caller
      ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
      world.transferOwnership(namespaceId, _msgSender());
    }

  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract ModuleMockRegistrationLibrary {
  function register(
    IBaseWorld world,
    bytes14 namespace,
    address forwardMockSystem,
    address hookableMockSystem,
    address accessRuleMockSystem
  ) public {
    // Register the namespace
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace)))
      world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));

    // Register the systems
    if (!ResourceIds.getExists(FORWARD_MOCK_SYSTEM_ID))
      world.registerSystem(FORWARD_MOCK_SYSTEM_ID, System(forwardMockSystem), true);
    if (!ResourceIds.getExists(HOOKABLE_MOCK_SYSTEM_ID))
      world.registerSystem(HOOKABLE_MOCK_SYSTEM_ID, System(hookableMockSystem), true);
    if (!ResourceIds.getExists(ACCESS_RULE_MOCK_SYSTEM_ID))
      world.registerSystem(ACCESS_RULE_MOCK_SYSTEM_ID, System(accessRuleMockSystem), true);
  }
}