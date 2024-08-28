// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { SmartDeployableSystem } from "../../src/systems/smart-deployable/SmartDeployableSystem.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/index.sol";
import { InventoryTable, InventoryTableData, InventoryItemTable, InventoryItemTableData } from "../../src/codegen/index.sol";
import { InventorySystem } from "../../src/systems/inventory/InventorySystem.sol";
import { IInventoryErrors } from "../../src/systems/inventory/IInventoryErrors.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { EntityRecord, EntityRecordData } from "../../src/codegen/index.sol";
import { EntityRecordSystem } from "../../src/systems/entity-record/EntityRecordSystem.sol";

import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { EntityRecordUtils } from "../../src/systems/entity-record/EntityRecordUtils.sol";
import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";

import { State } from "../../src/codegen/common.sol";

contract InventoryTest is MudTest {
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;

  IBaseWorld world;

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    vm.startPrank(deployer);

    EntityRecord.set(4235, 4235, 12, 100, true);
    EntityRecord.set(4236, 4236, 12, 200, true);
    EntityRecord.set(4237, 4237, 12, 150, true);
    EntityRecord.set(8235, 8235, 12, 100, true);
    EntityRecord.set(8236, 8236, 12, 200, true);
    EntityRecord.set(8237, 8237, 12, 150, true);
    EntityRecord.set(5237, 5237, 12, 150, true);
    EntityRecord.set(6237, 6237, 12, 150, true);
    EntityRecord.set(7237, 7237, 12, 150, true);
    EntityRecord.set(5238, 5238, 12, 150, true);
    EntityRecord.set(5239, 5239, 12, 150, true);
    EntityRecord.set(6238, 6238, 12, 150, true);
    EntityRecord.set(6239, 6239, 12, 150, true);
    EntityRecord.set(7238, 7238, 12, 150, true);
    EntityRecord.set(7239, 7239, 12, 150, true);
    EntityRecord.set(9236, 9236, 12, 150, true);
    EntityRecord.set(9237, 9237, 12, 150, true);

    vm.stopPrank();
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testSetDeployableStateToValid(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(systemId, abi.encodeCall(SmartDeployableSystem.globalResume, ()));

    world.call(
      systemId,
      abi.encodeCall(
        SmartDeployableSystem.setDeployableState,
        (
          smartObjectId,
          block.timestamp,
          State.ANCHORED,
          State.ONLINE,
          true,
          block.timestamp,
          block.number,
          block.timestamp
        )
      )
    );

    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);
    assertTrue(deployableStateData.isValid == true);
  }

  function testSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);

    DeployableState.setCurrentState(smartObjectId, State.ONLINE);
    ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
    console.log("inventorySystemId");

    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );

    assertEq(InventoryTable.getCapacity(smartObjectId), storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "Inventory: storage capacity cannot be 0"
      )
    );

    ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );
  }

  function testDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);

    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);
    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

    inventoryTableData = InventoryTable.get(smartObjectId);

    //Check weather the items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryTableData.items[i], items[i].inventoryItemId);
    }

    inventoryTableData = InventoryTable.get(smartObjectId);
    assert(capacityBeforeDeposit < capacityAfterDeposit);
    assertEq(inventoryTableData.items.length, 3);

    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);

    assertEq(inventoryItem1.quantity, items[0].quantity);
    assertEq(inventoryItem2.quantity, items[1].quantity);
    assertEq(inventoryItem3.quantity, items[2].quantity);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 1);
    assertEq(inventoryItem3.index, 2);
  }

  // function testInventoryItemQuantityIncrease(uint256 smartObjectId, uint256 storageCapacity) public {
  //   vm.assume(smartObjectId != 0);
  //   vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

  //   InventoryItem[] memory items = new InventoryItem[](3);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
  //   items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
  //   items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

  //   testSetInventoryCapacity(smartObjectId, storageCapacity);
  //   testSetDeployableStateToValid(smartObjectId);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, items[0].quantity);
  //   assertEq(inventoryItem2.quantity, items[1].quantity);

  //   //check the increase in quantity
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

  //   inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, items[0].quantity * 2);
  //   assertEq(inventoryItem2.quantity, items[1].quantity * 2);

  //   uint256 itemsLength = InventoryTable.getItems(smartObjectId).length;
  //   assertEq(itemsLength, 3);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 1);
  // }

  // function testDepositToExistingInventory(uint256 smartObjectId, uint256 storageCapacity) public {
  //   testDepositToInventory(smartObjectId, storageCapacity);

  //   InventoryItem[] memory items = new InventoryItem[](1);
  //   items[0] = InventoryItem(8235, address(0), 8235, 0, 1, 3);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

  //   uint256 itemsLength = InventoryTable.getItems(smartObjectId).length;
  //   assertEq(itemsLength, 4);

  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   assertEq(inventoryItem1.index, 3);
  // }

  // function testRevertDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
  //   vm.assume(smartObjectId != 0);
  //   vm.assume(storageCapacity >= 1 && storageCapacity <= 500);

  //   testSetInventoryCapacity(smartObjectId, storageCapacity);
  //   InventoryItem[] memory items = new InventoryItem[](1);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 6);
  //   testSetDeployableStateToValid(smartObjectId);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       IInventoryErrors.Inventory_InsufficientCapacity.selector,
  //       "Inventory: insufficient capacity",
  //       storageCapacity,
  //       items[0].volume * items[0].quantity
  //     )
  //   );
  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
  // }

  // function testWithdrawFromInventory(uint256 smartObjectId, uint256 storageCapacity) public {
  //   testDepositToInventory(smartObjectId, storageCapacity);

  //   //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
  //   InventoryItem[] memory items = new InventoryItem[](3);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 1);
  //   items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
  //   items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 1);

  //   InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
  //   uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
  //   uint256 itemVolume = 0;

  //   assertEq(capacityBeforeWithdrawal, 1000);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

  //   for (uint256 i = 0; i < items.length; i++) {
  //     itemVolume += items[i].volume * items[i].quantity;
  //   }

  //   inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
  //   assertEq(inventoryTableData.items.length, 2);

  //   uint256[] memory existingItems = inventoryTableData.items;
  //   assertEq(existingItems.length, 2);
  //   assertEq(existingItems[0], items[0].inventoryItemId);
  //   assertEq(existingItems[1], items[2].inventoryItemId);

  //   //Check weather the items quantity is reduced
  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
  //   assertEq(inventoryItem1.quantity, 2);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 1);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 1);
  // }

  // function testDeposit1andWithdraw1(uint256 smartObjectId, uint256 storageCapacity) public {
  //   vm.assume(smartObjectId != 0);
  //   vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);

  //   //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
  //   InventoryItem[] memory items = new InventoryItem[](1);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);

  //   testSetInventoryCapacity(smartObjectId, storageCapacity);
  //   testSetDeployableStateToValid(smartObjectId);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();

  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

  //   InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.items.length, 0);

  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);

  //   assertEq(inventoryItem1.quantity, 0);
  // }

  // function testWithdrawRemove2Items(uint256 smartObjectId, uint256 storageCapacity) public {
  //   testDepositToInventory(smartObjectId, storageCapacity);

  //   InventoryItem[] memory items = new InventoryItem[](2);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
  //   items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);

  //   InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
  //   uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
  //   uint256 itemVolume = 0;

  //   assertEq(capacityBeforeWithdrawal, 1000);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

  //   for (uint256 i = 0; i < items.length; i++) {
  //     itemVolume += items[i].volume * items[i].quantity;
  //   }

  //   inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
  //   assertEq(inventoryTableData.items.length, 1);

  //   uint256[] memory existingItems = inventoryTableData.items;
  //   assertEq(existingItems.length, 1);

  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, 4237);

  //   assertEq(inventoryItem1.quantity, 0);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 2);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 0);
  // }

  // function testWithdrawRemoveCompletely(uint256 smartObjectId, uint256 storageCapacity) public {
  //   testDepositToInventory(smartObjectId, storageCapacity);

  //   InventoryItem[] memory items = new InventoryItem[](3);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
  //   items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
  //   items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

  //   InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
  //   uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
  //   uint256 itemVolume = 0;

  //   assertEq(capacityBeforeWithdrawal, 1000);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

  //   for (uint256 i = 0; i < items.length; i++) {
  //     itemVolume += items[i].volume * items[i].quantity;
  //   }

  //   inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
  //   assertEq(inventoryTableData.items.length, 0);

  //   uint256[] memory existingItems = inventoryTableData.items;
  //   assertEq(existingItems.length, 0);

  //   //Check weather the items quantity is reduced
  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
  //   assertEq(inventoryItem1.quantity, 0);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 0);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 0);
  // }

  // function testWithdrawWithBigArraySize(uint256 smartObjectId, uint256 storageCapacity) public {
  //   vm.assume(smartObjectId != 0);
  //   vm.assume(storageCapacity >= 11000 && storageCapacity <= 90000);

  //   testSetInventoryCapacity(smartObjectId, storageCapacity);
  //   testSetDeployableStateToValid(smartObjectId);

  //   //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
  //   InventoryItem[] memory items = new InventoryItem[](12);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 10, 300);
  //   items[1] = InventoryItem(4236, address(1), 4236, 0, 20, 2);
  //   items[2] = InventoryItem(4237, address(2), 4237, 0, 10, 2);
  //   items[3] = InventoryItem(8235, address(2), 8235, 0, 10, 2);
  //   items[4] = InventoryItem(8237, address(2), 8237, 0, 10, 2);
  //   items[5] = InventoryItem(5237, address(2), 5237, 0, 10, 2);
  //   items[6] = InventoryItem(6237, address(2), 6237, 0, 10, 2);
  //   items[7] = InventoryItem(7237, address(2), 7237, 0, 10, 2);
  //   items[8] = InventoryItem(5238, address(2), 5238, 0, 10, 2);
  //   items[9] = InventoryItem(5239, address(2), 5239, 0, 10, 2);
  //   items[10] = InventoryItem(6238, address(2), 6238, 0, 10, 2);
  //   items[11] = InventoryItem(6239, address(2), 6239, 0, 10, 2);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, items)));

  //   //Change the order
  //   items = new InventoryItem[](12);
  //   items[0] = InventoryItem(4235, address(0), 4235, 0, 10, 300);
  //   items[1] = InventoryItem(4236, address(1), 4236, 0, 20, 2);
  //   items[2] = InventoryItem(4237, address(2), 4237, 0, 10, 2);
  //   items[3] = InventoryItem(8235, address(2), 8235, 0, 10, 2);
  //   items[4] = InventoryItem(8237, address(2), 8237, 0, 10, 2);
  //   items[5] = InventoryItem(5237, address(2), 5237, 0, 10, 2);
  //   items[6] = InventoryItem(6237, address(2), 6237, 0, 10, 2);
  //   items[7] = InventoryItem(7237, address(2), 7237, 0, 10, 2);
  //   items[8] = InventoryItem(5238, address(2), 5238, 0, 10, 2);
  //   items[9] = InventoryItem(5239, address(2), 5239, 0, 10, 2);
  //   items[10] = InventoryItem(6238, address(2), 6238, 0, 10, 2);
  //   items[11] = InventoryItem(6239, address(2), 6239, 0, 10, 2);

  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

  //   InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.items.length, 0);

  //   // check if everything is 0
  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
  //   InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
  //   assertEq(inventoryItem1.quantity, 0);
  //   assertEq(inventoryItem2.quantity, 0);
  //   assertEq(inventoryItem3.quantity, 0);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);
  //   assertEq(inventoryItem3.index, 0);
  // }

  // function testWithdrawMultipleTimes(uint256 smartObjectId, uint256 storageCapacity) public {
  //   testWithdrawFromInventory(smartObjectId, storageCapacity);

  //   InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.items.length, 2);

  //   InventoryItem[] memory items = new InventoryItem[](1);
  //   items[0] = InventoryItem(4237, address(0), 4237, 0, 200, 1);

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));

  //   uint256 itemId1 = uint256(4235);
  //   uint256 itemId3 = uint256(4237);

  //   InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, itemId1);
  //   InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, itemId3);

  //   assertEq(inventoryItem1.quantity, 2);
  //   assertEq(inventoryItem2.quantity, 0);

  //   assertEq(inventoryItem1.index, 0);
  //   assertEq(inventoryItem2.index, 0);

  //   inventoryTableData = InventoryTable.get(smartObjectId);
  //   assertEq(inventoryTableData.items.length, 1);
  // }

  // function revertWithdrawalForInvalidQuantity(uint256 smartObjectId, uint256 storageCapacity) public {
  //   testDepositToInventory(smartObjectId, storageCapacity);

  //   InventoryItem[] memory items = new InventoryItem[](1);
  //   items[0] = InventoryItem(4237, address(2), 4237, 0, 150, 1);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       IInventoryErrors.Inventory_InvalidQuantity.selector,
  //       "Inventory: invalid quantity",
  //       3,
  //       items[0].quantity
  //     )
  //   );

  //   ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  //   world.call(inventorySystemId, abi.encodeCall(InventorySystem.withdrawFromInventory, (smartObjectId, items)));
  // }

  function testOnlyAdminCanSetInventoryCapacity() public {
    //TODO : Add test case for only admin can set inventory capacity after RBAC
  }

  function testOnlyOwnerCanDepositToInventory() public {
    //TODO : Add test case for only owner can deposit to inventory after RBAC
  }

  function testOnlyOwnerCanWithdrawFromInventory() public {
    //TODO : Add test case for only owner can deposit to inventory after RBAC
  }
}
