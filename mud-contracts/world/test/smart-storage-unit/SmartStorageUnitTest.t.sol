// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityRecordTableData, EntityRecordTable } from "../../src/codegen/tables/EntityRecordTable.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { InventoryTable, InventoryTableData } from "../../src/codegen/tables/InventoryTable.sol";
import { InventoryItemTable, InventoryItemTableData } from "../../src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInvTable, EphemeralInvTableData } from "../../src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { EphemeralInvCapacityTable } from "../../src/codegen/tables/EphemeralInvCapacityTable.sol";

import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";

import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { Utils as SmartStorageUnitUtils } from "../../src/modules/smart-storage-unit/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as LocationUtils } from "../../src/modules/location/Utils.sol";
import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";

import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import "../../src/modules/smart-storage-unit/types.sol";

import { EntityTable, EntityTableData } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { EntityMap } from "@eveworld/smart-object-framework/src/codegen/tables/EntityMap.sol";

import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";

contract SmartStorageUnitTest is MudTest {
  using SmartStorageUnitUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryUtils for bytes14;
  using LocationUtils for bytes14;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using InventoryLib for InventoryLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  IERC721 erc721DeployableToken;
  bytes14 constant SMART_DEPLOYABLE_ERC721_NAMESPACE = "erc721deploybl";

  SmartStorageUnitLib.World smartStorageUnit;
  SmartDeployableLib.World smartDeployable;
  InventoryLib.World inventory;

  uint256 ssuClassId = uint256(keccak256("SSUClass"));
  uint256 storageCapacity = 100000;
  uint256 ephemeralStorageCapacity = 100000;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // SSU OWNER
  address bob = vm.addr(bobPK); // EPH INV OWNER

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    inventory = InventoryLib.World(world, INVENTORY_DEPLOYMENT_NAMESPACE);
    smartStorageUnit = SmartStorageUnitLib.World(world, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);

    erc721DeployableToken = IERC721(
      ERC721Registry.get(
        ERC721_REGISTRY_TABLE_ID,
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_ERC721_NAMESPACE)
      )
    );

    smartDeployable.globalResume();
  }

  function testSetup() public {
    address smartStorageUnitSystem = Systems.getSystem(
      SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId()
    );
    ResourceId smartStorageUnitSystemId = SystemRegistry.get(smartStorageUnitSystem);
    assertEq(smartStorageUnitSystemId.getNamespace(), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
  }

  function testCreateAndAnchorSmartStorageUnit(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);

    // set ssu classId in the config
    smartStorageUnit.setSSUClassId(ssuClassId);

    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    smartStorageUnit.createAndAnchorSmartStorageUnit(
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

    State currentState = DeployableState.getCurrentState(smartObjectId);
    assertEq(uint8(currentState), uint8(State.ONLINE));

    EntityRecordTableData memory entityRecordTableData = EntityRecordTable.get(smartObjectId);

    assertEq(entityRecordTableData.typeId, entityRecordData.typeId);
    assertEq(entityRecordTableData.itemId, entityRecordData.itemId);
    assertEq(entityRecordTableData.volume, entityRecordData.volume);

    LocationTableData memory locationTableData = LocationTable.get(smartObjectId);
    assertEq(locationTableData.solarSystemId, worldPosition.solarSystemId);
    assertEq(locationTableData.x, worldPosition.position.x);
    assertEq(locationTableData.y, worldPosition.position.y);
    assertEq(locationTableData.z, worldPosition.position.z);

    assertEq(erc721DeployableToken.ownerOf(smartObjectId), alice);

    smartStorageUnit.setDeployableMetadata(smartObjectId, "testName", "testDappURL", "testdesc");

    EntityRecordOffchainTableData memory entityRecordOffchainTableData = EntityRecordOffchainTable.get(smartObjectId);

    assertEq(entityRecordOffchainTableData.name, "testName");
    assertEq(entityRecordOffchainTableData.dappURL, "testDappURL");
    assertEq(entityRecordOffchainTableData.description, "testdesc");

    // check that the ssu has been registered as an OBJECT entity
    EntityTableData memory entityTableData = EntityTable.get(smartObjectId);
    assertEq(entityTableData.doesExists, true);
    assertEq(entityTableData.entityType, 1);

    // check that the ssu has been tagged for the appropriate classes
    uint256[] memory taggedEntityIds = EntityMap.get(smartObjectId);

    assertEq(taggedEntityIds[0], ssuClassId);
  }

  function testCreateAndDepositItemsToInventory(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    testCreateAndAnchorSmartStorageUnit(smartObjectId);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 useCapacity = items[0].volume * items[0].quantity;

    assertEq(inventoryTableData.capacity, storageCapacity);
    assertEq(inventoryTableData.usedCapacity, useCapacity);

    InventoryItemTableData memory inventoryItemTableData = InventoryItemTable.get(
      smartObjectId,
      items[0].inventoryItemId
    );

    assertEq(inventoryItemTableData.quantity, items[0].quantity);
    assertEq(inventoryItemTableData.index, 0);
  }

  function testCreateAndDepositItemsToEphemeralInventory(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    testCreateAndAnchorSmartStorageUnit(smartObjectId);
    InventoryItem[] memory items = new InventoryItem[](1);
    address ephemeralInventoryOwner = bob;
    items[0] = InventoryItem({ inventoryItemId: 456, owner: bob, itemId: 45, typeId: 6, volume: 10, quantity: 5 });
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);

    EphemeralInvTableData memory ephemeralInvTableData = EphemeralInvTable.get(smartObjectId, ephemeralInventoryOwner);

    uint256 useCapacity = items[0].volume * items[0].quantity;
    assertEq(EphemeralInvCapacityTable.getCapacity(smartObjectId), ephemeralStorageCapacity);
    assertEq(ephemeralInvTableData.usedCapacity, useCapacity);

    EphemeralInvItemTableData memory ephemeralInvItemTableData = EphemeralInvItemTable.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );

    assertEq(ephemeralInvItemTableData.quantity, items[0].quantity);
    assertEq(ephemeralInvItemTableData.index, 0);
  }

  function testUnanchorAndreAnchor(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    address ephemeralInventoryOwner = bob;
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.unanchor(smartObjectId);

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemTableData memory inventoryItemTableData = InventoryItemTable.get(
      smartObjectId,
      items[0].inventoryItemId
    );
    assertEq(inventoryItemTableData.quantity, items[0].quantity);
    assertEq(deployableStateData.anchoredAt >= inventoryItemTableData.stateUpdate, true);

    EphemeralInvItemTableData memory ephemeralInvItemTableData = EphemeralInvItemTable.get(
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemTableData.quantity, ephemeralItems[0].quantity);
    assertEq(deployableStateData.anchoredAt >= ephemeralInvItemTableData.stateUpdate, true);

    vm.warp(block.timestamp + 10);
    // set ssu classId in the config
    smartStorageUnit.setSSUClassId(ssuClassId);

    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    smartStorageUnit.createAndAnchorSmartStorageUnit(
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

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.ONLINE));
    assertEq(deployableStateData.isValid, true);

    inventoryItemTableData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItemTableData.quantity, items[0].quantity);

    ephemeralInvItemTableData = EphemeralInvItemTable.get(
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemTableData.quantity, ephemeralItems[0].quantity);
  }

  function testUnanchorDepositRevert(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    address ephemeralInventoryOwner = bob;
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.unanchor(smartObjectId);

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

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

  function testUnanchorWithdrawRevert(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    address ephemeralInventoryOwner = bob;
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(smartObjectId);
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
        "InventorySystem: invalid quantity",
        smartObjectId,
        items[0].quantity
      )
    );
    inventory.withdrawFromInventory(smartObjectId, items);
    vm.startPrank(bob);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidItemQuantity.selector,
        "EphemeralInventorySystem: invalid quantity",
        smartObjectId,
        ephemeralItems[0].quantity
      )
    );
    inventory.withdrawFromEphemeralInventory(smartObjectId, ephemeralInventoryOwner, ephemeralItems);
    vm.stopPrank();
  }

  function testDestroyAndRevertDepositItems(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: bob, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    testCreateAndDepositItemsToInventory(smartObjectId);

    smartDeployable.bringOffline(smartObjectId);
    smartDeployable.destroyDeployable(smartObjectId);

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.DESTROYED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemTableData memory inventoryItemTableData = InventoryItemTable.get(
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

  function testDestroyAndRevertWithdrawItems(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    testCreateAndDepositItemsToInventory(smartObjectId);

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
