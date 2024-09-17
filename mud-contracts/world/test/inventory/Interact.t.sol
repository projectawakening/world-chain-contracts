// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { InventoryItemTableData, InventoryItemTable } from "../../src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";

import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";

import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";

import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";

import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { VendingMachineMock } from "./VendingMachineMock.sol";

contract InteractTest is MudTest {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;

  IWorldWithEntryContext world;
  InventoryLib.World inventory;
  SmartDeployableLib.World smartDeployable;
  SmartStorageUnitLib.World smartStorageUnit;

  VendingMachineMock vendingMachineMock;
  bytes16 constant SYSTEM_NAME = bytes16("VendingMachineMo");
  ResourceId constant VENDING_MACHINE_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

  uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
  uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
  uint256 storageCapacity = 100000;
  uint256 ephemeralStorageCapacity = 100000;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // SSU owner
  address bob = vm.addr(bobPK); // EphInv owner

  function setUp() public override {
    vm.startPrank(deployer);
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    inventory = InventoryLib.World(world, DEPLOYMENT_NAMESPACE);
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartStorageUnit = SmartStorageUnitLib.World(world, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);

    // Vending Machine deploy & registration
    vendingMachineMock = new VendingMachineMock();
    world.registerSystem(VENDING_MACHINE_SYSTEM_ID, vendingMachineMock, true);

    // Register vending machine system's functions
    world.registerFunctionSelector(VENDING_MACHINE_SYSTEM_ID, "interactHandler(uint256, address, uint256)");

    // Resume SD operations for executing SSU configuration
    smartDeployable.globalResume();
    //Mock Smart Storage Unit data
    EntityRecordData memory entity1 = EntityRecordData({ typeId: 1, itemId: 2345, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

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
    invItems[0] = InventoryItem(itemObjectId1, alice, 45, 1, 50, 10);

    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    ephInvItems[0] = InventoryItem(itemObjectId2, bob, 46, 2, 70, 10);

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, invItems);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephInvItems);
    vm.stopPrank();
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
    uint256 quantity = 2;

    InventoryItemTableData memory inventoryItem = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(inventoryItem.quantity, 10);

    EphemeralInvItemTableData memory ephInvItem = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, bob);
    assertEq(ephInvItem.quantity, 10);

    vm.startPrank(bob);

    world.call(
      VENDING_MACHINE_SYSTEM_ID,
      abi.encodeCall(VendingMachineMock.interactHandler, (smartObjectId, bob, quantity))
    );

    inventoryItem = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(inventoryItem.quantity, 8);

    InventoryItemTableData memory inventoryInItem = InventoryItemTable.get(smartObjectId, itemObjectId2);
    assertEq(inventoryInItem.quantity, 2);

    ephInvItem = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, bob);
    assertEq(ephInvItem.quantity, 8);

    EphemeralInvItemTableData memory ephInInvItem = EphemeralInvItemTable.get(smartObjectId, itemObjectId1, bob);
    assertEq(ephInInvItem.quantity, 2);
    vm.stopPrank();
  }
}
