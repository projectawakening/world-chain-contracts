// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { DeployableState, DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecord } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { EphemeralInvItemData, EphemeralInvItem } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { DEPLOYMENT_NAMESPACE } from "../../src/namespaces/evefrontier/systems/constants.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { InventoryItem } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { EphemeralInventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/EphemeralInventorySystem.sol";
import { InventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { InventoryInteractSystem } from "../../src/namespaces/evefrontier/systems/inventory/InventoryInteractSystem.sol";
import { TransferItem } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystemLib, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystemLib, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryInteractSystemLib, inventoryInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { VendingMachineMock } from "./VendingMachineMock.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

contract InventoryInteractTest is MudTest {
  IWorldWithContext world;

  uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
  uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
  uint256 storageCapacity = 100000;
  uint256 ephemeralStorageCapacity = 100000;

  // Smart Character variables
  uint256 characterId = 1111;
  uint256 ephCharacterId = 2222;
  uint256 tribeId = 1122;
  EntityRecordData charEntityRecordData = EntityRecordData({ typeId: 2345, itemId: 1234, volume: 0 });
  EntityRecordData ephCharEntityRecordData = EntityRecordData({ typeId: 2345, itemId: 1234, volume: 0 });
  EntityMetadata characterMetadata =
    EntityMetadata({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });

  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));
  address alice = vm.addr(vm.deriveKey(mnemonic, 2));
  address bob = vm.addr(vm.deriveKey(mnemonic, 3));

  function setUp() public override {
    super.setUp();
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);
    vm.startPrank(deployer);

    deployableSystem.globalResume();

    // create SSU Inventory Owner character
    smartCharacterSystem.createCharacter(characterId, alice, tribeId, charEntityRecordData, characterMetadata);
    // create ephemeral Inventory Owner character
    smartCharacterSystem.createCharacter(ephCharacterId, bob, tribeId, charEntityRecordData, characterMetadata);

    registerClass();
    setupDeployable();

    // Inventory variables
    EntityRecord.set(itemObjectId1, itemObjectId1, 1, 50, true);
    EntityRecord.set(itemObjectId2, itemObjectId2, 2, 70, true);

    InventoryItem[] memory invItems = new InventoryItem[](1);
    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    invItems[0] = InventoryItem(itemObjectId1, alice, 45, 1, 50, 10);
    ephInvItems[0] = InventoryItem(itemObjectId2, bob, 46, 2, 70, 10);

    inventorySystem.setInventoryCapacity(smartObjectId, storageCapacity);
    ephemeralInventorySystem.setEphemeralInventoryCapacity(smartObjectId, ephemeralStorageCapacity);
    vm.stopPrank();

    vm.startPrank(alice);
    inventorySystem.depositToInventory(smartObjectId, invItems);
    ephemeralInventorySystem.depositToEphemeralInventory(smartObjectId, bob, ephInvItems);
    vm.stopPrank();
  }

  function setupDeployable() internal {
    uint256 fuelUnitVolume = 1;
    uint256 fuelConsumptionIntervalInSeconds = 1;
    uint256 fuelMaxCapacity = 10000;
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    deployableSystem.registerDeployable(
      smartObjectId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );
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
  }

  function registerClass() internal {
    uint256 inventoryItemClassId = uint256(bytes32("INVENTORY_ITEM"));
    ResourceId[] memory systemIds = new ResourceId[](6);
    systemIds[0] = inventorySystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = ephemeralInventorySystem.toResourceId();
    systemIds[3] = inventoryInteractSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = entityRecordSystem.toResourceId();
    entitySystem.registerClass(inventoryItemClassId, systemIds);
    entitySystem.instantiate(inventoryItemClassId, smartObjectId, alice);
    entitySystem.instantiate(inventoryItemClassId, itemObjectId1, alice);
    entitySystem.instantiate(inventoryItemClassId, itemObjectId2, bob);
  }

  function testEphemeralToInventoryTransfer() public {
    uint256 quantity = 2;

    InventoryItemData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 10);
    InventoryItemData memory storedInventoryItems2 = InventoryItemTable.get(smartObjectId, itemObjectId2);
    assertEq(storedInventoryItems2.quantity, 0);
    EphemeralInvItemData memory storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId2, bob, quantity);

    vm.startPrank(alice);
    inventoryInteractSystem.ephemeralToInventoryTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();

    storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 10);
    storedInventoryItems2 = InventoryItemTable.get(smartObjectId, itemObjectId2);
    assertEq(storedInventoryItems2.quantity, 2);
    storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 8);
  }

  function testRevertEphemeralToInventoryTransfer() public {
    uint256 quantity = 12;

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId2, bob, quantity);

    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryInteractSystem.Inventory_InvalidTransferItemQuantity.selector,
        "InventoryInteractSystem: not enough items to transfer",
        smartObjectId,
        "EPHEMERAL",
        bob,
        itemObjectId2,
        quantity
      )
    );

    vm.startPrank(alice);
    inventoryInteractSystem.ephemeralToInventoryTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();

    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryInteractSystem.Inventory_InvalidTransferItemQuantity.selector,
        "InventoryInteractSystem: not enough items to transfer",
        smartObjectId,
        "EPHEMERAL",
        bob,
        itemObjectId2,
        quantity
      )
    );

    vm.startPrank(alice);
    inventoryInteractSystem.ephemeralToInventoryTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();
  }

  function testInventoryToEphemeralTransfer() public {
    uint256 quantity = 2;

    InventoryItemData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 10);
    EphemeralInvItemData memory storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);
    EphemeralInvItemData memory storedEphInventoryItems1 = EphemeralInvItem.get(smartObjectId, itemObjectId1, bob);
    assertEq(storedEphInventoryItems1.quantity, 0);

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId1, alice, quantity);

    vm.startPrank(alice);
    inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();

    storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 8);
    storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);
    storedEphInventoryItems1 = EphemeralInvItem.get(smartObjectId, itemObjectId1, bob);
    assertEq(storedEphInventoryItems1.quantity, 2);
  }

  function testBobCannotTransferFromInventory() public {
    uint256 quantity = 2;

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId1, bob, quantity);

    vm.startPrank(bob);
    vm.expectRevert(
      abi.encodeWithSelector(AccessSystem.Access_NotOwnerOrCanWithdrawFromInventory.selector, bob, smartObjectId)
    );
    inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();
  }

  function testGrantTransferFromInventoryAccess() public {
    uint256 quantity = 2;

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId1, bob, quantity);

    vm.startPrank(deployer);
    inventoryInteractSystem.setInventoryToEphemeralTransferAccess(smartObjectId, bob, true);
    vm.stopPrank();

    vm.startPrank(bob);
    inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();
  }
}
