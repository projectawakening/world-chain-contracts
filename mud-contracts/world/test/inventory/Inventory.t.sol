// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EntityRecordTable } from "../../src/codegen/tables/EntityRecordTable.sol";
import { InventoryTable, InventoryTableData } from "../../src/codegen/tables/InventoryTable.sol";
import { InventoryItemTable, InventoryItemTableData } from "../../src/codegen/tables/InventoryItemTable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { InventorySystem } from "../../src/modules/inventory/systems/InventorySystem.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";

import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";

contract InventoryTest is MudTest {
  using Utils for bytes14;
  using InventoryLib for InventoryLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;

  IWorldWithEntryContext world;
  InventoryLib.World inventory;
  SmartDeployableLib.World smartDeployable;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);

  address deployer = vm.addr(deployerPK); // ADMIN

  function setUp() public override {
    vm.startPrank(deployer);
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    smartDeployable = SmartDeployableLib.World(world, DEPLOYMENT_NAMESPACE);
    inventory = InventoryLib.World(world, DEPLOYMENT_NAMESPACE);

    smartDeployable.globalResume();

    //Mock Item creation
    EntityRecordTable.set(4235, 4235, 12, 100, true);
    EntityRecordTable.set(4236, 4236, 12, 200, true);
    EntityRecordTable.set(4237, 4237, 12, 150, true);
    EntityRecordTable.set(8235, 8235, 12, 100, true);
    EntityRecordTable.set(8236, 8236, 12, 200, true);
    EntityRecordTable.set(8237, 8237, 12, 150, true);
    EntityRecordTable.set(5237, 5237, 12, 150, true);
    EntityRecordTable.set(6237, 6237, 12, 150, true);
    EntityRecordTable.set(7237, 7237, 12, 150, true);
    EntityRecordTable.set(5238, 5238, 12, 150, true);
    EntityRecordTable.set(5239, 5239, 12, 150, true);
    EntityRecordTable.set(6238, 6238, 12, 150, true);
    EntityRecordTable.set(6239, 6239, 12, 150, true);
    EntityRecordTable.set(7238, 7238, 12, 150, true);
    EntityRecordTable.set(7239, 7239, 12, 150, true);
    EntityRecordTable.set(9236, 9236, 12, 150, true);
    EntityRecordTable.set(9237, 9237, 12, 150, true);
    vm.stopPrank();
  }

  function testSetup() public {
    address InventorySystemAddress = Systems.getSystem(DEPLOYMENT_NAMESPACE.inventorySystemId());
    ResourceId inventorySystemId = SystemRegistry.get(InventorySystemAddress);
    assertEq(inventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
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
    vm.startPrank(deployer);
    DeployableState.setCurrentState(smartObjectId, State.ONLINE);
    vm.stopPrank();
    inventory.setInventoryCapacity(smartObjectId, storageCapacity);
    assertEq(InventoryTable.getCapacity(smartObjectId), storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    storageCapacity = 0;
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "InventorySystem: storage capacity cannot be 0"
      )
    );
    inventory.setInventoryCapacity(smartObjectId, storageCapacity);
  }

  function testDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);
    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    inventory.depositToInventory(smartObjectId, items);
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

  function testInventoryItemQuantityIncrease(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);
    inventory.depositToInventory(smartObjectId, items);

    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

    assertEq(inventoryItem1.quantity, items[0].quantity);
    assertEq(inventoryItem2.quantity, items[1].quantity);

    //check the increase in quantity
    inventory.depositToInventory(smartObjectId, items);
    inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);

    assertEq(inventoryItem1.quantity, items[0].quantity * 2);
    assertEq(inventoryItem2.quantity, items[1].quantity * 2);

    uint256 itemsLength = InventoryTable.getItems(smartObjectId).length;
    assertEq(itemsLength, 3);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 1);
  }

  function testDepositToExistingInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(8235, address(0), 8235, 0, 1, 3);
    inventory.depositToInventory(smartObjectId, items);

    uint256 itemsLength = InventoryTable.getItems(smartObjectId).length;
    assertEq(itemsLength, 4);

    inventory.depositToInventory(smartObjectId, items);
    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    assertEq(inventoryItem1.index, 3);
  }

  function testRevertDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1 && storageCapacity <= 500);
    testSetInventoryCapacity(smartObjectId, storageCapacity);
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 6);
    testSetDeployableStateToValid(smartObjectId);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InsufficientCapacity.selector,
        "InventorySystem: insufficient capacity",
        storageCapacity,
        items[0].volume * items[0].quantity
      )
    );
    inventory.depositToInventory(smartObjectId, items);
  }

  function testWithdrawFromInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 1);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 1);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 itemVolume = 0;

    assertEq(capacityBeforeWithdrawal, 1000);

    inventory.withdrawFromInventory(smartObjectId, items);
    for (uint256 i = 0; i < items.length; i++) {
      itemVolume += items[i].volume * items[i].quantity;
    }

    inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
    assertEq(inventoryTableData.items.length, 2);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);
    assertEq(existingItems[0], items[0].inventoryItemId);
    assertEq(existingItems[1], items[2].inventoryItemId);

    //Check weather the items quantity is reduced
    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 1);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 1);
  }

  function testDeposit1andWithdraw1(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);
    inventory.depositToInventory(smartObjectId, items);

    inventory.withdrawFromInventory(smartObjectId, items);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.items.length, 0);

    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);

    assertEq(inventoryItem1.quantity, 0);
  }

  function testWithdrawRemove2Items(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](2);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 itemVolume = 0;

    assertEq(capacityBeforeWithdrawal, 1000);

    inventory.withdrawFromInventory(smartObjectId, items);
    for (uint256 i = 0; i < items.length; i++) {
      itemVolume += items[i].volume * items[i].quantity;
    }

    inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
    assertEq(inventoryTableData.items.length, 1);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 1);

    //Check weather the items quantity is reduced
    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, 4237);
    assertEq(inventoryItem1.quantity, 0);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 2);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 0);
  }

  function testWithdrawRemoveCompletely(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 itemVolume = 0;

    assertEq(capacityBeforeWithdrawal, 1000);

    inventory.withdrawFromInventory(smartObjectId, items);
    for (uint256 i = 0; i < items.length; i++) {
      itemVolume += items[i].volume * items[i].quantity;
    }

    inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - itemVolume);
    assertEq(inventoryTableData.items.length, 0);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 0);

    //Check weather the items quantity is reduced
    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
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

    testSetInventoryCapacity(smartObjectId, storageCapacity);
    testSetDeployableStateToValid(smartObjectId);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](12);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 10, 300);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 20, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 10, 2);
    items[3] = InventoryItem(8235, address(2), 8235, 0, 10, 2);
    items[4] = InventoryItem(8237, address(2), 8237, 0, 10, 2);
    items[5] = InventoryItem(5237, address(2), 5237, 0, 10, 2);
    items[6] = InventoryItem(6237, address(2), 6237, 0, 10, 2);
    items[7] = InventoryItem(7237, address(2), 7237, 0, 10, 2);
    items[8] = InventoryItem(5238, address(2), 5238, 0, 10, 2);
    items[9] = InventoryItem(5239, address(2), 5239, 0, 10, 2);
    items[10] = InventoryItem(6238, address(2), 6238, 0, 10, 2);
    items[11] = InventoryItem(6239, address(2), 6239, 0, 10, 2);

    inventory.depositToInventory(smartObjectId, items);

    //Change the order
    items = new InventoryItem[](12);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 10, 300);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 20, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 10, 2);
    items[3] = InventoryItem(8235, address(2), 8235, 0, 10, 2);
    items[4] = InventoryItem(8237, address(2), 8237, 0, 10, 2);
    items[5] = InventoryItem(5237, address(2), 5237, 0, 10, 2);
    items[6] = InventoryItem(6237, address(2), 6237, 0, 10, 2);
    items[7] = InventoryItem(7237, address(2), 7237, 0, 10, 2);
    items[8] = InventoryItem(5238, address(2), 5238, 0, 10, 2);
    items[9] = InventoryItem(5239, address(2), 5239, 0, 10, 2);
    items[10] = InventoryItem(6238, address(2), 6238, 0, 10, 2);
    items[11] = InventoryItem(6239, address(2), 6239, 0, 10, 2);
    inventory.withdrawFromInventory(smartObjectId, items);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.items.length, 0);

    //check if everything is 0
    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, items[1].inventoryItemId);
    InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
    assertEq(inventoryItem1.quantity, 0);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 0);
  }

  function testWithdrawMultipleTimes(uint256 smartObjectId, uint256 storageCapacity) public {
    testWithdrawFromInventory(smartObjectId, storageCapacity);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.items.length, 2);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4237, address(0), 4237, 0, 200, 1);

    // Try withdraw again
    inventory.withdrawFromInventory(smartObjectId, items);

    uint256 itemId1 = uint256(4235);
    uint256 itemId3 = uint256(4237);

    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, itemId1);
    InventoryItemTableData memory inventoryItem2 = InventoryItemTable.get(smartObjectId, itemId3);

    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem2.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);

    inventoryTableData = InventoryTable.get(smartObjectId);
    assertEq(inventoryTableData.items.length, 1);
  }

  function revertWithdrawalForInvalidQuantity(uint256 smartObjectId, uint256 storageCapacity) public {
    testDepositToInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4237, address(2), 4237, 0, 150, 1);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidQuantity.selector,
        "InventorySystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    inventory.withdrawFromInventory(smartObjectId, items);
  }
}
