// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { DeployableState, DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { State } from "../../src/codegen/common.sol";
import { Inventory, InventoryData } from "../../src/namespaces/evefrontier/codegen/tables/Inventory.sol";
import { InventoryItemData, InventoryItem } from "../../src/namespaces/evefrontier/codegen/tables/InventoryItem.sol";

import { EntityRecordParams, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { InventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { EntityRecord } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystemLib, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EveTest } from "../EveTest.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

contract InventoryTest is EveTest {
  // // Inventory variables
  // InventoryItemParams item1;
  // InventoryItemParams item2;
  // InventoryItemParams item3;
  // InventoryItemParams item4;
  // InventoryItemParams item5;
  // InventoryItemParams item6;
  // InventoryItemParams item7;
  // InventoryItemParams item8;
  // InventoryItemParams item9;
  // InventoryItemParams item10;
  // InventoryItemParams item11;
  // InventoryItemParams item12;
  // InventoryItemParams item13;

  // uint256 smartObjectId;
  // uint256 characterId;
  // uint256 ephCharacterId;
  // uint256 tribeId;
  // EntityRecordParams charEntityRecordData;
  // EntityRecordParams ephCharEntityRecordData;
  // EntityMetadata characterMetadata;
  // string tokenCID;

  // function setUp() public virtual override {
  //   super.setUp();
  //   vm.startPrank(deployer);

  //   smartObjectId = 1234;
  //   characterId = 1111;
  //   ephCharacterId = 1111;
  //   tribeId = 1122;
  //   charEntityRecordData = EntityRecordParams({ typeId: 2345, itemId: 1234, volume: 0 });
  //   ephCharEntityRecordData = EntityRecordParams({ typeId: 2345, itemId: 1234, volume: 0 });
  //   characterMetadata = EntityMetadata({
  //     name: "Albus Demunster",
  //     dappURL: "https://www.my-tribe-website.com",
  //     description: "The top hunter-seeker in the Frontier."
  //   });
  //   tokenCID = "Qm1234abcdxxxx";

  //   // create SSU Inventory Owner character
  //   smartCharacterSystem.createCharacter(characterId, alice, tribeId, charEntityRecordData, characterMetadata);

  //   item1 = InventoryItemParams({ inventoryItemId: 4235, owner: alice, itemId: 4235, volume: 100, quantity: 1 });
  //   item2 = InventoryItemParams({ inventoryItemId: 4236, owner: alice, itemId: 4236, volume: 200, quantity: 1 });
  //   item3 = InventoryItemParams({ inventoryItemId: 4237, owner: alice, itemId: 4237, volume: 150, quantity: 1 });
  //   item4 = InventoryItemParams({ inventoryItemId: 8235, owner: alice, itemId: 8235, volume: 100, quantity: 1 });
  //   item5 = InventoryItemParams({ inventoryItemId: 8236, owner: alice, itemId: 8236, volume: 200, quantity: 1 });
  //   item6 = InventoryItemParams({ inventoryItemId: 8237, owner: alice, itemId: 8237, volume: 150, quantity: 1 });
  //   item7 = InventoryItemParams({ inventoryItemId: 5237, owner: alice, itemId: 5237, volume: 150, quantity: 1 });
  //   item8 = InventoryItemParams({ inventoryItemId: 6237, owner: alice, itemId: 6237, volume: 150, quantity: 1 });
  //   item9 = InventoryItemParams({ inventoryItemId: 7237, owner: alice, itemId: 7237, volume: 150, quantity: 1 });
  //   item10 = InventoryItemParams({ inventoryItemId: 5238, owner: alice, itemId: 5238, volume: 150, quantity: 1 });
  //   item11 = InventoryItemParams({ inventoryItemId: 5239, owner: alice, itemId: 5239, volume: 150, quantity: 1 });
  //   item12 = InventoryItemParams({ inventoryItemId: 6238, owner: alice, itemId: 6238, volume: 150, quantity: 1 });
  //   item13 = InventoryItemParams({ inventoryItemId: 6239, owner: bob, itemId: 6239, volume: 150, quantity: 1 });

  //   uint256 inventoryItemClassId = uint256(bytes32("INVENTORY_ITEM"));

  //   //Mock Item creation

  //   EntityRecord.set(item1.inventoryItemId, item1.itemId, item1.typeId, item1.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item1.inventoryItemId, alice);
  //   EntityRecord.set(item2.inventoryItemId, item2.itemId, item2.typeId, item2.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item2.inventoryItemId, alice);
  //   EntityRecord.set(item3.inventoryItemId, item3.itemId, item3.typeId, item3.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item3.inventoryItemId, alice);
  //   EntityRecord.set(item4.inventoryItemId, item4.itemId, item4.typeId, item4.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item4.inventoryItemId, alice);
  //   EntityRecord.set(item5.inventoryItemId, item5.itemId, item5.typeId, item5.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item5.inventoryItemId, alice);
  //   EntityRecord.set(item6.inventoryItemId, item6.itemId, item6.typeId, item6.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item6.inventoryItemId, alice);
  //   EntityRecord.set(item7.inventoryItemId, item7.itemId, item7.typeId, item7.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item7.inventoryItemId, alice);
  //   EntityRecord.set(item8.inventoryItemId, item8.itemId, item8.typeId, item8.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item8.inventoryItemId, alice);
  //   EntityRecord.set(item9.inventoryItemId, item9.itemId, item9.typeId, item9.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item9.inventoryItemId, alice);
  //   EntityRecord.set(item10.inventoryItemId, item10.itemId, item10.typeId, item10.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item10.inventoryItemId, alice);
  //   EntityRecord.set(item11.inventoryItemId, item11.itemId, item11.typeId, item11.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item11.inventoryItemId, alice);
  //   EntityRecord.set(item12.inventoryItemId, item12.itemId, item12.typeId, item12.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item12.inventoryItemId, alice);
  //   EntityRecord.set(item13.inventoryItemId, item13.itemId, item13.typeId, item13.volume, true);
  //   entitySystem.instantiate(inventoryItemClassId, item13.inventoryItemId, bob);

  //   uint256 inventoryTestClassId = uint256(bytes32("INVENTORY_TEST"));
  //   ResourceId[] memory inventoryTestSystemIds = new ResourceId[](3);
  //   inventoryTestSystemIds[0] = inventorySystem.toResourceId();
  //   inventoryTestSystemIds[1] = deployableSystem.toResourceId();
  //   inventoryTestSystemIds[2] = fuelSystem.toResourceId();
  //   entitySystem.registerClass(inventoryTestClassId, inventoryTestSystemIds);

  //   entitySystem.instantiate(inventoryTestClassId, smartObjectId, alice);

  //   uint256 fuelUnitVolume = 1;
  //   uint256 fuelConsumptionIntervalInSeconds = 1;
  //   uint256 fuelMaxCapacity = 10000;

  //   deployableSystem.globalResume();

  //   deployableSystem.registerDeployable(
  //     smartObjectId,
  //     alice,
  //     fuelUnitVolume,
  //     fuelConsumptionIntervalInSeconds,
  //     fuelMaxCapacity
  //   );
  //   DeployableState.set(
  //     smartObjectId,
  //     DeployableStateData({
  //       createdAt: block.timestamp,
  //       previousState: State.ANCHORED,
  //       currentState: State.ONLINE,
  //       isValid: true,
  //       anchoredAt: block.timestamp,
  //       updatedBlockNumber: block.number,
  //       updatedBlockTime: block.timestamp
  //     })
  //   );

  //   vm.stopPrank();
  // }

  // function testSetInventoryCapacity(uint256 storageCapacity) public {
  //   vm.assume(storageCapacity != 0);

  //   vm.startPrank(deployer);
  //   inventorySystem.setInventoryCapacity(smartObjectId, storageCapacity);
  //   vm.stopPrank();

  //   assertEq(Inventory.getCapacity(smartObjectId), storageCapacity);
  // }

  // function testRevertSetInventoryCapacity(uint256 storageCapacity) public {
  //   storageCapacity = 0;
  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       InventorySystem.Inventory_InvalidCapacity.selector,
  //       "InventorySystem: storage capacity cannot be 0"
  //     )
  //   );
  //   vm.startPrank(deployer);
  //   inventorySystem.setInventoryCapacity(smartObjectId, storageCapacity);
  //   vm.stopPrank();
  // }

  // function testDepositToInventory(uint256 storageCapacity) public {
  //   vm.assume(smartObjectId != 0);
  //   vm.assume(storageCapacity >= 1500 && storageCapacity <= 10000);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](3);
  //   item1.quantity = 3;
  //   item2.quantity = 2;
  //   item3.quantity = 2;
  //   items[0] = item1;
  //   items[1] = item2;
  //   items[2] = item3;

  //   testSetInventoryCapacity(storageCapacity);

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   uint256 capacityBeforeDeposit = inventoryData.usedCapacity;
  //   uint256 capacityAfterDeposit = 0;

  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();
  //   inventoryData = Inventory.get(smartObjectId);

  //   //Check whether the items are stored in the inventory table
  //   for (uint256 i = 0; i < items.length; i++) {
  //     uint256 itemVolume = items[i].volume * items[i].quantity;
  //     capacityAfterDeposit += itemVolume;
  //     assertEq(inventoryData.items[i], items[i].inventoryItemId);
  //   }

  //   inventoryData = Inventory.get(smartObjectId);
  //   assert(capacityBeforeDeposit < capacityAfterDeposit);
  //   assertEq(inventoryData.items.length, 3);

  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemData memory inventoryItem2 = InventoryItem.get(smartObjectId, items[1].inventoryItemId);

  //   InventoryItemData memory inventoryItem3 = InventoryItem.get(smartObjectId, items[2].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, items[0].quantity);
  //   assertEq(inventoryItem2.quantity, items[1].quantity);
  //   assertEq(inventoryItem3.quantity, items[2].quantity);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 1);
  //   assertEq(inventoryItem3.index, 2);
  // }

  // function testInventoryItemQuantityIncrease(uint256 storageCapacity) public {
  //   vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](3);
  //   item1.quantity = 3;
  //   item2.quantity = 2;
  //   item3.quantity = 2;
  //   items[0] = item1;
  //   items[1] = item2;
  //   items[2] = item3;

  //   testSetInventoryCapacity(storageCapacity);

  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemData memory inventoryItem2 = InventoryItem.get(smartObjectId, items[1].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, items[0].quantity);
  //   assertEq(inventoryItem2.quantity, items[1].quantity);

  //   //check the increase in quantity
  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   inventoryItem2 = InventoryItem.get(smartObjectId, items[1].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, items[0].quantity * 2);
  //   assertEq(inventoryItem2.quantity, items[1].quantity * 2);

  //   uint256 itemsLength = Inventory.getItems(smartObjectId).length;
  //   assertEq(itemsLength, 3);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 1);
  // }

  // function testDepositToExistingInventory(uint256 storageCapacity) public {
  //   vm.assume(storageCapacity >= 1200 && storageCapacity <= 10000);
  //   testDepositToInventory(storageCapacity);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](1);
  //   items[0] = item4;
  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   uint256 itemsLength = Inventory.getItems(smartObjectId).length;
  //   assertEq(itemsLength, 4);

  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();
  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   assertEq(inventoryItem1.index, 3);
  // }

  // function testRevertDepositToInventory(uint256 storageCapacity) public {
  //   vm.assume(storageCapacity >= 150 && storageCapacity <= 500);

  //   // create SSU smart object with token
  //   testSetInventoryCapacity(storageCapacity);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](1);
  //   item1.inventoryItemId = 20;
  //   items[0] = item1;

  //   // invalid item revert
  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       InventorySystem.Inventory_InvalidItem.selector,
  //       "InventorySystem: item is not created on-chain",
  //       item1.inventoryItemId
  //     )
  //   );
  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   item2.quantity = 60;
  //   items[0] = item2;
  //   // capacity revert
  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       InventorySystem.Inventory_InsufficientCapacity.selector,
  //       "InventorySystem: insufficient capacity",
  //       storageCapacity,
  //       items[0].volume * items[0].quantity
  //     )
  //   );
  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();
  // }

  // function testWithdrawFromInventory(uint256 storageCapacity) public {
  //   testDepositToInventory(storageCapacity);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](3);
  //   item1.quantity = 1;
  //   item2.quantity = 2;
  //   item3.quantity = 1;
  //   items[0] = item1;
  //   items[1] = item2;
  //   items[2] = item3;

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
  //   uint256 itemVolume = 0;

  //   assertEq(capacityBeforeWithdrawal, 1000);

  //   vm.startPrank(alice);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   for (uint256 i = 0; i < items.length; i++) {
  //     itemVolume += items[i].volume * items[i].quantity;
  //   }

  //   inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
  //   assertEq(inventoryData.items.length, 2);

  //   assertEq(inventoryData.items[0], items[0].inventoryItemId);
  //   assertEq(inventoryData.items[1], items[2].inventoryItemId);

  //   //Check whether the items quantity is reduced
  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemData memory inventoryItem3 = InventoryItem.get(smartObjectId, items[2].inventoryItemId);
  //   assertEq(inventoryItem1.quantity, 2);
  //   assertEq(inventoryItem3.quantity, 1);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem3.index, 1);
  // }

  // function testDeposit1andWithdraw1(uint256 storageCapacity) public {
  //   vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](1);
  //   item1.quantity = 3;
  //   items[0] = item1;

  //   testSetInventoryCapacity(storageCapacity);

  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.items.length, 0);

  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, 0);
  // }

  // function testWithdrawRemove2Items(uint256 storageCapacity) public {
  //   testDepositToInventory(storageCapacity);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](2);
  //   item1.quantity = 3;
  //   item2.quantity = 2;
  //   items[0] = item1;
  //   items[1] = item2;

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
  //   uint256 itemVolume = 0;

  //   assertEq(capacityBeforeWithdrawal, 1000);

  //   vm.startPrank(alice);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   for (uint256 i = 0; i < items.length; i++) {
  //     itemVolume += items[i].volume * items[i].quantity;
  //   }

  //   inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
  //   assertEq(inventoryData.items.length, 1);

  //   uint256[] memory existingItems = inventoryData.items;
  //   assertEq(existingItems.length, 1);

  //   //Check weather the items quantity is reduced
  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemData memory inventoryItem2 = InventoryItem.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemData memory inventoryItem3 = InventoryItem.get(smartObjectId, 4237);
  //   assertEq(inventoryItem1.quantity, 0);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 2);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 0);
  // }

  // function testWithdrawRemoveCompletely(uint256 storageCapacity) public {
  //   testDepositToInventory(storageCapacity);

  //   item1.quantity = 3;
  //   item2.quantity = 2;
  //   item3.quantity = 2;
  //   InventoryItemParams[] memory items = new InventoryItemParams[](3);
  //   items[0] = item1;
  //   items[1] = item2;
  //   items[2] = item3;

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
  //   uint256 itemVolume = 0;

  //   assertEq(capacityBeforeWithdrawal, 1000);

  //   vm.startPrank(alice);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   for (uint256 i = 0; i < items.length; i++) {
  //     itemVolume += items[i].volume * items[i].quantity;
  //   }

  //   inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
  //   assertEq(inventoryData.items.length, 0);

  //   uint256[] memory existingItems = inventoryData.items;
  //   assertEq(existingItems.length, 0);

  //   //Check weather the items quantity is reduced
  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemData memory inventoryItem2 = InventoryItem.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemData memory inventoryItem3 = InventoryItem.get(smartObjectId, items[2].inventoryItemId);
  //   assertEq(inventoryItem1.quantity, 0);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 0);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 0);
  // }

  // function testWithdrawWithBigArraySize(uint256 storageCapacity) public {
  //   vm.assume(storageCapacity >= 11000 && storageCapacity <= 90000);

  //   testSetInventoryCapacity(storageCapacity);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](12);
  //   item1.quantity = 3;
  //   item2.quantity = 2;
  //   item3.quantity = 2;
  //   item4.quantity = 2;
  //   item5.quantity = 2;
  //   item6.quantity = 2;
  //   item7.quantity = 2;
  //   item8.quantity = 2;
  //   item9.quantity = 2;
  //   item10.quantity = 2;
  //   item11.quantity = 2;
  //   item12.quantity = 2;

  //   items[0] = item1;
  //   items[1] = item2;
  //   items[2] = item3;
  //   items[3] = item4;
  //   items[4] = item5;
  //   items[5] = item6;
  //   items[6] = item7;
  //   items[7] = item8;
  //   items[8] = item9;
  //   items[9] = item10;
  //   items[10] = item11;
  //   items[11] = item12;

  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   //Change the order
  //   items = new InventoryItemParams[](12);
  //   items[0] = item10;
  //   items[1] = item7;
  //   items[2] = item3;
  //   items[3] = item12;
  //   items[4] = item5;
  //   items[5] = item8;
  //   items[6] = item2;
  //   items[7] = item6;
  //   items[8] = item11;
  //   items[9] = item1;
  //   items[10] = item9;
  //   items[11] = item4;

  //   vm.startPrank(alice);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.items.length, 0);

  //   //check if everything is 0
  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemData memory inventoryItem2 = InventoryItem.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemData memory inventoryItem3 = InventoryItem.get(smartObjectId, items[2].inventoryItemId);
  //   assertEq(inventoryItem1.quantity, 0);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 0);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 0);
  // }

  // function testWithdrawMultipleTimes(uint256 storageCapacity) public {
  //   testWithdrawFromInventory(storageCapacity);

  //   InventoryData memory inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.items.length, 2);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](1);
  //   item3.quantity = 1;
  //   items[0] = item3;

  //   // Try withdraw again
  //   vm.startPrank(alice);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();

  //   uint256 itemId1 = uint256(4235);
  //   uint256 itemId3 = uint256(4237);

  //   InventoryItemData memory inventoryItem1 = InventoryItem.get(smartObjectId, itemId1);
  //   InventoryItemData memory inventoryItem2 = InventoryItem.get(smartObjectId, itemId3);

  //   assertEq(inventoryItem1.quantity, 2);
  //   assertEq(inventoryItem2.quantity, 0);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);

  //   inventoryData = Inventory.get(smartObjectId);
  //   assertEq(inventoryData.items.length, 1);
  // }

  // function revertWithdrawalForInvalidQuantity(uint256 storageCapacity) public {
  //   testDepositToInventory(storageCapacity);

  //   InventoryItemParams[] memory items = new InventoryItemParams[](1);
  //   item3.quantity = 1;

  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       InventorySystem.Inventory_InvalidItemQuantity.selector,
  //       "InventorySystem: invalid quantity",
  //       3,
  //       items[0].quantity
  //     )
  //   );
  //   vm.startPrank(alice);
  //   inventorySystem.withdrawFromInventory(smartObjectId, items);
  //   vm.stopPrank();
  // }
}
