// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { SmartStorageUnitSystem } from "../../src/namespaces/evefrontier/systems/smart-storage-unit/SmartStorageUnitSystem.sol";
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { InventoryUtils } from "../../src/namespaces/evefrontier/systems/inventory/InventoryUtils.sol";
import { InventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { WorldPosition, Coord } from "../../src/namespaces/evefrontier/systems/location/types.sol";
import { InventoryItem } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { InventoryData, Inventory } from "../../src/namespaces/evefrontier/codegen/tables/Inventory.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../src/namespaces/evefrontier/codegen/tables/InventoryItem.sol";
import { DeployableState, DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { EphemeralInventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/EphemeralInventorySystem.sol";
import { EphemeralInv, EphemeralInvData } from "../../src/namespaces/evefrontier/codegen/tables/EphemeralInv.sol";
import { EphemeralInvCapacity } from "../../src/namespaces/evefrontier/codegen/tables/EphemeralInvCapacity.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../src/namespaces/evefrontier/codegen/tables/EphemeralInvItem.sol";
import { LocationData, Location } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { SmartStorageUnitSystemLib, smartStorageUnitSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystemLib, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystemLib, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { CreateAndAnchorDeployableParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { SMART_STORAGE_UNIT } from "../../src/namespaces/evefrontier/systems/constants.sol";

import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

contract SmartStorageUnitTest is MudTest {
  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));
  address alice = vm.addr(vm.deriveKey(mnemonic, 2));
  address bob = vm.addr(vm.deriveKey(mnemonic, 3));

  uint256 smartObjectId = 6666666;
  uint256 characterId = 123;
  uint256 diffCharacterId = 9999;
  uint256 tribeId = 100;
  SmartObjectData smartObjectData;
  WorldPosition worldPosition;
  EntityRecordData entityRecord;
  uint256 fuelMaxCapacity = 1000000000;

  uint256 inventoryItemId = 1233333;
  uint256 diffInventoryItemId = 9999999;
  uint256 ephemeralInventoryItemId = 4566666;
  uint256 diffEphemeralInventoryItemId = 7899999;

  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(deployer);
    deployableSystem.globalResume();

    entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    Coord memory position = Coord({ x: 1, y: 1, z: 1 });
    worldPosition = WorldPosition({ solarSystemId: 1, position: position });

    smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);
    smartCharacterSystem.createCharacter(diffCharacterId, bob, tribeId, entityRecord, entityRecordMetadata);

    uint256 inventoryItemClassId = uint256(bytes32("INVENTORY_ITEM"));
    ResourceId[] memory inventoryTestSystemIds = new ResourceId[](5);
    inventoryTestSystemIds[0] = inventorySystem.toResourceId();
    inventoryTestSystemIds[1] = ephemeralInventorySystem.toResourceId();
    inventoryTestSystemIds[2] = deployableSystem.toResourceId();
    inventoryTestSystemIds[3] = fuelSystem.toResourceId();
    inventoryTestSystemIds[4] = entityRecordSystem.toResourceId();
    entitySystem.registerClass(inventoryItemClassId, inventoryTestSystemIds);
    vm.stopPrank();
  }

  function testcreateAndAnchorSmartStorageUnit(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 0);
    vm.assume(ephemeralStorageCapacity > 0);
    vm.assume(fuelConsumptionIntervalInSeconds > 1);

    vm.startPrank(deployer);
    smartStorageUnitSystem.createAndAnchorSmartStorageUnit(
      CreateAndAnchorDeployableParams({
        smartObjectId: smartObjectId,
        smartAssemblyType: SMART_STORAGE_UNIT,
        entityRecordData: entityRecord,
        smartObjectData: smartObjectData,
        fuelUnitVolume: fuelUnitVolume,
        fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity: fuelMaxCapacity,
        locationData: LocationData({
          solarSystemId: worldPosition.solarSystemId,
          x: worldPosition.position.x,
          y: worldPosition.position.y,
          z: worldPosition.position.z
        })
      }),
      storageCapacity,
      ephemeralStorageCapacity
    );
    vm.stopPrank();
  }

  function testSetDeployableStateToValid() public {
    vm.startPrank(deployer);
    DeployableState.set(
      smartObjectId,
      DeployableStateData({
        createdAt: block.timestamp,
        previousState: State.ANCHORED,
        currentState: State.ONLINE,
        isValid: true,
        anchoredAt: block.timestamp,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
    );
    vm.stopPrank();
  }

  function testCreateAndDepositItemsToInventory(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(fuelConsumptionIntervalInSeconds > 1);
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    testcreateAndAnchorSmartStorageUnit(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    testSetDeployableStateToValid();

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    vm.startPrank(deployer);
    inventorySystem.createAndDepositItemsToInventory(smartObjectId, items);
    vm.stopPrank();

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    uint256 useCapacity = items[0].volume * items[0].quantity;

    assertEq(inventoryData.capacity, storageCapacity);
    assertEq(inventoryData.usedCapacity, useCapacity);

    InventoryItemData memory inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);

    assertEq(inventoryItemData.quantity, items[0].quantity);
    assertEq(inventoryItemData.index, 0);
  }

  function testCreateAndDepositItemsToEphemeralInventory(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 0);
    vm.assume(fuelConsumptionIntervalInSeconds > 1);
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    testcreateAndAnchorSmartStorageUnit(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );
    testSetDeployableStateToValid();

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: ephemeralInventoryItemId,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    vm.startPrank(deployer);
    ephemeralInventorySystem.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, items);
    vm.stopPrank();

    EphemeralInvData memory ephemeralInvData = EphemeralInv.get(smartObjectId, bob);

    uint256 useCapacity = items[0].volume * items[0].quantity;
    assertEq(EphemeralInvCapacity.getCapacity(smartObjectId), ephemeralStorageCapacity);
    assertEq(ephemeralInvData.usedCapacity, useCapacity);

    EphemeralInvItemData memory ephemeralInvItemData = EphemeralInvItem.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );

    assertEq(ephemeralInvItemData.quantity, items[0].quantity);
    assertEq(ephemeralInvItemData.index, 0);
  }

  function testUnanchorAndreAnchor(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 0);
    vm.assume(ephemeralStorageCapacity > 0);
    vm.assume(fuelConsumptionIntervalInSeconds > 1);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: ephemeralInventoryItemId,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    vm.startPrank(deployer);
    ephemeralInventorySystem.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephemeralItems);

    deployableSystem.bringOffline(smartObjectId);
    deployableSystem.unanchor(smartObjectId);
    vm.stopPrank();

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemData memory inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItemData.quantity, items[0].quantity, "inventoryItemData.quantity");
    assertEq(deployableStateData.anchoredAt >= inventoryItemData.stateUpdate, true, "deployableStateData.anchoredAt");

    EphemeralInvItemData memory ephemeralInvItemData = EphemeralInvItem.get(
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemData.quantity, ephemeralItems[0].quantity, "ephemeralInvItemData.quantity");
    assertEq(
      deployableStateData.anchoredAt >= ephemeralInvItemData.stateUpdate,
      true,
      "deployableStateData.anchoredAt"
    );

    vm.warp(block.timestamp + 10);

    testSetDeployableStateToValid();

    items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: diffInventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: diffEphemeralInventoryItemId,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    vm.startPrank(deployer);
    inventorySystem.createAndDepositItemsToInventory(smartObjectId, items);
    ephemeralInventorySystem.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephemeralItems);
    vm.stopPrank();

    deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.ONLINE), "deployableStateData.currentState");
    assertEq(deployableStateData.isValid, true, "deployableStateData.isValid");

    inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItemData.quantity, items[0].quantity, "inventoryItemData.quantity 2");

    ephemeralInvItemData = EphemeralInvItem.get(
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemData.quantity, ephemeralItems[0].quantity, "ephemeralInvItemData.quantity 2");
  }

  function testUnanchorDepositRevert(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(fuelConsumptionIntervalInSeconds > 1);
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: ephemeralInventoryItemId,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testcreateAndAnchorSmartStorageUnit(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );
    testSetDeployableStateToValid();

    vm.startPrank(deployer);
    inventorySystem.createAndDepositItemsToInventory(smartObjectId, items);
    ephemeralInventorySystem.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephemeralItems);

    deployableSystem.bringOffline(smartObjectId);
    deployableSystem.unanchor(smartObjectId);
    vm.stopPrank();

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    vm.warp(block.timestamp + 10);

    vm.startPrank(deployer);
    items[0] = InventoryItem({
      inventoryItemId: diffInventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    inventorySystem.createAndDepositItemsToInventory(smartObjectId, items);

    ephemeralItems[0] = InventoryItem({
      inventoryItemId: diffEphemeralInventoryItemId,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    ephemeralInventorySystem.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephemeralItems);
    vm.stopPrank();
  }

  function testUnanchorWithdrawRevert(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(fuelConsumptionIntervalInSeconds > 1);
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });
    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: ephemeralInventoryItemId,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testcreateAndAnchorSmartStorageUnit(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );
    testSetDeployableStateToValid();

    vm.startPrank(deployer);
    inventorySystem.createAndDepositItemsToInventory(smartObjectId, items);
    ephemeralInventorySystem.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephemeralItems);

    deployableSystem.bringOffline(smartObjectId);
    deployableSystem.unanchor(smartObjectId);
    vm.stopPrank();

    vm.warp(block.timestamp + 10);
    LocationData memory location = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    vm.startPrank(deployer);
    deployableSystem.anchor(smartObjectId, location);
    vm.stopPrank();
    testSetDeployableStateToValid();

    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InvalidItemQuantity.selector,
        "InventorySystem: invalid quantity",
        smartObjectId,
        items[0].quantity
      )
    );

    vm.startPrank(alice);
    inventorySystem.withdrawFromInventory(smartObjectId, items);
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.Ephemeral_Inventory_InvalidItemQuantity.selector,
        "EphemeralInventorySystem: invalid quantity",
        smartObjectId,
        ephemeralItems[0].quantity
      )
    );
    ephemeralInventorySystem.withdrawFromEphemeralInventory(smartObjectId, bob, ephemeralItems);

    vm.stopPrank();
  }

  function testDestroyAndRevertDepositItems(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 0);
    vm.assume(ephemeralStorageCapacity > 0);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: bob,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    vm.startPrank(deployer);
    deployableSystem.bringOffline(smartObjectId);
    deployableSystem.destroyDeployable(smartObjectId);
    vm.stopPrank();
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.DESTROYED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemData memory inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);

    assertEq(inventoryItemData.stateUpdate >= block.timestamp, true);
    assertEq(inventoryItemData.quantity, items[0].quantity);

    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.DESTROYED)
    );
    LocationData memory location = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });
    vm.startPrank(deployer);
    deployableSystem.anchor(smartObjectId, location);
    vm.stopPrank();
  }

  function testDestroyAndRevertWithdrawItems(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 0);
    vm.assume(ephemeralStorageCapacity > 0);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: 12,
      typeId: 3,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    vm.startPrank(deployer);
    deployableSystem.bringOffline(smartObjectId);
    deployableSystem.destroyDeployable(smartObjectId);
    vm.stopPrank();

    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.DESTROYED)
    );
    vm.startPrank(alice);
    inventorySystem.withdrawFromInventory(smartObjectId, items);
    vm.stopPrank();
  }
}
