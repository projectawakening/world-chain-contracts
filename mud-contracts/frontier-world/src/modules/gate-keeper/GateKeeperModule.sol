//SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { SMART_STORAGE_MODULE_NAME as MODULE_NAME, SMART_STORAGE_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { Utils } from "./Utils.sol";

import { GateKeeperTable } from "../../codegen/tables/GateKeeperTable.sol";

import { GateKeeper } from "./systems/GateKeeper.sol";

contract SmartStorageUnitModule is Module {
  error GateKeeperModule_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new GateKeeperModuleRegistrationLibrary());

  function getName() public pure returns (bytes16) {
    return MODULE_NAME;
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _requireDependencies() internal view {}

  function install(bytes memory encodeArgs) public {
    requireNotInstalled(__self, encodeArgs);

    bytes14 namespace = abi.decode(encodeArgs, (bytes14));

    if (namespace == MODULE_NAMESPACE) {
      revert GateKeeperModule_InvalidNamespace(namespace);
    }

    _requireDependencies();

    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnData) = registrationLibrary.delegatecall(
      abi.encodeCall(GateKeeperModuleRegistrationLibrary.register, (world, namespace))
    );
    require(success, string(returnData));

    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract GateKeeperModuleRegistrationLibrary {
  using Utils for bytes14;

  /**
   * Register systems and tables for a new smart storage unit in a given namespace
   */
  function register(IBaseWorld world, bytes14 namespace) external {
    //Register the namespace
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace)))
      world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));

    // Register the tables
    if (!ResourceIds.getExists(namespace.gateKeeperTableId()))
      GateKeeperTable.register(namespace.gateKeeperTableId());

    //Register the systems
    if (!ResourceIds.getExists(namespace.gateKeeperSystemId()))
      world.registerSystem(namespace.gateKeeperSystemId(), new GateKeeper(), true);
  }
}
