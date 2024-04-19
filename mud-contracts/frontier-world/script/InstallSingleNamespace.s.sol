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

// core module registration imports
import { AccessManagementSystem } from "@latticexyz/world/src/modules/core/implementations/AccessManagementSystem.sol";
import { BalanceTransferSystem } from "@latticexyz/world/src/modules/core/implementations/BalanceTransferSystem.sol";
import { BatchCallSystem } from "@latticexyz/world/src/modules/core/implementations/BatchCallSystem.sol";
import { CoreModule } from "@latticexyz/world/src/modules/core/CoreModule.sol";
import { CoreRegistrationSystem } from "@latticexyz/world/src/modules/core/CoreRegistrationSystem.sol";

import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { registerERC721 } from "../src/modules/eve-erc721-puppet/registerERC721.sol";
import { StaticDataGlobalTableData } from "../src/codegen/tables/StaticDataGlobalTable.sol";
import { IERC721Mintable } from "../src/modules/eve-erc721-puppet/IERC721Mintable.sol";

import "@eve/common-constants/src/constants.devnet.sol";
import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityRecordModule } from "../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../src/modules/static-data/StaticDataModule.sol";
import { InventoryModule } from "../src/modules/inventory/InventoryModule.sol";
import { LocationModule } from "../src/modules/location/LocationModule.sol";
import { SmartCharacterModule } from "../src/modules/smart-character/SmartCharacterModule.sol";
import { SmartDeployableModule } from "../src/modules/smart-deployable/SmartDeployableModule.sol";
//import { SmartStorageUnitModule } from "../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";

contract InstallSingleNamespaceModules is Script {
  function run(address worldAddress) external {

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);

    IBaseWorld world = IBaseWorld(address(worldAddress));
    //world.initialize(createCoreModule()); 
    StoreSwitch.setStoreAddress(worldAddress);

    // creating all module contracts
    PuppetModule puppetModule = new PuppetModule();
    SmartObjectFrameworkModule sofModule = new SmartObjectFrameworkModule();
    EntityRecordModule entityRecordModule = new EntityRecordModule();
    StaticDataModule staticDataModule = new StaticDataModule();
    LocationModule locationModule = new LocationModule();
    SmartCharacterModule smartCharacterModule = new SmartCharacterModule();
    SmartDeployableModule smartDeployableModule = new SmartDeployableModule();
    InventoryModule inventoryModule = new InventoryModule();
    //SmartStorageUnitModule ssuModule = new SmartStorageUnitModule();

    // puppetModule is conventionally installed as such
    world.installModule(puppetModule, new bytes(0));
    
    // installing all modules sequentially
    _installModule(world, sofModule, SMART_OBJECT_DEPLOYMENT_NAMESPACE);
    _installModule(world, entityRecordModule, ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    _installModule(world, staticDataModule, STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(world, locationModule, LOCATION_DEPLOYMENT_NAMESPACE);
    _installModule(world, smartCharacterModule, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
    _installModule(world, smartDeployableModule, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    _installModule(world, inventoryModule, INVENTORY_DEPLOYMENT_NAMESPACE);
    
    IERC721Mintable erc721Token = registerERC721(
      world,
      EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE,
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: "" })
    );

    vm.stopBroadcast();
  }

  function _installModule(IBaseWorld world, IModule module, bytes14 namespace) internal {
    world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function createCoreModule() internal returns (CoreModule) {
  return
    new CoreModule(
      new AccessManagementSystem(),
      new BalanceTransferSystem(),
      new BatchCallSystem(),
      new CoreRegistrationSystem()
    );
}
}
