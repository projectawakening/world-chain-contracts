// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { console } from "forge-std/console.sol";
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
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { InventoryTable, InventoryTableData } from "../../src/codegen/tables/InventoryTable.sol";
import { InventoryItemTable, InventoryItemTableData } from "../../src/codegen/tables/InventoryItemTable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { IERC721Errors } from "../../src/modules/eve-erc721-puppet/IERC721Errors.sol";

import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { InventorySystem } from "../../src/modules/inventory/systems/InventorySystem.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { EntityRecordData as CharEntityRecordData } from "../../src/modules/smart-character/types.sol";
import { EntityRecordData } from "../../src/modules/smart-storage-unit/types.sol";

import { SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";

contract InventoryTest is MudTest {
  using Utils for bytes14;
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using InventoryLib for InventoryLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;

  IWorldWithEntryContext world;
  SmartDeployableLib.World smartDeployable;
  SmartStorageUnitLib.World smartStorageUnit;
  InventoryLib.World inventory;
  SmartCharacterLib.World smartCharacter;

  EntityRecordData entityRecordData;
  SmartObjectData smartObjectData;
  WorldPosition worldPosition;

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

  // Smart Character variables
  uint256 characterId;
  uint256 ephCharacterId;
  uint256 tribeId;
  CharEntityRecordData charEntityRecordData;
  CharEntityRecordData ephCharEntityRecordData;
  EntityRecordOffchainTableData charOffchainData;
  string tokenCID;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // Inventory Owner
  address bob = vm.addr(bobPK); // Ephemeral Inventory Owner

  function setUp() public override {
    vm.startPrank(deployer);
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // deployable interface setting and set deployables to active
    smartDeployable = SmartDeployableLib.World(world, DEPLOYMENT_NAMESPACE);
    smartDeployable.globalResume();

    // SSU interface & variable setting
    smartStorageUnit = SmartStorageUnitLib.World(world, DEPLOYMENT_NAMESPACE);
    entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    // SmartCharacter interface & variable setting
    smartCharacter = SmartCharacterLib.World(world, DEPLOYMENT_NAMESPACE);
    characterId = 1111;
    ephCharacterId = 1111;
    tribeId = 1122;
    charEntityRecordData = CharEntityRecordData({ itemId: 1234, typeId: 2345, volume: 0 });
    ephCharEntityRecordData = CharEntityRecordData({ itemId: 1234, typeId: 2345, volume: 0 });
    charOffchainData = EntityRecordOffchainTableData({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });
    tokenCID = "Qm1234abcdxxxx";

    // create SSU Inventory Owner character
    smartCharacter.createCharacter(characterId, alice, tribeId, charEntityRecordData, charOffchainData, tokenCID);

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
    EntityRecordTable.set(item1.inventoryItemId, item1.itemId, item1.typeId, item1.volume, true);
    EntityRecordTable.set(item2.inventoryItemId, item2.itemId, item2.typeId, item2.volume, true);
    EntityRecordTable.set(item3.inventoryItemId, item3.itemId, item3.typeId, item3.volume, true);
    EntityRecordTable.set(item4.inventoryItemId, item4.itemId, item4.typeId, item4.volume, true);
    EntityRecordTable.set(item5.inventoryItemId, item5.itemId, item5.typeId, item5.volume, true);
    EntityRecordTable.set(item6.inventoryItemId, item6.itemId, item6.typeId, item6.volume, true);
    EntityRecordTable.set(item7.inventoryItemId, item7.itemId, item7.typeId, item7.volume, true);
    EntityRecordTable.set(item8.inventoryItemId, item8.itemId, item8.typeId, item8.volume, true);
    EntityRecordTable.set(item9.inventoryItemId, item9.itemId, item9.typeId, item9.volume, true);
    EntityRecordTable.set(item10.inventoryItemId, item10.itemId, item10.typeId, item10.volume, true);
    EntityRecordTable.set(item11.inventoryItemId, item11.itemId, item11.typeId, item11.volume, true);
    EntityRecordTable.set(item12.inventoryItemId, item12.itemId, item12.typeId, item12.volume, true);
    EntityRecordTable.set(item13.inventoryItemId, item13.itemId, item13.typeId, item13.volume, true);

    // inventory interface setting
    inventory = InventoryLib.World(world, DEPLOYMENT_NAMESPACE);

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
    vm.assume(storageCapacity >= 1500 && storageCapacity <= 10000);
    uint256 ephemeralStorageCapacity = 100000;
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

    InventoryItem[] memory items = new InventoryItem[](3);
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

    testSetDeployableStateToValid(smartObjectId);
    testSetInventoryCapacity(smartObjectId, storageCapacity);

    InventoryTableData memory inventoryTableData = InventoryTable.get(smartObjectId);
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    inventory.depositToInventory(smartObjectId, items);
    inventoryTableData = InventoryTable.get(smartObjectId);

    //Check whether the items are stored in the inventory table
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
    uint256 ephemeralStorageCapacity = 100000;
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

    InventoryItem[] memory items = new InventoryItem[](3);
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

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
    vm.assume(storageCapacity >= 1200 && storageCapacity <= 10000);
    testDepositToInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = item4;
    inventory.depositToInventory(smartObjectId, items);

    uint256 itemsLength = InventoryTable.getItems(smartObjectId).length;
    assertEq(itemsLength, 4);

    // inventory.depositToInventory(smartObjectId, items);
    // InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    // assertEq(inventoryItem1.index, 3);
  }

  function testRevertDepositToInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 150 && storageCapacity <= 500);

    // create SSU smart object with token
    uint256 ephemeralStorageCapacity = 100000;
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

    testSetDeployableStateToValid(smartObjectId);
    testSetInventoryCapacity(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    item1.inventoryItemId = 20;
    items[0] = item1;

    // invalid item revert
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidItem.selector,
        "InventorySystem: item is not created on-chain",
        item1.inventoryItemId
      )
    );
    inventory.depositToInventory(smartObjectId, items);

    // TODO: if _msgSender() is not APPROVED, then _initalMsgSender should be the owner of the inventory

    // items[0] = item13;
    // // item owner revert
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     IInventoryErrors.Inventory_InvalidItemOwner.selector,
    //     "InventorySystem: smartObjectId inventory owner and item.owner should be the same",
    //     items[0].inventoryItemId,
    //     items[0].owner,
    //     alice
    //   )
    // );
    // inventory.depositToInventory(smartObjectId, items);

    item2.quantity = 60;
    items[0] = item2;
    // capacity revert
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

    InventoryItem[] memory items = new InventoryItem[](3);
    item1.quantity = 1;
    item2.quantity = 2;
    item3.quantity = 1;
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

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

    assertEq(inventoryTableData.items[0], items[0].inventoryItemId);
    assertEq(inventoryTableData.items[1], items[2].inventoryItemId);

    //Check whether the items quantity is reduced
    InventoryItemTableData memory inventoryItem1 = InventoryItemTable.get(smartObjectId, items[0].inventoryItemId);
    InventoryItemTableData memory inventoryItem3 = InventoryItemTable.get(smartObjectId, items[2].inventoryItemId);
    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem3.quantity, 1);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem3.index, 1);
  }

  function testDeposit1andWithdraw1(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity >= 1100 && storageCapacity <= 10000);
    uint256 ephemeralStorageCapacity = 100000;
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

    InventoryItem[] memory items = new InventoryItem[](1);
    item1.quantity = 3;
    items[0] = item1;

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

    InventoryItem[] memory items = new InventoryItem[](2);
    item1.quantity = 3;
    item2.quantity = 2;
    items[0] = item1;
    items[1] = item2;

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
    item1.quantity = 3;
    item2.quantity = 2;
    item3.quantity = 2;
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = item1;
    items[1] = item2;
    items[2] = item3;

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

    uint256 ephemeralStorageCapacity = 100000;
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

    inventory.depositToInventory(smartObjectId, items);

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
    item3.quantity = 1;
    items[0] = item3;

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
    item3.quantity = 1;

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidItemQuantity.selector,
        "InventorySystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    inventory.withdrawFromInventory(smartObjectId, items);
  }

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
