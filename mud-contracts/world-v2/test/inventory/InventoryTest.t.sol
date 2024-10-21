// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { State } from "../../src/codegen/common.sol";
import { Inventory, InventoryData } from "../../src/codegen/tables/Inventory.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../src/codegen/tables/InventoryItem.sol";

import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { FuelUtils } from "../../src/systems/fuel/FuelUtils.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { InventorySystem } from "../../src/systems/inventory/InventorySystem.sol";
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";
import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { EntityRecord } from "../../src/codegen/index.sol";
import { IWorld } from "../../src/codegen/world/IWorld.sol";

contract InventoryTest is MudTest {
  IBaseWorld world;

  // Inventory variables
  InventoryItem item1;
  InventoryItem item2;
  InventoryItem item3;
  InventoryItem item4;
  InventoryItem item5;
  InventoryItem item6;
  InventoryItem item7;
  InventoryItem item8;
  InventoryItem item9;
  InventoryItem item10;
  InventoryItem item11;
  InventoryItem item12;
  InventoryItem item13;

  
  uint256 characterId;
  uint256 ephCharacterId;
  uint256 tribeId;
  EntityRecordData charEntityRecordData;
  EntityRecordData ephCharEntityRecordData;
  EntityMetadata characterMetadata;
  string tokenCID;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // Inventory Owner
  address bob = vm.addr(bobPK); // Ephemeral Inventory Owner

  ResourceId smartCharacterSystemId = SmartCharacterUtils.smartCharacterSystemId();
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId inventorySystemId = InventoryUtils.inventorySystemId();

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);
    vm.startPrank(deployer);

    characterId = 1111;
    ephCharacterId = 1111;
    tribeId = 1122;
    charEntityRecordData = EntityRecordData({ typeId: 2345, itemId: 1234, volume: 0 });
    ephCharEntityRecordData = EntityRecordData({ typeId: 2345, itemId: 1234, volume: 0 });
    characterMetadata = EntityMetadata({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });
    tokenCID = "Qm1234abcdxxxx";

    //   create SSU Inventory Owner character
    world.call(
      smartCharacterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, alice, tribeId, charEntityRecordData, characterMetadata)
      )
    );

    item1 = InventoryItem(4235, alice, 4235, 12, 100, 1);
    item2 = InventoryItem(4236, alice, 4236, 12, 200, 1);
    item3 = InventoryItem(4237, alice, 4237, 12, 150, 1);
    item4 = InventoryItem(8235, alice, 8235, 12, 100, 1);
    item5 = InventoryItem(8236, alice, 8236, 12, 200, 1);
    item6 = InventoryItem(8237, alice, 8237, 12, 150, 1);
    item7 = InventoryItem(5237, alice, 5237, 12, 150, 1);
    item8 = InventoryItem(6237, alice, 6237, 12, 150, 1);
    item9 = InventoryItem(7237, alice, 7237, 12, 150, 1);
    item10 = InventoryItem(5238, alice, 5238, 12, 150, 1);
    item11 = InventoryItem(5239, alice, 5239, 12, 150, 1);
    item12 = InventoryItem(6238, alice, 6238, 12, 150, 1);
    item13 = InventoryItem(6239, bob, 6239, 12, 150, 1);

    //Mock Item creation
    EntityRecord.set(item1.inventoryItemId, item1.itemId, item1.typeId, item1.volume, true);
    EntityRecord.set(item2.inventoryItemId, item2.itemId, item2.typeId, item2.volume, true);
    EntityRecord.set(item3.inventoryItemId, item3.itemId, item3.typeId, item3.volume, true);
    EntityRecord.set(item4.inventoryItemId, item4.itemId, item4.typeId, item4.volume, true);
    EntityRecord.set(item5.inventoryItemId, item5.itemId, item5.typeId, item5.volume, true);
    EntityRecord.set(item6.inventoryItemId, item6.itemId, item6.typeId, item6.volume, true);
    EntityRecord.set(item7.inventoryItemId, item7.itemId, item7.typeId, item7.volume, true);
    EntityRecord.set(item8.inventoryItemId, item8.itemId, item8.typeId, item8.volume, true);
    EntityRecord.set(item9.inventoryItemId, item9.itemId, item9.typeId, item9.volume, true);
    EntityRecord.set(item10.inventoryItemId, item10.itemId, item10.typeId, item10.volume, true);
    EntityRecord.set(item11.inventoryItemId, item11.itemId, item11.typeId, item11.volume, true);
    EntityRecord.set(item12.inventoryItemId, item12.itemId, item12.typeId, item12.volume, true);
    EntityRecord.set(item13.inventoryItemId, item13.itemId, item13.typeId, item13.volume, true);

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));

    vm.stopPrank();
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

  function testSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );

    assertEq(Inventory.getCapacity(smartObjectId), storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    storageCapacity = 0;
    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InvalidCapacity.selector,
        "InventorySystem: storage capacity cannot be 0"
      )
    );
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );
  }

  function testDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1500 && storageCapacity <= 10000);

    InventoryItem[] memory items = new InventoryItem[](3);
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

    testSetDeployableStateToValid(smartObjectId);
    testSetInventoryCapacity(smartObjectId, storageCapacity);

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    uint256 capacityBeforeDeposit = inventoryData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
    inventoryData = Inventory.get(smartObjectId);

    //Check whether the items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryData.items[i], items[i].inventoryItemId);
    }

    inventoryData = Inventory.get(smartObjectId);
    assert(capacityBeforeDeposit < capacityAfterDeposit);
    assertEq(inventoryData.items.length, 3);

    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

    InventoryItemData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);

    assertEq(inventoryItem1.quantity, items[0].quantity);
    assertEq(inventoryItem2.quantity, items[1].quantity);
    assertEq(inventoryItem3.quantity, items[2].quantity);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 1);
    assertEq(inventoryItem3.index, 2);
  }

  function testInventoryItemQuantityIncrease(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

    InventoryItem[] memory items = new InventoryItem[](3);
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

    assertEq(inventoryItem1.quantity, items[0].quantity);
    assertEq(inventoryItem2.quantity, items[1].quantity);

    //check the increase in quantity
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
    inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

    assertEq(inventoryItem1.quantity, items[0].quantity * 2);
    assertEq(inventoryItem2.quantity, items[1].quantity * 2);

    uint256 itemsLength = Inventory.getItems(smartObjectId).length;
    assertEq(itemsLength, 3);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 1);
  }

  function testDepositToExistingInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(storageCapacity >= 1200 && storageCapacity <= 10000);
    testDepositToInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = item4;
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

    uint256 itemsLength = Inventory.getItems(smartObjectId).length;
    assertEq(itemsLength, 4);

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItem1.index, 3);
  }

  function testRevertDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 150 && storageCapacity <= 500);

    // create SSU smart object with token
    testSetDeployableStateToValid(smartObjectId);
    testSetInventoryCapacity(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    item1.inventoryItemId = 20;
    items[0] = item1;

    // invalid item revert
    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InvalidItem.selector,
        "InventorySystem: item is not created on-chain",
        item1.inventoryItemId
      )
    );
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

    item2.quantity = 60;
    items[0] = item2;
    // capacity revert
    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InsufficientCapacity.selector,
        "InventorySystem: insufficient capacity",
        storageCapacity,
        items[0].volume * items[0].quantity
      )
    );
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
  }

  function testWithdrawFromInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](3);
    item1.quantity = 1;
    item2.quantity = 2;
    item3.quantity = 1;
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
    uint256 itemVolume = 0;

    assertEq(capacityBeforeWithdrawal, 1000);

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

    for (uint256 i = 0; i < items.length; i++) {
      itemVolume += items[i].volume * items[i].quantity;
    }

    inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
    assertEq(inventoryData.items.length, 2);

    assertEq(inventoryData.items[0], items[0].inventoryItemId);
    assertEq(inventoryData.items[1], items[2].inventoryItemId);

    //Check whether the items quantity is reduced
    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem3.quantity, 1);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem3.index, 1);
  }

  function testDeposit1andWithdraw1(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);

    InventoryItem[] memory items = new InventoryItem[](1);
    item1.quantity = 3;
    items[0] = item1;

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.items.length, 0);

    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);

    assertEq(inventoryItem1.quantity, 0);
  }

  function testWithdrawRemove2Items(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](2);
    item1.quantity = 3;
    item2.quantity = 2;
    items[0] = item1;
    items[1] = item2;

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
    uint256 itemVolume = 0;

    assertEq(capacityBeforeWithdrawal, 1000);

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));
    for (uint256 i = 0; i < items.length; i++) {
      itemVolume += items[i].volume * items[i].quantity;
    }

    inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
    assertEq(inventoryData.items.length, 1);

    uint256[] memory existingItems = inventoryData.items;
    assertEq(existingItems.length, 1);

    //Check weather the items quantity is reduced
    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, 4237);
    assertEq(inventoryItem1.quantity, 0);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 2);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 0);
  }

  function testWithdrawRemoveCompletely(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
    uint256 itemVolume = 0;

    assertEq(capacityBeforeWithdrawal, 1000);

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));
    for (uint256 i = 0; i < items.length; i++) {
      itemVolume += items[i].volume * items[i].quantity;
    }

    inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
    assertEq(inventoryData.items.length, 0);

    uint256[] memory existingItems = inventoryData.items;
    assertEq(existingItems.length, 0);

    //Check weather the items quantity is reduced
    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
    assertEq(inventoryItem1.quantity, 0);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 0);
  }

  function testWithdrawWithBigArraySize(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 11000 && storageCapacity <= 90000);

    testSetDeployableStateToValid(smartObjectId);
    testSetInventoryCapacity(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](12);
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    item4.quantity = 2;
    item5.quantity = 2;
    item6.quantity = 2;
    item7.quantity = 2;
    item8.quantity = 2;
    item9.quantity = 2;
    item10.quantity = 2;
    item11.quantity = 2;
    item12.quantity = 2;

    items[0] = item1;
    items[1] = item2;
    items[2] = item3;
    items[3] = item4;
    items[4] = item5;
    items[5] = item6;
    items[6] = item7;
    items[7] = item8;
    items[8] = item9;
    items[9] = item10;
    items[10] = item11;
    items[11] = item12;

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

    //Change the order
    items = new InventoryItem[](12);
    items[0] = item10;
    items[1] = item7;
    items[2] = item3;
    items[3] = item12;
    items[4] = item5;
    items[5] = item8;
    items[6] = item2;
    items[7] = item6;
    items[8] = item11;
    items[9] = item1;
    items[10] = item9;
    items[11] = item4;
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.items.length, 0);

    //check if everything is 0
    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
    assertEq(inventoryItem1.quantity, 0);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 0);
  }

  function testWithdrawMultipleTimes(uint256 smartObjectId, uint256 storageCapacity) public {
    testWithdrawFromInventory(smartObjectId, storageCapacity);

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.items.length, 2);

    InventoryItem[] memory items = new InventoryItem[](1);
    item3.quantity = 1;
    items[0] = item3;

    // Try withdraw again
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

    uint256 itemId1 = uint256(4235);
    uint256 itemId3 = uint256(4237);

    InventoryItemData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, itemId1);
    InventoryItemData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, itemId3);

    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem2.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);

    inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.items.length, 1);
  }

  function revertWithdrawalForInvalidQuantity(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    item3.quantity = 1;

    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InvalidItemQuantity.selector,
        "InventorySystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));
  }
}
