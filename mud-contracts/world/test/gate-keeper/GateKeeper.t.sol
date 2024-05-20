// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";

import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import "@eveworld/common-constants/src/constants.sol";

import { ModulesInitializationLibrary } from "../../src/utils/ModulesInitializationLibrary.sol";
import { SOFInitializationLibrary } from "../../src/utils/SOFInitializationLibrary.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { HookType } from "@eveworld/smart-object-framework/src/types.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityRecordTableData, EntityRecordTable } from "../../src/codegen/tables/EntityRecordTable.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { InventoryTable, InventoryTableData } from "../../src/codegen/tables/InventoryTable.sol";
import { InventoryItemTable, InventoryItemTableData } from "../../src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInvTable, EphemeralInvTableData } from "../../src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { EntityTable } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { EphemeralInvCapacityTable } from "../../src/codegen/tables/EphemeralInvCapacityTable.sol";

import { SmartStorageUnitModule } from "../../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { ERC721Module } from "../../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { GateKeeperModule } from "../../src/modules/gate-keeper/GateKeeperModule.sol";
import { GateKeeperLib } from "../../src/modules/gate-keeper/GateKeeperLib.sol";
import { IGateKeeper } from "../../src/modules/gate-keeper/interfaces/IGateKeeper.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { Inventory } from "../../src/modules/inventory/systems/Inventory.sol";
import { IInventory } from "../../src/modules/inventory/interfaces/IInventory.sol";
import { EphemeralInventory } from "../../src/modules/inventory/systems/EphemeralInventory.sol";
import { InventoryInteract } from "../../src/modules/inventory/systems/InventoryInteract.sol";
import { IInventoryInteract } from "../../src/modules/inventory/interfaces/IInventoryInteract.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { Utils as CoreUtils } from "@eveworld/smart-object-framework/src/utils.sol";
import { Utils as SmartStorageUnitUtils } from "../../src/modules/smart-storage-unit/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as LocationUtils } from "../../src/modules/location/Utils.sol";
import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { Utils as GateKeeperUtils } from "../../src/modules/gate-keeper/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";

import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import "../../src/modules/smart-storage-unit/types.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import "../../src/utils/ModulesInitializationLibrary.sol";

