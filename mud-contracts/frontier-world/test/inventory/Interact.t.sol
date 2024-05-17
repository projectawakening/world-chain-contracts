// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";

import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/frontier-smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/frontier-smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/frontier-smart-object-framework/src/systems/core/ModuleCore.sol";
import "@eveworld/common-constants/src/constants.sol";

import { ModulesInitializationLibrary } from "../../src/utils/ModulesInitializationLibrary.sol";
import { SOFInitializationLibrary } from "@eveworld/frontier-smart-object-framework/src/SOFInitializationLibrary.sol";
import { SmartObjectLib } from "@eveworld/frontier-smart-object-framework/src/SmartObjectLib.sol";
import { CLASS, OBJECT } from "@eveworld/frontier-smart-object-framework/src/constants.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { InventoryItemTableData, InventoryItemTable } from "../../src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInvTable } from "../../src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvTableData } from "../../src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { ItemTransferOffchainTable } from "../../src/codegen/tables/ItemTransferOffchainTable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";

import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";
import { Utils as CoreUtils } from "@eveworld/frontier-smart-object-framework/src/utils.sol";
import { EntityTable } from "@eveworld/frontier-smart-object-framework/src/codegen/tables/EntityTable.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { Inventory } from "../../src/modules/inventory/systems/Inventory.sol";
import { InventoryInteract } from "../../src/modules/inventory/systems/InventoryInteract.sol";
import { EphemeralInventory } from "../../src/modules/inventory/systems/EphemeralInventory.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartStorageUnitModule } from "../../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { IWorld } from "../../src/codegen/world/IWorld.sol";

import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";

import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

contract VendingMachineTestSystem is System {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using Utils for bytes14;

  /**
   * @notice Handle the interaction flow for vending machine to exchange 2x:10y items between two players
   * @dev Ideally the ration can be configured in a seperate function and stored on-chain
   * //TODO this function needs to be authorized by the builder to access inventory functions through RBAC
   * @param smartObjectId The smart object id of the smart storage unit
   * @param inventoryOwner The owner of the inventory
   * @param quantity is the quanity of the item to be exchanged
   */
  function interactHandler(uint256 smartObjectId, address inventoryOwner, uint256 quantity) public {
    //NOTE: Store the IN and OUT item details in table by configuring in a seperate function.
    //Its hardcoded only for testing purpose
    //Inventory Item IN data
    uint256 inItemId = uint256(keccak256(abi.encode("item:46")));
    uint256 outItemId = uint256(keccak256(abi.encode("item:45")));
    uint256 ratio = 1;
    address ephItemOwner = address(2); //Ideally this should the msg.sender

    //Below Data should be stored in a table and fetched from there
    InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem(inItemId, ephItemOwner, 46, 2, 70, quantity * ratio);

    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem(outItemId, inventoryOwner, 45, 1, 50, quantity * ratio);

    //Withdraw from inventory and deposit to ephemeral inventory
    _inventoryLib().inventoryToEphemeralTransfer(smartObjectId, outItems);

    //Withdraw from ephemeralnventory and deposit to inventory
    _inventoryLib().ephemeralToInventoryTransfer(smartObjectId, ephItemOwner, inItems);
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE))) {
      return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
    } else return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: DEPLOYMENT_NAMESPACE });
  }
}

