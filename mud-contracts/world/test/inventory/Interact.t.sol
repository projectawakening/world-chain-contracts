// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { console } from "forge-std/console.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { InventoryItemTableData, InventoryItemTable } from "../../src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";

import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { TransferItem } from "../../src/modules/inventory/types.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { IAccessSystemErrors } from "../../src/modules/access/interfaces/IAccessSystemErrors.sol";
import { IInventoryInteractSystem } from "../../src/modules/inventory/interfaces/IInventoryInteractSystem.sol";

import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";

import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";

import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as CharEntityRecordData } from "../../src/modules/smart-character/types.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

import { AccessRolePerObject } from "../../src/codegen/tables/AccessRolePerObject.sol";
import { AccessEnforcePerObject } from "../../src/codegen/tables/AccessEnforcePerObject.sol";

import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { VendingMachineMock } from "./VendingMachineMock.sol";

contract InteractTest is MudTest {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;

  IWorldWithEntryContext world;
  InventoryLib.World inventory;
  SmartDeployableLib.World smartDeployable;
  SmartStorageUnitLib.World smartStorageUnit;
  SmartCharacterLib.World smartCharacter;

  VendingMachineMock vendingMachineMock;
  bytes16 constant SYSTEM_NAME = bytes16("VendingMachineMo");
  ResourceId constant VENDING_MACHINE_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

  VendingMachineMock notAllowedMock;
  ResourceId constant NOT_ALLOWED_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, bytes14("not-allowed"), SYSTEM_NAME))));

  bytes32 constant APPROVED = bytes32("APPROVED_ACCESS_ROLE");

  uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
  uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
  uint256 storageCapacity = 100000;
  uint256 ephemeralStorageCapacity = 100000;

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
  address alice = vm.addr(alicePK); // SSU owner
  address bob = vm.addr(bobPK); // EphInv owner

  function setUp() public override {
    vm.startPrank(deployer);
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    inventory = InventoryLib.World(world, DEPLOYMENT_NAMESPACE);
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartStorageUnit = SmartStorageUnitLib.World(world, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);

    // Vending Machine deploy & registration
    vendingMachineMock = new VendingMachineMock();
    world.registerSystem(VENDING_MACHINE_SYSTEM_ID, vendingMachineMock, true);
    world.registerFunctionSelector(VENDING_MACHINE_SYSTEM_ID, "interactCall(uint256, address, uint256)");

    // Not Allowed deploy & registration
    notAllowedMock = new VendingMachineMock();
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(bytes14("not-allowed")));
    world.registerSystem(NOT_ALLOWED_SYSTEM_ID, notAllowedMock, true);
    world.registerFunctionSelector(NOT_ALLOWED_SYSTEM_ID, "interactCall(uint256, address, uint256)");

    // Resume SD operations for executing SSU configuration
    smartDeployable.globalResume();
    //Mock Smart Storage Unit data
    EntityRecordData memory entity1 = EntityRecordData({ typeId: 1, itemId: 2345, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    // SmartCharacter interface & variable setting
    smartCharacter = SmartCharacterLib.World(world, DEPLOYMENT_NAMESPACE);
    characterId = 1111;
    ephCharacterId = 2222;
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
    // create ephemeral Inventory Owner character
    smartCharacter.createCharacter(ephCharacterId, bob, tribeId, ephCharEntityRecordData, charOffchainData, tokenCID);

    smartStorageUnit.createAndAnchorSmartStorageUnit(
      smartObjectId,
      entity1,
      smartObjectData,
      worldPosition,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18, // fuelMaxCapacity,
      storageCapacity,
      ephemeralStorageCapacity
    );
    smartDeployable.depositFuel(smartObjectId, 100000);
    smartDeployable.bringOnline(smartObjectId);

    // Inventory variables
    InventoryItem[] memory invItems = new InventoryItem[](1);
    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    invItems[0] = InventoryItem(itemObjectId1, alice, 45, 1, 50, 10);
    ephInvItems[0] = InventoryItem(itemObjectId2, bob, 46, 2, 70, 10);

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, invItems);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, bob, ephInvItems);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(smartObjectId, alice, ephInvItems);
    vm.stopPrank();
  }

  function testSetup() public {
    address epheremalInventoryAddress = Systems.getSystem(DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId());
    ResourceId ephemeralInventorySystemId = SystemRegistry.get(epheremalInventoryAddress);
    assertEq(ephemeralInventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);

    address inventoryAddress = Systems.getSystem(DEPLOYMENT_NAMESPACE.inventorySystemId());
    ResourceId inventorySystemId = SystemRegistry.get(inventoryAddress);
    assertEq(inventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);

    address vendingMachineSystemAddress = Systems.getSystem(VENDING_MACHINE_SYSTEM_ID);
    ResourceId vendingMachineSystemId = SystemRegistry.get(vendingMachineSystemAddress);
    assertEq(vendingMachineSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testEphemeralToInventoryTransfer() public {
    uint256 quantity = 2;

    InventoryItemTableData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 10);
    InventoryItemTableData memory storedInventoryItems2 = InventoryItemTable.get(smartObjectId, itemObjectId2);
    assertEq(storedInventoryItems2.quantity, 0);
    EphemeralInvItemTableData memory storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId2, bob, quantity);

    vm.startPrank(bob);
    inventory.ephemeralToInventoryTransfer(smartObjectId, transferItems);
    vm.stopPrank();

    storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 10);
    storedInventoryItems2 = InventoryItemTable.get(smartObjectId, itemObjectId2);
    assertEq(storedInventoryItems2.quantity, 2);
    storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 8);
  }

  function testRevertEphemeralToInventoryTransfer() public {
    uint256 quantity = 12;

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId2, bob, quantity);

    // account does not have ephInventory for this Smart Object (this contract address)
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidTransferItemQuantity.selector,
        "InventoryInteractSystem: not enough items to transfer",
        smartObjectId,
        "EPHEMERAL",
        address(this),
        itemObjectId2,
        quantity
      )
    );
    inventory.ephemeralToInventoryTransfer(smartObjectId, transferItems);

    // acccount has ephInventory for this Smart Object (bob), but does not have enough items to transfer
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidTransferItemQuantity.selector,
        "InventoryInteractSystem: not enough items to transfer",
        smartObjectId,
        "EPHEMERAL",
        bob,
        itemObjectId2,
        quantity
      )
    );
    vm.startPrank(bob);
    inventory.ephemeralToInventoryTransfer(smartObjectId, transferItems);
    vm.stopPrank();
  }

  function testInventoryToEphemeralTransfer() public {
    uint256 quantity = 2;

    InventoryItemTableData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 10);
    EphemeralInvItemTableData memory storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);
    EphemeralInvItemTableData memory storedEphInventoryItems1 = EphemeralInvItemTable.get(
      smartObjectId,
      itemObjectId1,
      bob
    );
    assertEq(storedEphInventoryItems1.quantity, 0);

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId1, alice, quantity);
    vm.startPrank(alice);
    inventory.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();

    storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 8);
    storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, bob);
    assertEq(storedEphInvItems.quantity, 10);
    storedEphInventoryItems1 = EphemeralInvItemTable.get(smartObjectId, itemObjectId1, bob);
    assertEq(storedEphInventoryItems1.quantity, 2);
  }

  function testRevertInventoryToEphemeralTransfer() public {
    uint256 quantity = 12;

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId1, alice, quantity);

    // acccount is owner for this Smart Object (alice), but does not have enough items in the object to transfer
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidTransferItemQuantity.selector,
        "InventoryInteractSystem: not enough items to transfer",
        smartObjectId,
        "OBJECT",
        alice,
        itemObjectId1,
        quantity
      )
    );
    vm.startPrank(alice);
    inventory.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();
  }

  function testSetApprovedAccessList() public {
    address[] memory accessList = new address[](1);
    accessList[0] = address(vendingMachineMock);

    address[] memory storedAccessList = AccessRolePerObject.get(smartObjectId, APPROVED);
    assertEq(storedAccessList.length, 0);
    vm.startPrank(alice);
    inventory.setApprovedAccessList(smartObjectId, accessList);
    vm.stopPrank();
    storedAccessList = AccessRolePerObject.get(smartObjectId, APPROVED);
    assertEq(storedAccessList.length, accessList.length);
    assertEq(storedAccessList[0], address(vendingMachineMock));
  }

  function testRevertSetApprovedAccessList() public {
    address[] memory accessList = new address[](1);
    accessList[0] = address(vendingMachineMock);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(this), bytes32("OWNER"))
    );
    inventory.setApprovedAccessList(smartObjectId, accessList);
  }
  // for this test alice has to be her own ephemeral inventory owner, because intialMsgSender only picks up the first prank
  function testSetAllInventoryTransferAccess() public {
    bytes32 target1 = keccak256(
      abi.encodePacked(
        DEPLOYMENT_NAMESPACE.inventoryInteractSystemId(),
        IInventoryInteractSystem.ephemeralToInventoryTransfer.selector
      )
    );
    bytes32 target2 = keccak256(
      abi.encodePacked(
        DEPLOYMENT_NAMESPACE.inventoryInteractSystemId(),
        IInventoryInteractSystem.inventoryToEphemeralTransfer.selector
      )
    );
    // set access list
    testSetApprovedAccessList();

    // set enforcement true
    vm.startPrank(alice);
    inventory.setAllInventoryTransferAccess(smartObjectId, true);
    vm.stopPrank();

    assertEq(AccessEnforcePerObject.get(smartObjectId, target1), true);
    assertEq(AccessEnforcePerObject.get(smartObjectId, target2), true);

    vm.startPrank(alice);
    // call via vendingMachineMock success (internally this calls both interact.inventoryToEphemeralTransfer and interact.ephemeralToInventoryTransfer)
    world.call(VENDING_MACHINE_SYSTEM_ID, abi.encodeCall(VendingMachineMock.interactCall, (smartObjectId, alice, 1)));
    vm.stopPrank();

    // check storage changes
    InventoryItemTableData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 8);
    EphemeralInvItemTableData memory storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, alice);
    assertEq(storedEphInvItems.quantity, 9);
    EphemeralInvItemTableData memory storedEphInventoryItems1 = EphemeralInvItemTable.get(
      smartObjectId,
      itemObjectId1,
      alice
    );
    assertEq(storedEphInventoryItems1.quantity, 2);

    // call via notAllowed Mock fail
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(notAllowedMock), APPROVED)
    );
    world.call(NOT_ALLOWED_SYSTEM_ID, abi.encodeCall(VendingMachineMock.interactCall, (smartObjectId, bob, 1)));

    // set enforcement false
    vm.startPrank(alice);
    inventory.setAllInventoryTransferAccess(smartObjectId, false);
    vm.stopPrank();

    assertEq(AccessEnforcePerObject.get(smartObjectId, target1), false);
    assertEq(AccessEnforcePerObject.get(smartObjectId, target2), false);
  }

  function testRevertSetAllInventoryTransferAccess() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(this), bytes32("OWNER"))
    );
    inventory.setAllInventoryTransferAccess(smartObjectId, true);
  }

  function testSetEphemeralToInventoryTransferAccess() public {
    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId2, bob, 1);
    bytes32 target1 = keccak256(
      abi.encodePacked(
        DEPLOYMENT_NAMESPACE.inventoryInteractSystemId(),
        IInventoryInteractSystem.ephemeralToInventoryTransfer.selector
      )
    );

    // set access list
    testSetApprovedAccessList();
    // set enforcement true
    vm.startPrank(alice);
    inventory.setEphemeralToInventoryTransferAccess(smartObjectId, true);
    vm.stopPrank();

    assertEq(AccessEnforcePerObject.get(smartObjectId, target1), true);

    // call via vendingMachineMock success (internally this calls both interact.inventoryToEphemeralTransfer and interact.ephemeralToInventoryTransfer)
    vm.startPrank(alice);
    world.call(VENDING_MACHINE_SYSTEM_ID, abi.encodeCall(VendingMachineMock.interactCall, (smartObjectId, alice, 1)));
    vm.stopPrank();
    InventoryItemTableData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 8);
    EphemeralInvItemTableData memory storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, alice);
    assertEq(storedEphInvItems.quantity, 9);
    EphemeralInvItemTableData memory storedEphInventoryItems1 = EphemeralInvItemTable.get(
      smartObjectId,
      itemObjectId1,
      alice
    );
    assertEq(storedEphInventoryItems1.quantity, 2);

    // call via notAllowed Mock fail
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(notAllowedMock), APPROVED)
    );
    world.call(NOT_ALLOWED_SYSTEM_ID, abi.encodeCall(VendingMachineMock.interactCall, (smartObjectId, bob, 1)));

    // call directly fail
    vm.expectRevert(abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, APPROVED));
    vm.startPrank(alice);
    inventory.ephemeralToInventoryTransfer(smartObjectId, transferItems);
    vm.stopPrank();

    // set enforcement false
    vm.startPrank(alice);
    inventory.setEphemeralToInventoryTransferAccess(smartObjectId, false);
    vm.stopPrank();

    // not enforced direct call success
    vm.startPrank(alice);
    inventory.ephemeralToInventoryTransfer(smartObjectId, transferItems);
    vm.stopPrank();

    assertEq(AccessEnforcePerObject.get(smartObjectId, target1), false);
  }

  function testRevertSetEphemeralToInventoryTransferAccess() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(this), bytes32("OWNER"))
    );
    inventory.setEphemeralToInventoryTransferAccess(smartObjectId, true);
  }

  function setInventoryToEphemeralTransferAccess() public {
    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(itemObjectId2, alice, 1);
    bytes32 target2 = keccak256(
      abi.encodePacked(
        DEPLOYMENT_NAMESPACE.inventoryInteractSystemId(),
        IInventoryInteractSystem.inventoryToEphemeralTransfer.selector
      )
    );

    // set access list
    testSetApprovedAccessList();
    // set enforcement true
    vm.startPrank(alice);
    inventory.setInventoryToEphemeralTransferAccess(smartObjectId, true);
    vm.stopPrank();

    assertEq(AccessEnforcePerObject.get(smartObjectId, target2), true);

    // call via vendingMachineMock success (internally this calls both interact.inventoryToEphemeralTransfer and interact.ephemeralToInventoryTransfer)
    vm.startPrank(alice);
    world.call(VENDING_MACHINE_SYSTEM_ID, abi.encodeCall(VendingMachineMock.interactCall, (smartObjectId, alice, 1)));
    vm.stopPrank();
    InventoryItemTableData memory storedInventoryItems = InventoryItemTable.get(smartObjectId, itemObjectId1);
    assertEq(storedInventoryItems.quantity, 8);
    EphemeralInvItemTableData memory storedEphInvItems = EphemeralInvItemTable.get(smartObjectId, itemObjectId2, alice);
    assertEq(storedEphInvItems.quantity, 9);
    EphemeralInvItemTableData memory storedEphInventoryItems1 = EphemeralInvItemTable.get(
      smartObjectId,
      itemObjectId1,
      alice
    );
    assertEq(storedEphInventoryItems1.quantity, 2);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(notAllowedMock), APPROVED)
    );
    world.call(NOT_ALLOWED_SYSTEM_ID, abi.encodeCall(VendingMachineMock.interactCall, (smartObjectId, bob, 1)));

    // call directly succeeds (for Object owner)
    vm.startPrank(alice);
    inventory.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
    vm.stopPrank();

    // set enforcement false
    vm.startPrank(alice);
    inventory.setEphemeralToInventoryTransferAccess(smartObjectId, false);
    vm.stopPrank();

    // not enforced direct call success
    vm.startPrank(alice);
    inventory.ephemeralToInventoryTransfer(smartObjectId, transferItems);
    vm.stopPrank();

    assertEq(AccessEnforcePerObject.get(smartObjectId, target2), false);
  }

  function testRevertSetInventoryToEphemeralTransferAccess() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(this), bytes32("OWNER"))
    );
    inventory.setInventoryToEphemeralTransferAccess(smartObjectId, true);
  }
}
