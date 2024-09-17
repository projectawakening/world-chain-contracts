// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { Module } from "@latticexyz/world/src/Module.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { KillMailTable } from "../../codegen/tables/KillMailTable.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";
import { KILL_MAIL_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { KillMailSystem } from "./systems/KillMailSystem.sol";
import { Utils } from "./Utils.sol";

contract KillMailModule is Module {
  error KillMailModule_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new KillMailModuleRegistrationLibrary());

  function _requireDependencies() internal view {}

  function install(bytes memory encodedArgs) public {
    requireNotInstalled(__self, encodedArgs);

    bytes14 namespace = abi.decode(encodedArgs, (bytes14));

    if (namespace == MODULE_NAMESPACE) {
      revert KillMailModule_InvalidNamespace(namespace);
    }

    _requireDependencies();

    IBaseWorld world = IBaseWorld(_world());

    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(KillMailModuleRegistrationLibrary.register, (world, namespace))
    );

    if (!success) {
      revertWithBytes(returnedData);
    }

    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract KillMailModuleRegistrationLibrary {
  using Utils for bytes14;

  function register(IBaseWorld world, bytes14 namespace) public {
    ResourceId encodedNamespace = WorldResourceIdLib.encodeNamespace(namespace);
    if (!ResourceIds.getExists(encodedNamespace)) {
      world.registerNamespace(encodedNamespace);
    }

    if (!ResourceIds.getExists(KillMailTable._tableId)) {
      KillMailTable.register();
    }

    if (!ResourceIds.getExists(namespace.killMailSystemId())) {
      world.registerSystem(namespace.killMailSystemId(), new KillMailSystem(), true);
    }
  }
}