contract InteractTest is Test {
  using Utils for bytes14;
  using CoreUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using ModulesInitializationLibrary for IBaseWorld;
  using SOFInitializationLibrary for IBaseWorld;
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  SmartObjectLib.World smartObject;
  EntityRecordLib.World entityRecord;
  InventoryLib.World inventory;
  SmartDeployableLib.World smartDeployable;
  InventoryModule inventoryModule;
  IERC721Mintable erc721DeployableToken;
  SmartStorageUnitLib.World smartStorageUnit;

  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";
  uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
  uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
  EntityRecordData entity1 = EntityRecordData({ typeId: 1, itemId: 2345, volume: 100 });
  EntityRecordData entity2 = EntityRecordData({ typeId: 45, itemId: 1, volume: 50 });
  EntityRecordData entity3 = EntityRecordData({ typeId: 46, itemId: 2, volume: 70 });

  VendingMachineTestSystem private vendingMachineSystem = new VendingMachineTestSystem();
  bytes16 constant SYSTEM_NAME = bytes16("System");
  ResourceId constant VENDING_MACHINE_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    // installing SOF & other modules (SmartCharacterModule dependancies)
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );
    world.initSOF();
    smartObject = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);
    // install module dependancies
    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    _installModule(new LocationModule(), LOCATION_DEPLOYMENT_NAMESPACE);
    world.initStaticData();
    world.initEntityRecord();
    world.initLocation();
    entityRecord = EntityRecordLib.World(world, ENTITY_RECORD_DEPLOYMENT_NAMESPACE);

    erc721DeployableToken = registerERC721(
      world,
      ERC721_DEPLOYABLE,
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: "" })
    );

    // install SmartDeployableModule
    SmartDeployableModule deployableModule = new SmartDeployableModule();
    if (
      NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE)) ==
      address(this)
    )
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE),
        address(deployableModule)
      );
    world.installModule(deployableModule, abi.encode(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, new SmartDeployable()));
    world.initSmartDeployable();

    smartObject.registerEntity(SMART_DEPLOYABLE_CLASS_ID, CLASS);
    world.associateClassIdToSmartDeployable(SMART_DEPLOYABLE_CLASS_ID);
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721DeployableToken));
    smartDeployable.globalResume();

    // Inventory Module installation
    inventoryModule = new InventoryModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE), address(inventoryModule));
    world.installModule(
      inventoryModule,
      abi.encode(DEPLOYMENT_NAMESPACE, new Inventory(), new EphemeralInventory(), new InventoryInteract())
    );
    world.initInventory();

    inventory = InventoryLib.World(world, DEPLOYMENT_NAMESPACE);

    // Smart Storage Module installation
    _installModule(new SmartStorageUnitModule(), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
    world.initSSU();
    smartStorageUnit = SmartStorageUnitLib.World(world, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
    smartObject.registerEntity(SSU_CLASS_ID, CLASS);
    world.associateClassIdToSSU(SSU_CLASS_ID);

    // Vending Machine registration
    world.registerSystem(VENDING_MACHINE_SYSTEM_ID, vendingMachineSystem, true);

    // Register system's functions
    world.registerFunctionSelector(VENDING_MACHINE_SYSTEM_ID, "interactHandler(uint256, address, uint256)");

    _createMockItems();
    //Mock Smart Storage Unit data
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: address(1), tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    uint256 storageCapacity = 100000;
    uint256 ephemeralStorageCapacity = 100000;
    address inventoryOwner = address(1);
    address ephItemOwner = address(2);

    smartStorageUnit.createAndAnchorSmartStorageUnit(
      smartObjectId,
      entity1,
      smartObjectData,
      worldPosition,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionPerMinute,
      1000000 * 1e18, // fuelMaxCapacity,
      storageCapacity,
      ephemeralStorageCapacity
    );
    smartDeployable.depositFuel(smartObjectId, 100000);
    smartDeployable.bringOnline(smartObjectId);

    InventoryItem[] memory invItems = new InventoryItem[](1);
    invItems[0] = InventoryItem(itemObjectId1, inventoryOwner, 45, 1, 50, 10);

    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    ephInvItems[0] = InventoryItem(itemObjectId2, ephItemOwner, 46, 2, 70, 10);

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, invItems);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephItemOwner, ephInvItems);
  }

  function _createMockItems() internal {
    //Mock Smart Storage Unit data

    smartObject.registerEntity(itemObjectId1, OBJECT);
    world.associateEntityRecord(itemObjectId1);
    smartObject.registerEntity(itemObjectId2, OBJECT);
    world.associateEntityRecord(itemObjectId2);

    entityRecord.createEntityRecord(itemObjectId1, entity2.itemId, entity2.typeId, entity2.volume);
    entityRecord.createEntityRecord(itemObjectId2, entity3.itemId, entity3.typeId, entity3.volume);
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function testSetup() public {
    address epheremalInventoryAddress = Systems.getSystem(DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId());
    ResourceId ephemeralInventorySystemId = SystemRegistry.get(epheremalInventoryAddress);
    assertEq(ephemeralInventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);

    address inventoryAddress = Systems.getSystem(DEPLOYMENT_NAMESPACE.inventorySystemId());
    ResourceId inventorySystemId = SystemRegistry.get(inventoryAddress);
    assertEq(inventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);

    address vendingMachineSystemAddress = Systems.getSystem(VENDING_MACHINE_SYSTEM_ID);
    ResourceId vendingMachineSystemId = SystemRegistry.get(vendingMachineSystemAddress);
    assertEq(vendingMachineSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testInteractHandler() public {
    address inventoryOwner = address(1);
    address ephItemOwner = address(2);
    uint256 quantity = 2;

    InventoryItemTableData memory inventoryItem = InventoryItemTable.get(
      DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      itemObjectId1
    );
    assertEq(inventoryItem.quantity, 10);

    EphemeralInvItemTableData memory ephInvItem = EphemeralInvItemTable.get(
      DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      itemObjectId2,
      ephItemOwner
    );
    assertEq(ephInvItem.quantity, 10);

    world.call(
      VENDING_MACHINE_SYSTEM_ID,
      abi.encodeCall(VendingMachineTestSystem.interactHandler, (smartObjectId, inventoryOwner, quantity))
    );

    inventoryItem = InventoryItemTable.get(DEPLOYMENT_NAMESPACE.inventoryItemTableId(), smartObjectId, itemObjectId1);
    assertEq(inventoryItem.quantity, 8);

    ephInvItem = EphemeralInvItemTable.get(
      DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      itemObjectId2,
      ephItemOwner
    );
    assertEq(ephInvItem.quantity, 8);
  }
}
