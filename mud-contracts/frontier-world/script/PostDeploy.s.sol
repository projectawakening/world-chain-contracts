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
import { SmartStorageUnitModule } from "../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { SmartCharacterLib } from "../src/modules/smart-character/SmartCharacterLib.sol";
import { InventoryModule } from "../src/modules/inventory/InventoryModule.sol";
import { Inventory } from "../src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "../src/modules/inventory/systems/EphemeralInventory.sol";
import { SmartDeployableLib } from "../src/modules/smart-deployable/SmartDeployableLib.sol";

contract PostDeploy is Script {
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;

  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    vm.startBroadcast(deployerPrivateKey);

    // creating all module contracts
    SmartObjectFrameworkModule sofModule = new SmartObjectFrameworkModule();
    EntityRecordModule entityRecordModule = new EntityRecordModule();
    StaticDataModule staticDataModule = new StaticDataModule();
    LocationModule locationModule = new LocationModule();
    SmartCharacterModule smartCharacterModule = new SmartCharacterModule();
    SmartDeployableModule smartDeployableModule = new SmartDeployableModule();
    InventoryModule inventoryModule = new InventoryModule();
    SmartStorageUnitModule ssuModule = new SmartStorageUnitModule();

    _installPuppet(world);
    
    // SOF System front-loaded
    // TODO: Stack (way) too deep. Even though this is technically a "script" it is also a standard solidity method
    // Also, the conditionals with module deployment means here we don't really need to actually deploy new contracts, do we ?

    // EntityCore entityCore = new EntityCore();
    // HookCore hookCore = new HookCore();
    // ModuleCore moduleCore = new ModuleCore();

    //InventoryModule Systems front-loaded
    Inventory inventorySystem = new Inventory();
    EphemeralInventory ephInvSystem = new EphemeralInventory();

    // installing all modules sequentially
    // TODO: Stack (way) too deep. Even though this is technically a "script" it is also a standard solidity method so 
    // same EVM restrictions applies, even if the underlying computations are performed over multiple transactions

    // _installModule(world, deployer, sofModule, SMART_OBJECT_DEPLOYMENT_NAMESPACE, address(entityCore), address(hookCore), address(moduleCore));
    // _installModule(world, deployer, entityRecordModule, ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    // _installModule(world, deployer, staticDataModule, STATIC_DATA_DEPLOYMENT_NAMESPACE);
    // _installModule(world, deployer, locationModule, LOCATION_DEPLOYMENT_NAMESPACE);
    // _installModule(world, deployer, smartCharacterModule, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
    // _installModule(world, deployer, smartDeployableModule, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    // _installModule(world, deployer, inventoryModule, INVENTORY_DEPLOYMENT_NAMESPACE, address(inventorySystem), address(ephInvSystem));
    // _installModule(world, deployer, ssuModule, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);

    _initERC721(world);

    vm.stopBroadcast();
  }

  function _installPuppet(IBaseWorld world) internal {
    // creating all module contracts
    PuppetModule puppetModule = new PuppetModule(); 
    // puppetModule is conventionally installed as such
    world.installModule(puppetModule, new bytes(0));
  }

  function _installModule(IBaseWorld world, address deployer, IModule module, bytes14 namespace) internal {
    if(NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function _installModule(IBaseWorld world, address deployer, IModule module, bytes14 namespace, address system1, address system2) internal {
    if(NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace, system1, system2));
  }

  function _installModule(IBaseWorld world, address deployer, IModule module, bytes14 namespace, address system1, address system2, address system3) internal {
    if(NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace, system1, system2, system3));
  }

  function _initERC721(IBaseWorld world) internal {
    string memory baseURI = vm.envString("BASE_URI");
    IERC721Mintable erc721CharacterToken;
    erc721CharacterToken = registerERC721(
      world,
      "myERC721",
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: baseURI })
    );

    console.log("Deploying ERC721 token with address: ", address(erc721CharacterToken));
    SmartCharacterLib
      .World({ iface: IBaseWorld(world), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE })
      .registerERC721Token(address(erc721CharacterToken));

    IERC721Mintable erc721SmartDeployableToken;
    erc721SmartDeployableToken = registerERC721(
      world,
      "erc721Deploybl",
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: baseURI })
    );

    console.log("Deploying ERC721 token with address: ", address(erc721SmartDeployableToken));
    SmartDeployableLib
      .World({ iface: IBaseWorld(world), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE })
      .registerDeployableToken(address(erc721SmartDeployableToken));

    vm.stopBroadcast();
  }
}
