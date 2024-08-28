// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { SmartDeployableSystem } from "../../src/systems/smart-deployable/SmartDeployableSystem.sol";
import { EphemeralInvCapacity } from "../../src/codegen/tables/EphemeralInvCapacity.sol";
import { EphemeralInventorySystem } from "../../src/systems/inventory/EphemeralInventorySystem.sol";
import { EphemeralInv, EphemeralInvData } from "../../src/codegen/tables/EphemeralInv.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../src/codegen/tables/EphemeralInvItem.sol";
import { IInventoryErrors } from "../../src/systems/inventory/IInventoryErrors.sol";
import { InventoryItem } from "../../../src/systems/inventory/types.sol";
import { EntityRecord, EntityRecordData } from "../../src/codegen/index.sol";
import { EntityRecordSystem } from "../../src/systems/entity-record/EntityRecordSystem.sol";

import { State } from "../../src/codegen/common.sol";

import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";
import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { EntityRecordUtils } from "../../src/systems/entity-record/EntityRecordUtils.sol";

contract EphemeralInventoryTest is MudTest {
  IBaseWorld world;
  using SmartDeployableUtils for bytes14;
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;

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

  function testSetEphemeralInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.globalResume, ()));

    world.call(
      deployableSystemId,
      abi.encodeCall(SmartDeployableSystem.setCurrentState, (smartObjectId, State.ONLINE))
    );

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, storageCapacity))
    );

    uint256 capacity = EphemeralInvCapacity.getCapacity(smartObjectId);
    assertTrue(capacity == storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "InventoryEphemeralSystem: storage capacity cannot be 0"
      )
    );

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, storageCapacity))
    );
  }

  function testDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 1500 && storageCapacity <= 10000);

    testSetDeployableStateToValid(smartObjectId);

    // Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    EphemeralInvData memory inventoryTableData = EphemeralInv.get(smartObjectId, owner);
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    inventoryTableData = EphemeralInv.get(smartObjectId, owner);

    // Check if items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryTableData.items[i], items[i].inventoryItemId);
    }

    assert(capacityBeforeDeposit < capacityAfterDeposit);
    assertEq(inventoryTableData.items.length, 3);

    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(smartObjectId, items[0].inventoryItemId, owner);
    EphemeralInvItemData memory inventoryItem2 = EphemeralInvItem.get(smartObjectId, items[1].inventoryItemId, owner);
    EphemeralInvItemData memory inventoryItem3 = EphemeralInvItem.get(smartObjectId, items[2].inventoryItemId, owner);

    assertEq(inventoryItem1.quantity, items[0].quantity);
    assertEq(inventoryItem2.quantity, items[1].quantity);
    assertEq(inventoryItem3.quantity, items[2].quantity);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 1);
    assertEq(inventoryItem3.index, 2);
  }

  function testEphemeralInventoryItemQuantityIncrease(
    uint256 smartObjectId,
    uint256 storageCapacity,
    address owner
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

    testSetDeployableStateToValid(smartObjectId);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemData memory inventoryItem2 = EphemeralInvItem.get(
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemData memory inventoryItem3 = EphemeralInvItem.get(
      smartObjectId,
      items[2].inventoryItemId,
      items[2].owner
    );
    assertEq(inventoryItem1.quantity, items[0].quantity * 2);
    assertEq(inventoryItem2.quantity, items[1].quantity * 2);
    assertEq(inventoryItem3.quantity, items[2].quantity * 2);

    uint256 itemsLength = EphemeralInv.getItems(smartObjectId, owner).length;
    assertEq(itemsLength, 3);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 1);
  }

  function testRevertDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 1 && storageCapacity <= 500);
    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(1), 4235, 0, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InsufficientCapacity.selector,
        "InventoryEphemeralSystem: insufficient capacity",
        storageCapacity,
        items[0].volume * items[0].quantity
      )
    );

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );
  }

  // "InventoryEphemeralSystem: ephemeralInventoryOwner and item owner should be the same"
  function testDepositToExistingEphemeralInventory(
    uint256 smartObjectId,
    uint256 storageCapacity,
    address owner
  ) public {
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);
    vm.assume(owner != address(0));

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(8235, owner, 8235, 0, 1, 3);
    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    uint256 itemsLength = EphemeralInv.getItems(smartObjectId, owner).length;
    assertEq(itemsLength, 4);

    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    assertEq(inventoryItem1.index, 3);

    items = new InventoryItem[](1);
    address differentOwner = address(5);
    items[0] = InventoryItem(8235, differentOwner, 8235, 0, 1, 3);
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    itemsLength = EphemeralInv.getItems(smartObjectId, differentOwner).length;
    assertEq(itemsLength, 1);

    inventoryItem1 = EphemeralInvItem.get(smartObjectId, items[0].inventoryItemId, items[0].owner);
    assertEq(inventoryItem1.index, 0);
  }

  function testWithdrawFromEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(owner != address(0));
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 1);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 1);

    EphemeralInvData memory inventoryTableData = EphemeralInv.get(smartObjectId, owner);

    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );

    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryTableData = EphemeralInv.get(smartObjectId, owner);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);
    assertEq(existingItems[0], items[0].inventoryItemId);
    assertEq(existingItems[1], items[2].inventoryItemId);

    //Check weather the items quantity is reduced
    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemData memory inventoryItem2 = EphemeralInvItem.get(
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemData memory inventoryItem3 = EphemeralInvItem.get(
      smartObjectId,
      items[2].inventoryItemId,
      items[2].owner
    );
    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 1);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem2.index, 0);
    assertEq(inventoryItem3.index, 1);
  }

  function testWithdrawCompletely(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(owner != address(0));
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    EphemeralInvData memory inventoryTableData = EphemeralInv.get(smartObjectId, owner);

    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );

    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryTableData = EphemeralInv.get(smartObjectId, owner);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 0);

    //Check weather the items quantity is reduced
    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemData memory inventoryItem2 = EphemeralInvItem.get(
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemData memory inventoryItem3 = EphemeralInvItem.get(
      smartObjectId,
      items[2].inventoryItemId,
      items[2].owner
    );
    assertEq(inventoryItem1.quantity, 0);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 0);
  }

  function testWithdrawMultipleTimes(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    testWithdrawFromEphemeralInventory(smartObjectId, storageCapacity, owner);

    EphemeralInvData memory inventoryTableData = EphemeralInv.get(smartObjectId, owner);
    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4237, owner, 4237, 0, 200, 1);

    // Try withdraw again
    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );

    uint256 itemId1 = uint256(4235);
    uint256 itemId3 = uint256(4237);

    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(smartObjectId, itemId1, owner);
    EphemeralInvItemData memory inventoryItem3 = EphemeralInvItem.get(smartObjectId, itemId3, owner);

    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem3.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem3.index, 0);

    existingItems = EphemeralInv.getItems(smartObjectId, owner);
    assertEq(existingItems.length, 1);
  }

  function testRevertWithdrawFromEphemeralInventory(
    uint256 smartObjectId,
    uint256 storageCapacity,
    address owner
  ) public {
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(1), 4235, 0, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidQuantity.selector,
        "InventoryEphemeralSystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );
  }

  function testOnlyAdminCanSetEphemeralInventoryCapacity(
    uint256 smartObjectId,
    address owner,
    uint256 storageCapacity
  ) public {
    // TODO: Implement the logic to check if the caller is admin after RBAC implementation
  }

  function testAnyoneCanDepositToInventory() public {
    // TODO : Add test case for only owner can withdraw from inventory after RBAC
  }

  function testOnlyItemOwnerCanWithdrawFromInventory() public {
    // TODO : Add test case for only owner can withdraw from inventory after RBAC
  }
}
