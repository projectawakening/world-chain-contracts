// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

// World imports
import { World } from "@latticexyz/world/src/World.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";

import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { registerERC721 } from "../src/modules/eve-erc721-puppet/registerERC721.sol";
import { StaticDataGlobalTableData } from "../src/codegen/tables/StaticDataGlobalTable.sol";
import { IERC721Mintable } from "../src/modules/eve-erc721-puppet/IERC721Mintable.sol";

import "@eve/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eve/frontier-smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eve/frontier-smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eve/frontier-smart-object-framework/src/systems/core/ModuleCore.sol";

import { EntityRecordModule } from "../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../src/modules/location/LocationModule.sol";
import { SmartCharacterModule } from "../src/modules/smart-character/SmartCharacterModule.sol";
import { SmartDeployableModule } from "../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployableLib } from "../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployable } from "../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartStorageUnitModule } from "../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { SmartCharacterLib } from "../src/modules/smart-character/SmartCharacterLib.sol";
import { InventoryModule } from "../src/modules/inventory/InventoryModule.sol";
import { Inventory } from "../src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "../src/modules/inventory/systems/EphemeralInventory.sol";
import { InventoryInteract } from "../src/modules/inventory/systems/InventoryInteract.sol";

contract PostDeploy is Script {
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;

  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);
    string memory baseURI = vm.envString("BASE_URI");
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    vm.startBroadcast(deployerPrivateKey);
    // installing all modules sequentially
    _installModule(
      world,
      deployer,
      new SmartObjectFrameworkModule(),
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      address(new EntityCore()),
      address(new HookCore()),
      address(new ModuleCore())
    );
    _installPuppet(world, deployer);
    _installModule(world, deployer, new StaticDataModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(world, deployer, new EntityRecordModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(world, deployer, new LocationModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(world, deployer, new SmartCharacterModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(
      world,
      deployer,
      new SmartDeployableModule(),
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      address(new SmartDeployable())
    );
    _installModule(
      world,
      deployer,
      new InventoryModule(),
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      address(new Inventory()),
      address(new EphemeralInventory()),
      address(new InventoryInteract())
    );
    _installModule(world, deployer, new SmartStorageUnitModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    // register new ERC721 puppets for SmartCharacter and SmartDeployable modules
    _initERC721(world, baseURI);
    vm.stopBroadcast();
  }

  function _installPuppet(IBaseWorld world, address deployer) internal {
    StoreSwitch.setStoreAddress(address(world));
    // creating all module contracts
    PuppetModule puppetModule = new PuppetModule();
    // puppetModule is conventionally installed as such
    world.installModule(puppetModule, new bytes(0));
  }

  function _installModule(IBaseWorld world, address deployer, IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function _installModule(
    IBaseWorld world,
    address deployer,
    IModule module,
    bytes14 namespace,
    address system1
  ) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace, system1));
  }

  function _installModule(
    IBaseWorld world,
    address deployer,
    IModule module,
    bytes14 namespace,
    address system1,
    address system2
  ) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace, system1, system2));
  }

  function _installModule(
    IBaseWorld world,
    address deployer,
    IModule module,
    bytes14 namespace,
    address system1,
    address system2,
    address system3
  ) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace, system1, system2, system3));
  }

  function _initERC721(IBaseWorld world, string memory baseURI) internal {
    IERC721Mintable erc721SmartDeployableToken = registerERC721(
      world,
      "erc721deploybl",
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: baseURI })
    );

    IERC721Mintable erc721CharacterToken = registerERC721(
      world,
      "erc721charactr",
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: baseURI })
    );
    console.log("Deploying ERC721 token with address: ", address(erc721CharacterToken));
    SmartCharacterLib
      .World({ iface: IBaseWorld(world), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE })
      .registerERC721Token(address(erc721CharacterToken));

    console.log("Deploying ERC721 token with address: ", address(erc721SmartDeployableToken));
    SmartDeployableLib
      .World({ iface: IBaseWorld(world), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE })
      .registerDeployableToken(address(erc721SmartDeployableToken));
  }
}
