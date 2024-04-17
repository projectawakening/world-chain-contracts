//SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { INVENTORY_MODULE_NAME as MODULE_NAME, INVENTORY_MODULE_NAMESPACE as MODULE_NAMESPACE } from "./constants.sol";
import { InventoryTable } from "../../codegen/tables/InventoryTable.sol";
import { InventoryItemTable } from "../../codegen/tables/InventoryItemTable.sol";
import { EphemeralInventoryTable } from "../../codegen/tables/EphemeralInventoryTable.sol";
import { EphemeralInvItemTable } from "../../codegen/tables/EphemeralInvItemTable.sol";
import { ItemTransferOffchainTable } from "../../codegen/tables/ItemTransferOffchainTable.sol";

import { InventorySystem } from "./systems/InventorySystem.sol";
import { EphemeralInventorySystem } from "./systems/EphemeralInventorySystem.sol";

import { Utils } from "./Utils.sol";

contract InventoryModule is Module {
  error InventoryModule_InvalidNamespace(bytes14 namespace);

  address immutable registrationLibrary = address(new InventoryModuleRegistration());

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
    //Require the module to be installed with the args
    requireNotInstalled(__self, encodeArgs);

    //Extract args
    bytes14 namespace = abi.decode(encodeArgs, (bytes14));

    //Require the namespace to not be the module's namespace
    if (namespace == MODULE_NAMESPACE) {
      revert InventoryModule_InvalidNamespace(namespace);
    }

    //Require the dependencies to be installed
    _requireDependencies();

    //Register Inventory module's tables and systems
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory returnedData) = registrationLibrary.delegatecall(
      abi.encodeCall(InventoryModuleRegistration.register, (world, namespace))
    );
    require(success, string(returnedData));

    //Transfer the ownership of the namespace to the caller
    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(namespace);
    world.transferOwnership(namespaceId, _msgSender());
  }

  function installRoot(bytes memory) public pure {
    revert Module_RootInstallNotSupported();
  }
}

contract InventoryModuleRegistration {
  using Utils for bytes14;

  function register(IBaseWorld world, bytes14 namespace) public {
    //Register the namespace
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));

    //Register the tables and systems for inventory namespace
    InventoryTable.register(namespace.inventoryTableId());
    InventoryItemTable.register(namespace.inventoryItemTableId());
    EphemeralInventoryTable.register(namespace.ephemeralInventoryTableId());
    EphemeralInvItemTable.register(namespace.ephemeralInventoryItemTableId());
    ItemTransferOffchainTable.register(namespace.itemTransferTableId());

    //Register the systems
    world.registerSystem(namespace.inventorySystemId(), new InventorySystem(), true);
    world.registerSystem(namespace.ephemeralInventorySystemId(), new EphemeralInventorySystem(), true);
  }
}
