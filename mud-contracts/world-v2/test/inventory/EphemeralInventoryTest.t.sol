// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EphemeralInvCapacity } from "../../src/codegen/tables/EphemeralInvCapacity.sol";
import { EphemeralInv, EphemeralInvData } from "../../src/codegen/tables/EphemeralInv.sol";
import { State } from "../../src/codegen/common.sol";
import { EntityRecord } from "../../src/codegen/index.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../src/codegen/tables/EphemeralInvItem.sol";
import { IWorld } from "../../src/codegen/world/IWorld.sol";

import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { EphemeralInventorySystem } from "../../src/systems/inventory/EphemeralInventorySystem.sol";
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";

import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";

contract EphemeralInventoryTest is MudTest {
  IBaseWorld world;
  EntityRecordData charEntityRecordData;
  EntityRecordData ephCharEntityRecordData;
  EntityMetadata characterMetadata;
  string tokenCID;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 ownerPK = vm.deriveKey(mnemonic, 2);
  uint256 diffOwnerPK = vm.deriveKey(mnemonic, 3);

  address deployer = vm.addr(deployerPK); // ADMIN
  address owner = vm.addr(ownerPK); // Ephemeral Owner smart character account
  address differentOwner = vm.addr(diffOwnerPK); // another different Ephemeral Owner

  uint256 characterId = 1111;
  uint256 diffCharacterId = 9999;
  uint256 tribeId = 1122;

  ResourceId smartCharacterSystemId = SmartCharacterUtils.smartCharacterSystemId();
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();

  function setUp() public virtual override {
    vm.startPrank(deployer);
    super.setUp();
    world = IBaseWorld(worldAddress);

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
        (characterId, owner, tribeId, charEntityRecordData, characterMetadata)
      )
    );
    world.call(
      smartCharacterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (diffCharacterId, differentOwner, tribeId, charEntityRecordData, characterMetadata)
      )
    );

    //Mock Item creation
    // Note: this only works because deployer currently owns `ENTITY_RECORD` namespace so direct calls to its tables are allowed
    EntityRecord.set(4235, 4235, 12, 100, true);
    EntityRecord.set(4236, 4236, 12, 200, true);
    EntityRecord.set(4237, 4237, 12, 150, true);
    EntityRecord.set(8235, 8235, 12, 100, true);
    EntityRecord.set(8236, 8236, 12, 200, true);
    EntityRecord.set(8237, 8237, 12, 150, true);
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

  function testSetEphemeralInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    vm.startPrank(deployer);
    DeployableState.setCurrentState(smartObjectId, State.ONLINE);
    vm.stopPrank();

    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, storageCapacity))
    );
    assertEq(EphemeralInvCapacity.getCapacity(smartObjectId), storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.Ephemeral_Inventory_InvalidCapacity.selector,
        "EphemeralInventorySystem: storage capacity cannot be 0"
      )
    );
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, storageCapacity))
    );
  }

  function testDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1500 && storageCapacity <= 10000);

    testSetDeployableStateToValid(smartObjectId);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    EphemeralInvData memory inventoryData = EphemeralInv.get(smartObjectId, owner);
    uint256 capacityBeforeDeposit = inventoryData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    inventoryData = EphemeralInv.get(smartObjectId, owner);

    //Check weather the items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryData.items[i], items[i].inventoryItemId);
    }

    inventoryData = EphemeralInv.get(smartObjectId, owner);
    assert(capacityBeforeDeposit < capacityAfterDeposit);

    assertEq(inventoryData.items.length, 3);

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

  function testEphemeralInventoryItemQuantityIncrease(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

    testSetDeployableStateToValid(smartObjectId);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    //check the increase in quantity
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

  function testRevertDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1 && storageCapacity <= 500);
    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(1), 4235, 12, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.Ephemeral_Inventory_InsufficientCapacity.selector,
        "EphemeralInventorySystem: insufficient capacity",
        storageCapacity,
        items[0].volume * items[0].quantity
      )
    );
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    owner = address(9); // set owner as non-character address
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.InvalidEphemeralInventoryOwner.selector,
        "EphemeralInventorySystem: provided ephemeralInventoryOwner is not a valid address",
        address(9)
      )
    );
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );
  }

  function testDepositToExistingEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testDepositToEphemeralInventory(smartObjectId, storageCapacity);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(8235, owner, 8235, 0, 1, 3);
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
    );

    uint256 itemsLength = EphemeralInv.getItems(smartObjectId, owner).length;
    // ALTHOUGH THIS LITLERALLY RETURNS THE VALUE 4 EVERY SINGLE TIME, this assertion fails for me, so I'm commenting out for now
    assertEq(itemsLength, 4);

    EphemeralInvItemData memory inventoryItem1 = EphemeralInvItem.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    assertEq(inventoryItem1.index, 3);

    items = new InventoryItem[](1);

    items[0] = InventoryItem(8235, differentOwner, 8235, 0, 1, 3);
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, differentOwner, items))
    );

    itemsLength = EphemeralInv.getItems(smartObjectId, differentOwner).length;
    assertEq(itemsLength, 1);

    inventoryItem1 = EphemeralInvItem.get(smartObjectId, items[0].inventoryItemId, items[0].owner);
    assertEq(inventoryItem1.index, 0);
  }

  function testWithdrawFromEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testDepositToEphemeralInventory(smartObjectId, storageCapacity);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 1);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 1);

    EphemeralInvData memory inventoryData = EphemeralInv.get(smartObjectId, owner);

    uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryData = EphemeralInv.get(smartObjectId, owner);
    assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryData.items;
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

  function testWithdrawCompletely(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testDepositToEphemeralInventory(smartObjectId, storageCapacity);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    EphemeralInvData memory inventoryData = EphemeralInv.get(smartObjectId, owner);

    uint256 capacityBeforeWithdrawal = inventoryData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryData = EphemeralInv.get(smartObjectId, owner);
    assertEq(inventoryData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryData.items;
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

  function testWithdrawMultipleTimes(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testWithdrawFromEphemeralInventory(smartObjectId, storageCapacity);

    EphemeralInvData memory inventoryData = EphemeralInv.get(smartObjectId, owner);
    uint256[] memory existingItems = inventoryData.items;
    assertEq(existingItems.length, 2);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4237, owner, 4237, 0, 200, 1);

    // Try withdraw again
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

  function testRevertWithdrawFromEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testDepositToEphemeralInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, differentOwner, 4235, 12, 100, 6);
    items[0] = InventoryItem(4235, owner, 4235, 12, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.Ephemeral_Inventory_InvalidItemQuantity.selector,
        "EphemeralInventorySystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );
  }
}
