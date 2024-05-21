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

import "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { HookType } from "@eveworld/smart-object-framework/src/types.sol";

import { ModulesInitializationLibrary } from "../src/utils/ModulesInitializationLibrary.sol";
import { SOFInitializationLibrary } from "../src/utils/SOFInitializationLibrary.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { Utils as GateKeeperUtils } from "../src/modules/gate-keeper/Utils.sol";
import { Utils as InventoryUtils } from "../src/modules/inventory/Utils.sol";

import { IGateKeeper } from "../src/modules/gate-keeper/interfaces/IGateKeeper.sol";
import { IInventory } from "../src/modules/inventory/interfaces/IInventory.sol";
import { IInventoryInteract } from "../src/modules/inventory/interfaces/IInventoryInteract.sol";
import { EntityRecordModule } from "../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../src/modules/location/LocationModule.sol";
import { SmartCharacterModule } from "../src/modules/smart-character/SmartCharacterModule.sol";
import { SmartDeployableModule } from "../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployableLib } from "../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployable } from "../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartStorageUnitModule } from "../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { GateKeeperModule } from "../src/modules/gate-keeper/GateKeeperModule.sol";
import { SmartCharacterLib } from "../src/modules/smart-character/SmartCharacterLib.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";

import { InventoryModule } from "../src/modules/inventory/InventoryModule.sol";
import { Inventory } from "../src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "../src/modules/inventory/systems/EphemeralInventory.sol";
import { InventoryInteract } from "../src/modules/inventory/systems/InventoryInteract.sol";

import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { EntityTable, EntityTableData } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { EntityMap } from "@eveworld/smart-object-framework/src/codegen/tables/EntityMap.sol";
import { Utils as SmartObjectUtils } from "@eveworld/smart-object-framework/src/utils.sol";

contract PostDeploy is Script {
  using SmartObjectUtils for bytes14;
  using ModulesInitializationLibrary for IBaseWorld;
  using SOFInitializationLibrary for IBaseWorld;
  using SmartObjectLib for SmartObjectLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;

  SmartStorageUnitLib.World smartStorageUnit;
  using GateKeeperUtils for bytes14;
  using InventoryUtils for bytes14;

  IBaseWorld world;
  SmartObjectLib.World smartObject;

  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    world = IBaseWorld(worldAddress);
    string memory baseURI = vm.envString("BASE_URI");
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    vm.startBroadcast(deployerPrivateKey);
    // installing all modules sequentially
    _installModule(
      deployer,
      new SmartObjectFrameworkModule(),
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      address(new EntityCore()),
      address(new HookCore()),
      address(new ModuleCore())
    );
    _installPuppet(deployer);
    _installModule(deployer, new StaticDataModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(deployer, new EntityRecordModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(deployer, new LocationModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(deployer, new SmartCharacterModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(
      deployer,
      new SmartDeployableModule(),
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      address(new SmartDeployable())
    );
    _installModule(
      deployer,
      new InventoryModule(),
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      address(new Inventory()),
      address(new EphemeralInventory()),
      address(new InventoryInteract())
    );
    _installModule(deployer, new SmartStorageUnitModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    _installModule(deployer, new GateKeeperModule(), FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    // register new ERC721 puppets for SmartCharacter and SmartDeployable modules
    _initERC721(baseURI);

    _initModules();
    _initERC721(baseURI);
    vm.stopBroadcast();
  }

  function _initModules() internal {
    world.initSOF();
    smartObject = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);
    world.initStaticData();
    world.initEntityRecord();
    world.initLocation();
    world.initSmartCharacter();
    world.initSmartDeployable();
    world.initInventory();
    world.initSSU();
    world.initGateKeeper();

    smartObject.registerEntity(SMART_CHARACTER_CLASS_ID, CLASS);
    smartObject.registerEntity(SMART_DEPLOYABLE_CLASS_ID, CLASS);
    smartObject.registerEntity(SSU_CLASS_ID, CLASS);
    smartObject.registerEntity(GATE_KEEPER_CLASS_ID, CLASS);
    world.associateClassIdToSmartCharacter(SMART_CHARACTER_CLASS_ID);
    world.associateClassIdToSmartDeployable(SMART_DEPLOYABLE_CLASS_ID);
    world.associateClassIdToSSU(SSU_CLASS_ID);
    world.associateClassIdToGateKeeper(GATE_KEEPER_CLASS_ID);

    uint256 smartDeplFrontierClassId = world.registerAndAssociateTypeIdToSSU(SMART_DEPLOYABLE_FRONTIER_TYPE_ID);
    console.log("Smart Deployable (Frontier TypeId: 77917) - classId: ", smartDeplFrontierClassId);

    _registerClassLevelHookGateKeeper();
  }

  function _installPuppet(address deployer) internal {
    StoreSwitch.setStoreAddress(address(world));
    // creating all module contracts
    PuppetModule puppetModule = new PuppetModule();
    // puppetModule is conventionally installed as such
    world.installModule(puppetModule, new bytes(0));
  }

  function _installModule(address deployer, IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == deployer)
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function _installModule(
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

  function _initERC721(string memory baseURI) internal {
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

    SmartDeployableLib
      .World({ iface: IBaseWorld(world), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE })
      .globalResume();
  }

  function _registerClassLevelHookGateKeeper() internal {
    ResourceId gateKeeperSystemId = GATE_KEEPER_DEPLOYMENT_NAMESPACE.gateKeeperSystemId();
    ResourceId inventoryInteractSystemId = INVENTORY_DEPLOYMENT_NAMESPACE.inventoryInteractSystemId();
    ResourceId inventorySystemId = INVENTORY_DEPLOYMENT_NAMESPACE.inventorySystemId();

    smartObject.registerHook(gateKeeperSystemId, IGateKeeper.depositToInventoryHook.selector);
    uint256 depositHookId = uint256(
      keccak256(abi.encodePacked(gateKeeperSystemId, IGateKeeper.depositToInventoryHook.selector))
    );
    smartObject.associateHook(GATE_KEEPER_CLASS_ID, depositHookId);
    smartObject.addHook(depositHookId, HookType.BEFORE, inventorySystemId, IInventory.depositToInventory.selector);

    smartObject.registerHook(gateKeeperSystemId, IGateKeeper.ephemeralToInventoryTransferHook.selector);
    uint256 transferHookId = uint256(
      keccak256(abi.encodePacked(gateKeeperSystemId, IGateKeeper.ephemeralToInventoryTransferHook.selector))
    );
    smartObject.associateHook(GATE_KEEPER_CLASS_ID, transferHookId);
    smartObject.addHook(
      transferHookId,
      HookType.BEFORE,
      inventoryInteractSystemId,
      IInventoryInteract.ephemeralToInventoryTransfer.selector
    );
  }
}