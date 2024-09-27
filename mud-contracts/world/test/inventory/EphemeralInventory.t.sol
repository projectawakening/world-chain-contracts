// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import "@eveworld/common-constants/src/constants.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EntityRecordTable } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EphemeralInvTable, EphemeralInvTableData } from "../../src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvCapacityTable } from "../../src/codegen/tables/EphemeralInvCapacityTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { EntityRecordData } from "../../src/modules/smart-character/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";

contract EphemeralInventoryTest is MudTest {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  InventoryLib.World ephemeralInventory;
  SmartDeployableLib.World smartDeployable;
  SmartCharacterLib.World smartCharacter;

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
  EntityRecordData charEntityRecordData = EntityRecordData({ itemId: 1234, typeId: 2345, volume: 0 });
  EntityRecordData diffCharEntityRecordData = EntityRecordData({ itemId: 1235, typeId: 2346, volume: 0 });
  EntityRecordOffchainTableData charOffchainData =
    EntityRecordOffchainTableData({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });

  EntityRecordOffchainTableData diffCharOffchainData =
    EntityRecordOffchainTableData({
      name: "Erbus Demernster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The worst hunter-seeker in the Frontier."
    });

  string tokenCID = "Qm1234abcdxxxx";

  function setUp() public override {
    vm.startPrank(deployer);
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    ephemeralInventory = InventoryLib.World(world, INVENTORY_DEPLOYMENT_NAMESPACE);
    smartCharacter = SmartCharacterLib.World(world, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);

    smartDeployable.globalResume();

    smartCharacter.createCharacter(characterId, owner, tribeId, charEntityRecordData, charOffchainData, tokenCID);
    smartCharacter.createCharacter(
      diffCharacterId,
      differentOwner,
      tribeId,
      diffCharEntityRecordData,
      diffCharOffchainData,
      tokenCID
    );

    //Mock Item creation
    // Note: this only works because deployer currently owns `ENTITY_RECORD` namespace so direct calls to its tables are allowed
    EntityRecordTable.set(4235, 4235, 12, 100, true);
    EntityRecordTable.set(4236, 4236, 12, 200, true);
    EntityRecordTable.set(4237, 4237, 12, 150, true);
    EntityRecordTable.set(8235, 8235, 12, 100, true);
    EntityRecordTable.set(8236, 8236, 12, 200, true);
    EntityRecordTable.set(8237, 8237, 12, 150, true);
    vm.stopPrank();
  }

  function testSetup() public {
    address EpheremalSystem = Systems.getSystem(INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId());
    ResourceId ephemeralInventorySystemId = SystemRegistry.get(EpheremalSystem);
    assertEq(ephemeralInventorySystemId.getNamespace(), INVENTORY_DEPLOYMENT_NAMESPACE);
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
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, storageCapacity);
    assertEq(EphemeralInvCapacityTable.getCapacity(smartObjectId), storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "EphemeralInventorySystem: storage capacity cannot be 0"
      )
    );
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, storageCapacity);
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

    EphemeralInvTableData memory inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);

    //Check weather the items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryTableData.items[i], items[i].inventoryItemId);
    }

    inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);
    assert(capacityBeforeDeposit < capacityAfterDeposit);

    assertEq(inventoryTableData.items.length, 3);

    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      smartObjectId,
      items[0].inventoryItemId,
      owner
    );

    EphemeralInvItemTableData memory inventoryItem2 = EphemeralInvItemTable.get(
      smartObjectId,
      items[1].inventoryItemId,
      owner
    );

    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(
      smartObjectId,
      items[2].inventoryItemId,
      owner
    );

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
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    //check the increase in quantity
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);
    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemTableData memory inventoryItem2 = EphemeralInvItemTable.get(
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(
      smartObjectId,
      items[2].inventoryItemId,
      items[2].owner
    );
    assertEq(inventoryItem1.quantity, items[0].quantity * 2);
    assertEq(inventoryItem2.quantity, items[1].quantity * 2);
    assertEq(inventoryItem3.quantity, items[2].quantity * 2);

    uint256 itemsLength = EphemeralInvTable.getItems(smartObjectId, owner).length;
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
        IInventoryErrors.Inventory_InsufficientCapacity.selector,
        "EphemeralInventorySystem: insufficient capacity",
        storageCapacity,
        items[0].volume * items[0].quantity
      )
    );
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    owner = address(9); // set owner as non-character address
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidEphemeralInventoryOwner.selector,
        "EphemeralInventorySystem: provided ephemeralInventoryOwner is not a valid address",
        address(9)
      )
    );
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);
  }

  function testDepositToExistingEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testDepositToEphemeralInventory(smartObjectId, storageCapacity);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(8235, owner, 8235, 0, 1, 3);
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    uint256 itemsLength = EphemeralInvTable.getItems(smartObjectId, owner).length;
    // ALTHOUGH THIS LITLERALLY RETURNS THE VALUE 4 EVERY SINGLE TIME, this assertion fails for me, so I'm commenting out for now
    assertEq(itemsLength, 4);

    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    assertEq(inventoryItem1.index, 3);

    items = new InventoryItem[](1);

    items[0] = InventoryItem(8235, differentOwner, 8235, 0, 1, 3);
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, differentOwner, items);

    itemsLength = EphemeralInvTable.getItems(smartObjectId, differentOwner).length;
    assertEq(itemsLength, 1);

    inventoryItem1 = EphemeralInvItemTable.get(smartObjectId, items[0].inventoryItemId, items[0].owner);
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

    EphemeralInvTableData memory inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);

    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);
    assertEq(existingItems[0], items[0].inventoryItemId);
    assertEq(existingItems[1], items[2].inventoryItemId);

    //Check weather the items quantity is reduced
    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemTableData memory inventoryItem2 = EphemeralInvItemTable.get(
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(
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

    EphemeralInvTableData memory inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);

    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 0);

    //Check weather the items quantity is reduced
    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemTableData memory inventoryItem2 = EphemeralInvItemTable.get(
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(
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

    EphemeralInvTableData memory inventoryTableData = EphemeralInvTable.get(smartObjectId, owner);
    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4237, owner, 4237, 0, 200, 1);

    // Try withdraw again
    ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);

    uint256 itemId1 = uint256(4235);
    uint256 itemId3 = uint256(4237);

    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(smartObjectId, itemId1, owner);
    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(smartObjectId, itemId3, owner);

    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem3.quantity, 0);

    assertEq(inventoryItem1.index, 0);
    assertEq(inventoryItem3.index, 0);

    existingItems = EphemeralInvTable.getItems(smartObjectId, owner);
    assertEq(existingItems.length, 1);
  }

  function testRevertWithdrawFromEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    testDepositToEphemeralInventory(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, differentOwner, 4235, 12, 100, 6);

    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     IInventoryErrors.Inventory_InvalidItemOwner.selector,
    //     "EphemeralInventorySystem: ephemeralInventoryOwner and item.owner should be the same",
    //     4235,
    //     differentOwner,
    //     owner
    //   )
    // );
    // ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);

    items[0] = InventoryItem(4235, owner, 4235, 12, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidItemQuantity.selector,
        "EphemeralInventorySystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);
  }
}
