// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { DeployableState, DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecord } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { InventoryItemData, InventoryItem  } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordParams, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { DEPLOYMENT_NAMESPACE } from "../../src/namespaces/evefrontier/systems/constants.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { EphemeralInventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/EphemeralInventorySystem.sol";
import { InventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { InventoryInteractSystem } from "../../src/namespaces/evefrontier/systems/inventory/InventoryInteractSystem.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { VendingMachineMock } from "./VendingMachineMock.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystemLib, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystemLib, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryInteractSystemLib, inventoryInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { EveTest } from "../EveTest.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-system/AccessSystem.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

contract InventoryInteractTest is EveTest {
  // VendingMachineMock vendingMachineMock;
  // bytes16 constant SYSTEM_NAME = bytes16("VendingMachineMo");
  // ResourceId constant VENDING_MACHINE_SYSTEM_ID =
  //   ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

  // VendingMachineMock notAllowedMock;
  // ResourceId constant NOT_ALLOWED_SYSTEM_ID =
  //   ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, bytes14("not-allowed"), SYSTEM_NAME))));

  // uint256 vendingMachineClassId = uint256(bytes32("VENDING_MACHINE"));

  // uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  // uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
  // uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
  // uint256 storageCapacity = 100000;
  // uint256 ephemeralStorageCapacity = 100000;

  // // Smart Character variables
  // uint256 characterId;
  // uint256 ephCharacterId;
  // uint256 tribeId;
  // EntityRecordParams charEntityRecordData;
  // EntityRecordparams ephCharEntityRecordData;
  // EntityMetadata characterMetadata;
  // string tokenCID;

  // function setUp() public override {
  //   vm.startPrank(deployer);

  //   // Running full EveTest setup was running out of gas.
  //   // So we do a subset of the setup here.
  //   worldSetup();
  //   deploySmartObjectFramework();
  //   configureAdminRole();
  //   registerInventoryItemClass(adminRole);
  //   registerSmartCharacterClass(adminRole);
  //   configureInventoryInteractAccess();

  //   // Vending Machine deploy & registration
  //   vendingMachineMock = new VendingMachineMock();
  //   world.registerSystem(VENDING_MACHINE_SYSTEM_ID, vendingMachineMock, true);
  //   world.registerFunctionSelector(VENDING_MACHINE_SYSTEM_ID, "interactCall(uint256, address, uint256)");

  //   // Not Allowed deploy & registration
  //   notAllowedMock = new VendingMachineMock();
  //   world.registerNamespace(WorldResourceIdLib.encodeNamespace(bytes14("not-allowed")));
  //   world.registerSystem(NOT_ALLOWED_SYSTEM_ID, notAllowedMock, true);
  //   world.registerFunctionSelector(NOT_ALLOWED_SYSTEM_ID, "interactCall(uint256, address, uint256)");

  //   characterId = 1111;
  //   ephCharacterId = 2222;
  //   tribeId = 1122;
  //   charEntityRecordData = EntityRecordParams({ typeId: 2345, itemId: 1234, volume: 0 });
  //   ephCharEntityRecordData = EntityRecordParams({ typeId: 2345, itemId: 1234, volume: 0 });
  //   characterMetadata = EntityMetadata({
  //     name: "Albus Demunster",
  //     dappURL: "https://www.my-tribe-website.com",
  //     description: "The top hunter-seeker in the Frontier."
  //   });
  //   tokenCID = "Qm1234abcdxxxx";

  //   deployableSystem.globalResume();

  //   // create SSU Inventory Owner character
  //   smartCharacterSystem.createCharacter(characterId, alice, tribeId, charEntityRecordData, characterMetadata);
  //   // create ephemeral Inventory Owner character
  //   smartCharacterSystem.createCharacter(ephCharacterId, bob, tribeId, charEntityRecordData, characterMetadata);

  //   // Inventory variables
  //   EntityRecord.set(itemObjectId1, itemObjectId1, 1, 50, true);
  //   EntityRecord.set(itemObjectId2, itemObjectId2, 2, 70, true);

  //   InventoryItemParams[] memory invItems = new InventoryItemParams[](1);
  //   InventoryItemParams[] memory ephInvItems = new InventoryItemParams[](1);
  //   invItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId1, owner: alice, itemId: 45, volume: 50, quantity: 10 });
  //   ephInvItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId2, owner: bob, itemId: 46, volume: 70, quantity: 10 });

  //   uint256 fuelUnitVolume = 1;
  //   uint256 fuelConsumptionIntervalInSeconds = 1;
  //   uint256 fuelMaxCapacity = 10000;

  //   ResourceId[] memory systemIds = new ResourceId[](5);
  //   systemIds[0] = inventorySystem.toResourceId();
  //   systemIds[1] = deployableSystem.toResourceId();
  //   systemIds[2] = ephemeralInventorySystem.toResourceId();
  //   systemIds[3] = inventoryInteractSystem.toResourceId();
  //   systemIds[4] = fuelSystem.toResourceId();
  //   entitySystem.registerClass(vendingMachineClassId, systemIds);

  //   entitySystem.instantiate(vendingMachineClassId, smartObjectId, alice);

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
  //   inventorySystem.setCapacity(smartObjectId, storageCapacity);
  //   inventorySystem.setEphemeralCapacity(smartObjectId, ephemeralStorageCapacity);
  //   vm.stopPrank();

  //   vm.startPrank(alice);
  //   inventorySystem.depositToInventory(smartObjectId, invItems);
  //   ephemeralInventorySystem.depositToEphemeralInventory(smartObjectId, bob, ephInvItems);
  //   // ephemeralInventorySystem.depositToEphemeralInventory(smartObjectId, alice, ephInvItems);
  //   vm.stopPrank();
  // }

  // function testEphemeralToInventoryTransfer() public {
  //   uint256 quantity = 2;

  //   InventoryItemData memory storedInventoryItems = InventoryItem.get(smartObjectId, itemObjectId1);
  //   assertEq(storedInventoryItems.quantity, 10);
  //   InventoryItemData memory storedInventoryItems2 = InventoryItem.get(smartObjectId, itemObjectId2);
  //   assertEq(storedInventoryItems2.quantity, 0);
  //   EphemeralInvItemData memory storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
  //   assertEq(storedEphInvItems.quantity, 10);

  //   InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
  //   transferItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId2, owner: bob, itemId: itemObjectId2, volume: 10, quantity: quantity });

  //   vm.startPrank(alice);
  //   inventoryInteractSystem.ephemeralToInventoryTransfer(smartObjectId, bob, transferItems);
  //   vm.stopPrank();

  //   storedInventoryItems = InventoryItem.get(smartObjectId, itemObjectId1);
  //   assertEq(storedInventoryItems.quantity, 10);
  //   storedInventoryItems2 = InventoryItem.get(smartObjectId, itemObjectId2);
  //   assertEq(storedInventoryItems2.quantity, 2);
  //   storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
  //   assertEq(storedEphInvItems.quantity, 8);
  // }

  // function testRevertEphemeralToInventoryTransfer() public {
  //   uint256 quantity = 12;

  //   InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
  //   transferItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId2, owner: bob, itemId: itemObjectId2, volume: 10, quantity: quantity });

  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       InventoryInteractSystem.Inventory_InvalidInventoryItemQuantity.selector,
  //       "InventoryInteractSystem: not enough items to transfer",
  //       smartObjectId,
  //       "EPHEMERAL",
  //       bob,
  //       itemObjectId2,
  //       quantity
  //     )
  //   );

  //   vm.startPrank(alice);
  //   inventoryInteractSystem.ephemeralToInventoryTransfer(smartObjectId, bob, transferItems);
  //   vm.stopPrank();

  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       InventoryInteractSystem.Inventory_InvalidInventoryItemQuantity.selector,
  //       "InventoryInteractSystem: not enough items to transfer",
  //       smartObjectId,
  //       "EPHEMERAL",
  //       bob,
  //       itemObjectId2,
  //       quantity
  //     )
  //   );

  //   vm.startPrank(alice);
  //   inventoryInteractSystem.ephemeralToInventoryTransfer(smartObjectId, bob, transferItems);
  //   vm.stopPrank();
  // }

  // function testInventoryToEphemeralTransfer() public {
  //   uint256 quantity = 2;

  //   InventoryItemData memory storedInventoryItems = InventoryItem.get(smartObjectId, itemObjectId1);
  //   assertEq(storedInventoryItems.quantity, 10);
  //   EphemeralInvItemData memory storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
  //   assertEq(storedEphInvItems.quantity, 10);
  //   EphemeralInvItemData memory storedEphInventoryItems1 = EphemeralInvItem.get(smartObjectId, itemObjectId1, bob);
  //   assertEq(storedEphInventoryItems1.quantity, 0);

  //   InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
  //   transferItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId1, owner: alice, itemId: itemObjectId1, volume: 10, quantity: quantity });

  //   vm.startPrank(alice);
  //   inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
  //   vm.stopPrank();

  //   storedInventoryItems = InventoryItem.get(smartObjectId, itemObjectId1);
  //   assertEq(storedInventoryItems.quantity, 8);
  //   storedEphInvItems = EphemeralInvItem.get(smartObjectId, itemObjectId2, bob);
  //   assertEq(storedEphInvItems.quantity, 10);
  //   storedEphInventoryItems1 = EphemeralInvItem.get(smartObjectId, itemObjectId1, bob);
  //   assertEq(storedEphInventoryItems1.quantity, 2);
  // }

  // function testBobCannotTransferFromInventory() public {
  //   uint256 quantity = 2;

  //   InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
  //   transferItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId1, owner: bob, itemId: itemObjectId1, volume: 10, quantity: quantity });

  //   vm.startPrank(bob);
  //   vm.expectRevert(
  //     abi.encodeWithSelector(AccessSystem.Access_NotOwnerOrCanWithdrawFromInventory.selector, bob, smartObjectId)
  //   );
  //   inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
  //   vm.stopPrank();
  // }

  // function testGrantTransferFromInventoryAccess() public {
  //   uint256 quantity = 2;

  //   InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
  //   transferItems[0] = InventoryItemParams({ inventoryItemId: itemObjectId1, owner: bob, itemId: itemObjectId1, volume: 10, quantity: quantity });

  //   vm.startPrank(deployer);
  //   inventoryInteractSystem.setInventoryToEphemeralTransferAccess(smartObjectId, bob, true);
  //   vm.stopPrank();

  //   vm.startPrank(bob);
  //   inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, bob, transferItems);
  //   vm.stopPrank();
  // }
}
