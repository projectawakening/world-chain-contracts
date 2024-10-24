// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { SmartStorageUnitSystem } from "../../src/systems/smart-storage-unit/SmartStorageUnitSystem.sol";
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";
import { SmartStorageUnitUtils } from "../../src/systems/smart-storage-unit/SmartStorageUnitUtils.sol";
import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { InventorySystem } from "../../src/systems/inventory/InventorySystem.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { State, SmartObjectData } from "../../src/systems/deployable/types.sol";
import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { WorldPosition, Coord } from "../../src/systems/smart-storage-unit/types.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { InventoryData, Inventory } from "../../src/codegen/tables/Inventory.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../src/codegen/tables/InventoryItem.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EphemeralInventorySystem } from "../../src/systems/inventory/EphemeralInventorySystem.sol";
import { EphemeralInv, EphemeralInvData } from "../../src/codegen/tables/EphemeralInv.sol";
import { EphemeralInvCapacity } from "../../src/codegen/tables/EphemeralInvCapacity.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../src/codegen/tables/EphemeralInvItem.sol";
import { LocationData, Location } from "../../src/codegen/tables/Location.sol";

contract SmartStorageUnitTest is MudTest {
  IBaseWorld world;
  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 2);
  uint256 bobPK = vm.deriveKey(mnemonic, 3);

  address deployer = vm.addr(deployerPK); // ADMIN
  uint256 characterId = 123;
  uint256 diffCharacterId = 9999;
  address alice = vm.addr(alicePK);
  address bob = vm.addr(bobPK); // Ephemeral Inventory Owner
  uint256 tribeId = 100;
  SmartObjectData smartObjectData;
  WorldPosition worldPosition;
  EntityRecordData entityRecord;
  uint256 fuelMaxCapacity = 1000000000;

  ResourceId smartStorageUnitSystemId = SmartStorageUnitUtils.smartStorageUnitSystemId();
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId characterSystemId = SmartCharacterUtils.smartCharacterSystemId();
  ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  ResourceId ephemeralSystemId = InventoryUtils.ephemeralInventorySystemId();

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));

    entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    Coord memory position = Coord({ x: 1, y: 1, z: 1 });
    worldPosition = WorldPosition({ solarSystemId: 1, position: position });

    world.call(
      characterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, alice, tribeId, entityRecord, entityRecordMetadata)
      )
    );

    world.call(
      characterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (diffCharacterId, bob, tribeId, entityRecord, entityRecordMetadata)
      )
    );
  }

  function testcreateAndAnchorSmartStorageUnit(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));
    vm.assume(storageCapacity > 0);
    vm.assume(ephemeralStorageCapacity > 0);
    vm.assume(fuelConsumptionIntervalInSeconds > 1);

    world.call(
      smartStorageUnitSystemId,
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorSmartStorageUnit,
        (
          smartObjectId,
          smartAssemblyType,
          entityRecord,
          smartObjectData,
          worldPosition,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          storageCapacity,
          ephemeralStorageCapacity
        )
      )
    );
  }

  function testSetDeployableStateToValid(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
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
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    testcreateAndAnchorSmartStorageUnit(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    testSetDeployableStateToValid(smartObjectId);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.createAndDepositItemsToInventory, (smartObjectId, items))
    );

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    uint256 useCapacity = items[0].volume * items[0].quantity;

    assertEq(inventoryData.capacity, storageCapacity);
    assertEq(inventoryData.usedCapacity, useCapacity);

    InventoryItemData memory inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);

    assertEq(inventoryItemData.quantity, items[0].quantity);
    assertEq(inventoryItemData.index, 0);
  }

  function testCreateAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    testcreateAndAnchorSmartStorageUnit(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );
    testSetDeployableStateToValid(smartObjectId);

    InventoryItem[] memory items = new InventoryItem[](1);

    items[0] = InventoryItem({ inventoryItemId: 456, owner: bob, itemId: 45, typeId: 6, volume: 10, quantity: 5 });

    world.call(
      ephemeralSystemId,
      abi.encodeCall(EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory, (smartObjectId, bob, items))
    );

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
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testCreateAndDepositItemsToInventory(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    world.call(
      ephemeralSystemId,
      abi.encodeCall(
        EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory,
        (smartObjectId, bob, ephemeralItems)
      )
    );

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOffline, (smartObjectId)));
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.unanchor, (smartObjectId)));

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    InventoryItemData memory inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItemData.quantity, items[0].quantity);
    assertEq(deployableStateData.anchoredAt >= inventoryItemData.stateUpdate, true);

    EphemeralInvItemData memory ephemeralInvItemData = EphemeralInvItem.get(
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemData.quantity, ephemeralItems[0].quantity);
    assertEq(deployableStateData.anchoredAt >= ephemeralInvItemData.stateUpdate, true);

    vm.warp(block.timestamp + 10);

    testcreateAndAnchorSmartStorageUnit(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    testSetDeployableStateToValid(smartObjectId);
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.createAndDepositItemsToInventory, (smartObjectId, items))
    );

    world.call(
      ephemeralSystemId,
      abi.encodeCall(
        EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory,
        (smartObjectId, bob, ephemeralItems)
      )
    );

    deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.ONLINE));
    assertEq(deployableStateData.isValid, true);

    inventoryItemData = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItemData.quantity, items[0].quantity);

    ephemeralInvItemData = EphemeralInvItem.get(
      smartObjectId,
      ephemeralItems[0].inventoryItemId,
      ephemeralItems[0].owner
    );

    assertEq(ephemeralInvItemData.quantity, ephemeralItems[0].quantity);
  }

  function testUnanchorDepositRevert(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testcreateAndAnchorSmartStorageUnit(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );
    testSetDeployableStateToValid(smartObjectId);
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.createAndDepositItemsToInventory, (smartObjectId, items))
    );

    world.call(
      ephemeralSystemId,
      abi.encodeCall(
        EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory,
        (smartObjectId, bob, ephemeralItems)
      )
    );

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOffline, (smartObjectId)));
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.unanchor, (smartObjectId)));

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(uint8(deployableStateData.currentState), uint8(State.UNANCHORED));
    assertEq(deployableStateData.isValid, false);

    vm.warp(block.timestamp + 10);

    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );

    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.createAndDepositItemsToInventory, (smartObjectId, items))
    );
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );

    world.call(
      ephemeralSystemId,
      abi.encodeCall(
        EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory,
        (smartObjectId, bob, ephemeralItems)
      )
    );
  }

  function testUnanchorWithdrawRevert(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity > 500);
    vm.assume(ephemeralStorageCapacity > 1000);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    InventoryItem[] memory ephemeralItems = new InventoryItem[](1);
    ephemeralItems[0] = InventoryItem({
      inventoryItemId: 456,
      owner: bob,
      itemId: 45,
      typeId: 6,
      volume: 10,
      quantity: 5
    });

    testcreateAndAnchorSmartStorageUnit(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );
    testSetDeployableStateToValid(smartObjectId);
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.createAndDepositItemsToInventory, (smartObjectId, items))
    );

    world.call(
      ephemeralSystemId,
      abi.encodeCall(
        EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory,
        (smartObjectId, bob, ephemeralItems)
      )
    );

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOffline, (smartObjectId)));
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.unanchor, (smartObjectId)));

    vm.warp(block.timestamp + 10);
    LocationData memory location = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.anchor, (smartObjectId, location)));
    testSetDeployableStateToValid(smartObjectId);

    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InvalidItemQuantity.selector,
        "InventorySystem: invalid quantity",
        smartObjectId,
        items[0].quantity
      )
    );

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));
    vm.startPrank(bob);
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.Ephemeral_Inventory_InvalidItemQuantity.selector,
        "EphemeralInventorySystem: invalid quantity",
        smartObjectId,
        ephemeralItems[0].quantity
      )
    );
    world.call(
      ephemeralSystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, bob, ephemeralItems))
    );

    vm.stopPrank();
  }

  function testDestroyAndRevertDepositItems(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(smartObjectId != 0);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: bob, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    testCreateAndDepositItemsToInventory(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOffline, (smartObjectId)));
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.destroyDeployable, (smartObjectId)));
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

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.anchor, (smartObjectId, location)));
  }

  function testDestroyAndRevertWithdrawItems(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(smartObjectId != 0);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: alice, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    testCreateAndDepositItemsToInventory(
      smartObjectId,
      smartAssemblyType,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      storageCapacity,
      ephemeralStorageCapacity
    );

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOffline, (smartObjectId)));
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.destroyDeployable, (smartObjectId)));

    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.DESTROYED)
    );

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));
  }
}
