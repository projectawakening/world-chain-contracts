// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { State, SmartObjectData } from "../../src/systems/deployable/types.sol";
import { EntityRecord } from "../../src/codegen/index.sol";
import { InventoryItemData, InventoryItem as InventoryItemTable } from "../../src/codegen/index.sol";
import { EphemeralInvItemData, EphemeralInvItem } from "../../src/codegen/index.sol";
import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { DEPLOYMENT_NAMESPACE } from "../../src/systems/constants.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { EphemeralInventorySystem } from "../../src/systems/inventory/EphemeralInventorySystem.sol";
import { InventorySystem } from "../../src/systems/inventory/InventorySystem.sol";
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";
import { InventoryInteractSystem } from "../../src/systems/inventory/InventoryInteractSystem.sol";
import { TransferItem } from "../../src/systems/inventory/types.sol";
import { VendingMachineMock } from "./VendingMachineMock.sol";

contract InventoryInteractTest is MudTest {
  IBaseWorld world;
  VendingMachineMock vendingMachineMock;
  bytes16 constant SYSTEM_NAME = bytes16("VendingMachineMo");
  ResourceId constant VENDING_MACHINE_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

  VendingMachineMock notAllowedMock;
  ResourceId constant NOT_ALLOWED_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, bytes14("not-allowed"), SYSTEM_NAME))));

  uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
  uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
  uint256 storageCapacity = 100000;
  uint256 ephemeralStorageCapacity = 100000;

  // Smart Character variables
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
  address alice = vm.addr(alicePK); // SSU owner
  address bob = vm.addr(bobPK); // EphInv owner

  ResourceId smartCharacterSystemId = SmartCharacterUtils.smartCharacterSystemId();
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
  ResourceId invetoryInteractSystemId = InventoryUtils.inventoryInteractSystemId();

  function setUp() public override {
    vm.startPrank(deployer);

    super.setUp();
    world = IBaseWorld(worldAddress);

    // Vending Machine deploy & registration
    vendingMachineMock = new VendingMachineMock();
    world.registerSystem(VENDING_MACHINE_SYSTEM_ID, vendingMachineMock, true);
    world.registerFunctionSelector(VENDING_MACHINE_SYSTEM_ID, "interactCall(uint256, address, uint256)");

    // Not Allowed deploy & registration
    notAllowedMock = new VendingMachineMock();
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(bytes14("not-allowed")));
    world.registerSystem(NOT_ALLOWED_SYSTEM_ID, notAllowedMock, true);
    world.registerFunctionSelector(NOT_ALLOWED_SYSTEM_ID, "interactCall(uint256, address, uint256)");

    characterId = 1111;
    ephCharacterId = 2222;
    tribeId = 1122;
    charEntityRecordData = EntityRecordData({ typeId: 2345, itemId: 1234, volume: 0 });
    ephCharEntityRecordData = EntityRecordData({ typeId: 2345, itemId: 1234, volume: 0 });
    characterMetadata = EntityMetadata({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });
    tokenCID = "Qm1234abcdxxxx";

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));

    // create SSU Inventory Owner character
    world.call(
      smartCharacterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, alice, tribeId, charEntityRecordData, characterMetadata)
      )
    );
    // create ephemeral Inventory Owner character
    world.call(
      smartCharacterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (ephCharacterId, bob, tribeId, charEntityRecordData, characterMetadata)
      )
    );

    // Inventory variables
    EntityRecord.set(itemObjectId1, itemObjectId1, 1, 50, true);
    EntityRecord.set(itemObjectId2, itemObjectId2, 2, 70, true);

    InventoryItem[] memory invItems = new InventoryItem[](1);
    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    invItems[0] = InventoryItem(itemObjectId1, alice, 45, 1, 50, 10);
    ephInvItems[0] = InventoryItem(itemObjectId2, bob, 46, 2, 70, 10);

    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    uint256 fuelUnitVolume = 1;
    uint256 fuelConsumptionIntervalInSeconds = 1;
    uint256 fuelMaxCapacity = 10000;

    world.call(
      deployableSystemId,
      abi.encodeCall(
        DeployableSystem.registerDeployable,
        (smartObjectId, smartObjectData, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity)
      )
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
    world.call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, ephemeralStorageCapacity))
    );

    world.call(inventorySystemId, abi.encodeCall(InventorySystem.depositToInventory, (smartObjectId, invItems)));
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, bob, ephInvItems))
    );
    world.call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, alice, ephInvItems))
    );

    vm.stopPrank();
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

    vm.startPrank(bob);
    world.call(
      invetoryInteractSystemId,
      abi.encodeCall(InventoryInteractSystem.ephemeralToInventoryTransfer, (smartObjectId, bob, transferItems))
    );

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

    // account does not have ephInventory for this Smart Object (this contract address)
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

    world.call(
      invetoryInteractSystemId,
      abi.encodeCall(InventoryInteractSystem.ephemeralToInventoryTransfer, (smartObjectId, bob, transferItems))
    );

    // acccount has ephInventory for this Smart Object (bob), but does not have enough items to transfer
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
    world.call(
      invetoryInteractSystemId,
      abi.encodeCall(InventoryInteractSystem.ephemeralToInventoryTransfer, (smartObjectId, bob, transferItems))
    );
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

    world.call(
      invetoryInteractSystemId,
      abi.encodeCall(InventoryInteractSystem.inventoryToEphemeralTransfer, (smartObjectId, bob, transferItems))
    );
    vm.stopPrank();

    storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 8);
    storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);
    storedEphInventoryItems1 = EphemeralInvItem.get(smartObjectId, itemObjectId1, bob);
    assertEq(storedEphInventoryItems1.quantity, 2);
  }

  //TODO All access control tests
}