contract GateKeeperUnitTest is Test {
  using CoreUtils for bytes14;
  using SmartStorageUnitUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryUtils for bytes14;
  using LocationUtils for bytes14;
  using GateKeeperUtils for bytes14;
  using ModulesInitializationLibrary for IBaseWorld;
  using SOFInitializationLibrary for IBaseWorld;
  using SmartObjectLib for SmartObjectLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using GateKeeperLib for GateKeeperLib.World;
  using InventoryLib for InventoryLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  SmartObjectLib.World smartObject;
  IERC721Mintable erc721DeployableToken;
  SmartStorageUnitLib.World smartStorageUnit;
  GateKeeperLib.World gateKeeper;
  SmartDeployableLib.World smartDeployable;
  InventoryLib.World inventory;

  uint256 storageCapacity = 100000;
  uint256 ephemeralStorageCapacity = 100000;

  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";

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
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721DeployableToken));

    // Inventory module installation
    InventoryModule inventoryModule = new InventoryModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE),
        address(inventoryModule)
      );

    world.installModule(
      inventoryModule,
      abi.encode(INVENTORY_DEPLOYMENT_NAMESPACE, new Inventory(), new EphemeralInventory(), new InventoryInteract())
    );
    world.initInventory();
    inventory = InventoryLib.World(world, INVENTORY_DEPLOYMENT_NAMESPACE);

    // SmartStorageUnitModule installation
    _installModule(new SmartStorageUnitModule(), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
    world.initSSU();
    smartStorageUnit = SmartStorageUnitLib.World(world, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);

    // GateKeeperModule installation
    _installModule(new GateKeeperModule(), GATE_KEEPER_DEPLOYMENT_NAMESPACE);
    world.initGateKeeper();
    gateKeeper = GateKeeperLib.World(world, GATE_KEEPER_DEPLOYMENT_NAMESPACE);

    smartObject.registerEntity(SSU_CLASS_ID, CLASS);
    world.associateClassIdToSSU(SSU_CLASS_ID);

    smartObject.registerEntity(GATE_KEEPER_CLASS_ID, CLASS);
    world.associateClassIdToGateKeeper(GATE_KEEPER_CLASS_ID);

    smartObject.registerEntity(SMART_DEPLOYABLE_CLASS_ID, CLASS);
    world.associateClassIdToSmartDeployable(SMART_DEPLOYABLE_CLASS_ID);
    smartDeployable.globalResume();

    smartObject.registerEntity(123, OBJECT);
    world.associateEntityRecord(123);
    smartObject.registerEntity(456, OBJECT);
    world.associateEntityRecord(456);

    ResourceId gateKeeperSystemId = GATE_KEEPER_DEPLOYMENT_NAMESPACE.gateKeeperSystemId();
    ResourceId inventoryInteractSystemId = INVENTORY_DEPLOYMENT_NAMESPACE.inventoryInteractSystemId();
    ResourceId inventorySystemId = INVENTORY_DEPLOYMENT_NAMESPACE.inventorySystemId();

    _registerClassLevelHookGateKeeper();
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
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

  function testSetup() public {
    address smartStorageUnitSystem = Systems.getSystem(
      SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId()
    );
    ResourceId smartStorageUnitSystemId = SystemRegistry.get(smartStorageUnitSystem);
    assertEq(smartStorageUnitSystemId.getNamespace(), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
  }

  function testCreateAndAnchorGateKeeper(uint256 smartObjectId) public {
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: address(1), tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });
    vm.assume(
      smartObjectId != 0 &&
        !EntityTable.getDoesExists(SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityTableTableId(), smartObjectId)
    );

    gateKeeper.createAndAnchorGateKeeper(
      smartObjectId,
      entityRecordData,
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

    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );
    assertEq(uint8(currentState), uint8(State.ONLINE));

    EntityRecordTableData memory entityRecordTableData = EntityRecordTable.get(
      ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      smartObjectId
    );

    assertEq(entityRecordTableData.typeId, entityRecordData.typeId);
    assertEq(entityRecordTableData.itemId, entityRecordData.itemId);
    assertEq(entityRecordTableData.volume, entityRecordData.volume);

    LocationTableData memory locationTableData = LocationTable.get(
      LOCATION_DEPLOYMENT_NAMESPACE.locationTableId(),
      smartObjectId
    );
    assertEq(locationTableData.solarSystemId, worldPosition.solarSystemId);
    assertEq(locationTableData.x, worldPosition.position.x);
    assertEq(locationTableData.y, worldPosition.position.y);
    assertEq(locationTableData.z, worldPosition.position.z);

    assertEq(erc721DeployableToken.ownerOf(smartObjectId), address(1));

    smartStorageUnit.setDeploybaleMetadata(smartObjectId, "testName", "testDappURL", "testdesc");

    EntityRecordOffchainTableData memory entityRecordOffchainTableData = EntityRecordOffchainTable.get(
      ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordOffchainTableId(),
      smartObjectId
    );

    assertEq(entityRecordOffchainTableData.name, "testName");
    assertEq(entityRecordOffchainTableData.dappURL, "testDappURL");
    assertEq(entityRecordOffchainTableData.description, "testdesc");
  }

  function testCreateAndDepositItemsToInventoryRevertWrongItemType(uint256 smartObjectId, uint256 entityTypeId) public {
    testCreateAndAnchorGateKeeper(smartObjectId);
    vm.assume(entityTypeId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(2),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });
    gateKeeper.setAcceptedItemTypeId(smartObjectId, 0);
    gateKeeper.setTargetQuantity(smartObjectId, 1000000);
    vm.expectRevert();
    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);
  }

  function testCreateAndDepositItemsToInventoryRevertTooMuchDeposited(
    uint256 smartObjectId,
    uint256 entityTypeId,
    uint256 quantity
  ) public {
    testCreateAndAnchorGateKeeper(smartObjectId);
    vm.assume(quantity < type(uint256).max);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(2),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: quantity + 1
    });
    gateKeeper.setAcceptedItemTypeId(smartObjectId, entityTypeId);
    gateKeeper.setTargetQuantity(smartObjectId, quantity);
    vm.expectRevert();
    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);
  }

  function testCreateAndDepositItemsToInventory(uint256 smartObjectId, uint256 entityTypeId) public {
    testCreateAndAnchorGateKeeper(smartObjectId);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(2),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });
    gateKeeper.setAcceptedItemTypeId(smartObjectId, entityTypeId);
    gateKeeper.setTargetQuantity(smartObjectId, 1000000);
    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);

    InventoryTableData memory inventoryTableData = InventoryTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryTableId(),
      smartObjectId
    );
    uint256 useCapacity = items[0].volume * items[0].quantity;

    assertEq(inventoryTableData.capacity, storageCapacity);
    assertEq(inventoryTableData.usedCapacity, useCapacity);

    InventoryItemTableData memory inventoryItemTableData = InventoryItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId
    );

    assertEq(inventoryItemTableData.quantity, items[0].quantity);
    assertEq(inventoryItemTableData.index, 0);
  }

  function testCreateAndDepositItemsToEphemeralInventory(uint256 smartObjectId) public {
    testCreateAndAnchorGateKeeper(smartObjectId);
    InventoryItem[] memory items = new InventoryItem[](1);
    address ephemeralInventoryOwner = address(1);
    items[0] = InventoryItem({
      inventoryItemId: 456,
      owner: address(1),
      itemId: 45,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);

    EphemeralInvTableData memory ephemeralInvTableData = EphemeralInvTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvTableId(),
      smartObjectId,
      ephemeralInventoryOwner
    );

    uint256 useCapacity = items[0].volume * items[0].quantity;
    assertEq(
      EphemeralInvCapacityTable.getCapacity(
        INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvCapacityTableId(),
        smartObjectId
      ),
      ephemeralStorageCapacity
    );
    assertEq(ephemeralInvTableData.usedCapacity, useCapacity);

    EphemeralInvItemTableData memory ephemeralInvItemTableData = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );

    assertEq(ephemeralInvItemTableData.quantity, items[0].quantity);
    assertEq(ephemeralInvItemTableData.index, 0);
  }

  function testUnanchorAndreAnchor(uint256 smartObjectId, uint256 entityTypeId) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(1),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    address ephemeralInventoryOwner = address(2);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: address(2),
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId, entityTypeId);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.unanchor(smartObjectId);

    DeployableStateData memory deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemTableData memory inventoryItemTableData = InventoryItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId
    );
    assertEq(inventoryItemTableData.quantity, items[0].quantity);
    assertEq(deployableStateData.anchoredAt >= inventoryItemTableData.stateUpdate, true);

    EphemeralInvItemTableData memory ephemeralInvItemTableData = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemTableData.quantity, ephemeralItems[0].quantity);
    assertEq(deployableStateData.anchoredAt >= ephemeralInvItemTableData.stateUpdate, true);

    vm.warp(block.timestamp + 10);
    LocationTableData memory location = LocationTableData({ solarSystemId: 1, x: 1, y: 1, z: 1 });
    smartDeployable.anchor(smartObjectId, location);
    smartDeployable.bringOnline(smartObjectId);

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    assertEq(uint8(deployableStateData.currentState), uint8(State.ONLINE));
    assertEq(deployableStateData.isValid, true);

    inventoryItemTableData = InventoryItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId
    );
    assertEq(inventoryItemTableData.quantity, items[0].quantity);

    ephemeralInvItemTableData = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemTableData.quantity, ephemeralItems[0].quantity);
  }

  function testUnanchorDepositRevert(uint256 smartObjectId, uint256 entityTypeId) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(1),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    address ephemeralInventoryOwner = address(2);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: address(2),
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId, entityTypeId);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.unanchor(smartObjectId);

    DeployableStateData memory deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    vm.warp(block.timestamp + 10);

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartDeployableErrors.SmartDeployable_IncorrectState.selector,
        smartObjectId,
        State.UNANCHORED
      )
    );

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);
    vm.expectRevert(
      abi.encodeWithSelector(
        SmartDeployableErrors.SmartDeployable_IncorrectState.selector,
        smartObjectId,
        State.UNANCHORED
      )
    );
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);
  }

  function testUnanchorWithdrawRevert(uint256 smartObjectId, uint256 entityTypeId) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(1),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    address ephemeralInventoryOwner = address(2);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: address(2),
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId, entityTypeId);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.unanchor(smartObjectId);
    vm.warp(block.timestamp + 10);
    LocationTableData memory location = LocationTableData({ solarSystemId: 1, x: 1, y: 1, z: 1 });
    smartDeployable.anchor(smartObjectId, location);
    smartDeployable.bringOnline(smartObjectId);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidItemQuantity.selector,
        "Inventory: invalid quantity",
        smartObjectId,
        items[0].quantity
      )
    );

    inventory.withdrawFromInventory(smartObjectId, items);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidItemQuantity.selector,
        "Inventory: invalid quantity",
        smartObjectId,
        ephemeralItems[0].quantity
      )
    );
    inventory.withdrawFromEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);
  }

  function testDestroyAndRevertDepositItems(uint256 smartObjectId, uint256 entityTypeId) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(2),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId, entityTypeId);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.destroyDeployable(smartObjectId);

    DeployableStateData memory deployableStateData = DeployableState.get(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    assertEq(uint8(deployableStateData.currentState), uint8(State.DESTROYED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemTableData memory inventoryItemTableData = InventoryItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId
    );

    assertEq(inventoryItemTableData.stateUpdate >= block.timestamp, true);
    assertEq(inventoryItemTableData.quantity, items[0].quantity);

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartDeployableErrors.SmartDeployable_IncorrectState.selector,
        smartObjectId,
        State.DESTROYED
      )
    );
    LocationTableData memory location = LocationTableData({ solarSystemId: 1, x: 1, y: 1, z: 1 });
    smartDeployable.anchor(smartObjectId, location);
  }

  function testDestroyAndRevertWithdrawItems(uint256 smartObjectId, uint256 entityTypeId) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: 123,
      owner: address(2),
      itemId: 12,
      typeId: entityTypeId,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId, entityTypeId);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.destroyDeployable(smartObjectId);

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartDeployableErrors.SmartDeployable_IncorrectState.selector,
        smartObjectId,
        State.DESTROYED
      )
    );

    inventory.withdrawFromInventory(smartObjectId, items);
  }
}
