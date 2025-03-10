// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { WorldOwnership } from "../../src/namespaces/evefrontier/codegen/tables/WorldOwnership.sol";
import { AccountOwnership } from "../../src/namespaces/evefrontier/codegen/tables/AccountOwnership.sol";
import { OwnershipByObject } from "../../src/namespaces/evefrontier/codegen/tables/OwnershipByObject.sol";
import { InventoryByItem } from "../../src/namespaces/evefrontier/codegen/tables/InventoryByItem.sol";
import { EntityRecord } from "../../src/namespaces/evefrontier/codegen/tables/EntityRecord.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { Inventory, InventoryData } from "../../src/namespaces/evefrontier/codegen/tables/Inventory.sol";
import { InventoryItem, InventoryItemData } from "../../src/namespaces/evefrontier/codegen/tables/InventoryItem.sol";
import { CharactersByAccount } from "../../src/namespaces/evefrontier/codegen/tables/CharactersByAccount.sol";

import { OwnershipSystemLib, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventorySystemLib, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { EveTest } from "../EveTest.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-system/AccessSystem.sol";
import { OwnershipSystem } from "../../src/namespaces/evefrontier/systems/ownership/OwnershipSystem.sol";
import { EntityRecordParams, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";

contract OwnershipTest is EveTest {
  // uint256 singletonObjectId = 1234;
  // uint256 nonSingletonObjectId = 2345;
  // uint256 inventoryObjectId = 3456;
  // uint256 secondInventoryObjectId = 4567;
  // uint256 characterId = 111;
  // uint256 tribeId = 222;
  // uint256 itemId = 333;
  // uint256 typeId = 444;

  // string mnemonic = "test test test test test test test test test test test junk";

  // uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  // address deployer = vm.addr(deployerPK);

  // uint256 alicePK = vm.deriveKey(mnemonic, 2);
  // address alice = vm.addr(alicePK);

  // uint256 bobPK = vm.deriveKey(mnemonic, 3);
  // address bob = vm.addr(bobPK);
  // function setUp() public virtual override {
  //   super.setUp();

  //   vm.startPrank(deployer);
    
  //   // Register necessary classes
  //   uint256 ownershipTestClassId = uint256(bytes32("OWNERSHIP_TEST"));
  //   ResourceId[] memory ownershipTestSystemIds = new ResourceId[](1);
  //   ownershipTestSystemIds[0] = ownershipSystem.toResourceId();
  //   entitySystem.registerClass(ownershipTestClassId, ownershipTestSystemIds);

  //   uint256 inventoryTestClassId = uint256(bytes32("INVENTORY_TEST"));
  //   ResourceId[] memory inventoryTestSystemIds = new ResourceId[](2);
  //   inventoryTestSystemIds[0] = inventorySystem.toResourceId();
  //   inventoryTestSystemIds[1] = ownershipSystem.toResourceId();
  //   entitySystem.registerClass(inventoryTestClassId, inventoryTestSystemIds);

  //   // Create a smart character for alice
  //   EntityRecordParams memory entityRecord = EntityRecordParams({ 
  //     typeId: typeId, 
  //     itemId: itemId, 
  //     volume: 100 
  //   });
    
  //   EntityMetadata memory entityRecordMetadata = EntityMetadata({
  //     name: "Test Character",
  //     dappURL: "https://example.com",
  //     description: "A test character"
  //   });
    
  //   smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);
    
  //   // Create singleton object
  //   entitySystem.instantiate(ownershipTestClassId, singletonObjectId, deployer);
  //   EntityRecord.set(singletonObjectId, true, itemId, typeId, 100, "tenant");
    
  //   // Create non-singleton object
  //   entitySystem.instantiate(ownershipTestClassId, nonSingletonObjectId, deployer);
  //   EntityRecord.set(nonSingletonObjectId, true, 0, typeId, 50, "tenant");
    
  //   // Create primary inventory object
  //   entitySystem.instantiate(inventoryTestClassId, inventoryObjectId, deployer);
  //   EntityRecord.set(inventoryObjectId, true, itemId+1, typeId, 200, "tenant");
  //   inventorySystem.setInventoryCapacity(inventoryObjectId, 1000);
    
  //   // Create second inventory object for transfer tests
  //   entitySystem.instantiate(inventoryTestClassId, secondInventoryObjectId, deployer);
  //   EntityRecord.set(secondInventoryObjectId, true, itemId+2, typeId, 200, "tenant");
  //   inventorySystem.setInventoryCapacity(secondInventoryObjectId, 1000);

  //   vm.stopPrank();
  // }

  // function test_ascribeToAccount() public {
  //   // Revert Case 1: Non-existent object
  //   uint256 nonExistentObjectId = 9999;
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.OwnershipSystem_NonexistentObject.selector, nonExistentObjectId));
  //   ownershipSystem.ascribeToAccount(nonExistentObjectId, alice);
  //   vm.stopPrank();
    
  //   // Revert Case 2: Cannot ascribe non-singleton object
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.OwnershipSystem_InvalidSingleton.selector, nonSingletonObjectId));
  //   ownershipSystem.ascribeToAccount(nonSingletonObjectId, alice);
  //   vm.stopPrank();
    
  //   // Revert Case 3: Cannot ascribe to an address without a smart character
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.OwnershipSystem_InvalidAccount.selector, bob));
  //   ownershipSystem.ascribeToAccount(singletonObjectId, bob);
  //   vm.stopPrank();
    
  //   // Test success case
  //   // Get values before ascribing
  //   address ownerBefore = OwnershipByObject.get(singletonObjectId);
  //   uint256 accountQuantityBefore = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityBefore = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
  //   uint256 classQuantityBefore = WorldOwnership.getQuantity(classId);
    
  //   assertEq(ownerBefore, address(0));
  //   assertEq(accountQuantityBefore, 0);
  //   assertEq(worldQuantityBefore, 0);
  //   assertEq(classQuantityBefore, 0);

  //   // Execute ascribeToAccount
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToAccount(singletonObjectId, alice);
  //   vm.stopPrank();
    
  //   // Verify state after ascribing
  //   address ownerAfter = OwnershipByObject.get(singletonObjectId);
  //   uint256 accountQuantityAfter = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityAfter = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classQuantityAfter = WorldOwnership.getQuantity(classId);
    
  //   // Assert changes
  //   assertEq(ownerAfter, alice);
  //   assertEq(accountQuantityAfter, accountQuantityBefore + 1);
  //   assertEq(worldQuantityAfter, worldQuantityBefore + 1);
  //   assertEq(classQuantityAfter, classQuantityBefore + 1);
  // }

  // function test_ascribeToInventory() public {
  //   // First set up the inventory owner
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToAccount(inventoryObjectId, alice);
  //   vm.stopPrank();
    
  //   // Revert Case 1: Non-existent item record
  //   uint256 nonExistentObjectId = 9999;
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_NonexistentItemRecord.selector, 
  //     nonExistentObjectId
  //   ));
  //   ownershipSystem.ascribeToInventory(nonExistentObjectId, inventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 2: Cannot ascribe to non-existent inventory object
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_NonexistentObject.selector, 
  //     nonExistentObjectId
  //   ));
  //   ownershipSystem.ascribeToInventory(singletonObjectId, nonExistentObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 3: Cannot ascribe to inventory without an owner
  //   uint256 unownedInventoryId = 8888;
  //   entitySystem.instantiate(inventoryTestClassId, unownedInventoryId, deployer);
  //   EntityRecord.set(unownedInventoryId, true, itemId+3, typeId, 200, "tenant");
    
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidOwner.selector, 
  //     unownedInventoryId, address(0)
  //   ));
  //   ownershipSystem.ascribeToInventory(singletonObjectId, unownedInventoryId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 4: Cannot ascribe singleton with quantity != 1
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidQuantity.selector, 
  //     singletonObjectId, 2, 1
  //   ));
  //   ownershipSystem.ascribeToInventory(singletonObjectId, inventoryObjectId, 2);
  //   vm.stopPrank();
    
  //   // Test success case for singleton
  //   // Get values before ascribing
  //   uint256 inventoryIdBefore = InventoryByItem.getInventoryId(singletonObjectId);
  //   uint256 accountQuantityBefore = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityBefore = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
  //   uint256 classQuantityBefore = WorldOwnership.getQuantity(classId);

  //   assertEq(inventoryIdBefore, 0);
  //   assertEq(accountQuantityBefore, 0);
  //   assertEq(worldQuantityBefore, 0);
  //   assertEq(classQuantityBefore, 0);
    
  //   // Execute ascribeToInventory for singleton
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToInventory(singletonObjectId, inventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Verify state after ascribing
  //   uint256 inventoryIdAfter = InventoryByItem.getInventoryId(singletonObjectId);
  //   uint256 accountQuantityAfter = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityAfter = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classQuantityAfter = WorldOwnership.getQuantity(classId);

  //   // Assert changes
  //   assertEq(inventoryIdAfter, inventoryObjectId);
  //   assertEq(accountQuantityAfter, accountQuantityBefore + 1);
  //   assertEq(worldQuantityAfter, worldQuantityBefore + 1);
  //   assertEq(classQuantityAfter, classQuantityBefore + 1);

  //   // Test non-singleton
    
  //   // Revert Case 1: zero quantity
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_ZeroQuantity.selector, 
  //     nonSingletonObjectId, 0
  //   ));
  //   ownershipSystem.ascribeToInventory(nonSingletonObjectId, inventoryObjectId, 0);
  //   vm.stopPrank();

  //   // Test success case for non-singleton
  //   uint256 quantity = 5;
    
  //   // Get values before ascribing
  //   // Assert changes - note that for non-singletons, the inventory ID isn't set in InventoryByItem
  //   accountQuantityBefore = AccountOwnership.getQuantity(nonSingletonObjectId, alice);
  //   worldQuantityBefore = WorldOwnership.getQuantity(nonSingletonObjectId);
  //   classQuantityBefore = WorldOwnership.getQuantity(classId);

  //   assertEq(accountQuantityBefore, 0);
  //   assertEq(worldQuantityBefore, 0);
  //   assertEq(classQuantityBefore, 0);
    
  //   // Execute ascribeToInventory for non-singleton
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToInventory(nonSingletonObjectId, inventoryObjectId, quantity);
  //   vm.stopPrank();
    
  //   // Verify state after ascribing
  //   accountQuantityAfter = AccountOwnership.getQuantity(nonSingletonObjectId, alice);
  //   worldQuantityAfter = WorldOwnership.getQuantity(nonSingletonObjectId);
  //   classQuantityAfter = WorldOwnership.getQuantity(classId);
    
  //   assertEq(accountQuantityAfter, accountQuantityBefore + quantity);
  //   assertEq(classQuantityAfter, classQuantityBefore + quantity);
  // }

  // function test_annulFromAccount() public {
  //   // First set up ownership
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToAccount(singletonObjectId, alice);
  //   vm.stopPrank();
    
  //   // Test revert cases first
    
  //   // Revert Case 1: Cannot annul non-existent object
  //   uint256 nonExistentObjectId = 9999;
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_NonexistentObject.selector, 
  //     nonExistentObjectId
  //   ));
  //   ownershipSystem.annulFromAccount(nonExistentObjectId, alice);
  //   vm.stopPrank();
    
  //   // Revert Case 2: Cannot annul non-singleton object from an account
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidSingleton.selector, 
  //     nonSingletonObjectId
  //   ));
  //   ownershipSystem.annulFromAccount(nonSingletonObjectId, alice);
  //   vm.stopPrank();
    
  //   // Revert Case 3: Cannot annul if not owned by the account
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidOwner.selector, 
  //     singletonObjectId, bob
  //   ));
  //   ownershipSystem.annulFromAccount(singletonObjectId, bob);
  //   vm.stopPrank();
    
  //   // Test success case
  //   // Get values before annulling
  //   address ownerBefore = OwnershipByObject.get(singletonObjectId);
  //   uint256 accountQuantityBefore = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityBefore = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
  //   uint256 classQuantityBefore = WorldOwnership.getQuantity(classId);
    
  //   // check owner using the ownershipSystem.owner() function also
  //   assertEq(ownershipSystem.owner(singletonObjectId), alice);

  //   assertEq(ownerBefore, alice);
  //   assertEq(accountQuantityBefore, 1);
  //   assertEq(worldQuantityBefore, 1);
  //   assertEq(classQuantityBefore, 1);

  //   // Execute annulFromAccount
  //   vm.startPrank(deployer);
  //   ownershipSystem.annulFromAccount(singletonObjectId, alice);
  //   vm.stopPrank();
    
  //   // Verify state after annulling
  //   address ownerAfter = OwnershipByObject.get(singletonObjectId);
  //   uint256 accountQuantityAfter = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityAfter = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classQuantityAfter = WorldOwnership.getQuantity(classId);
    
  //   // Assert changes
  //   assertEq(ownerAfter, address(0)); // Owner should be cleared
  //   assertEq(accountQuantityAfter, 0); // Quantity should be reduced to 0
  //   assertEq(worldQuantityAfter, worldQuantityBefore - 1);
  //   assertEq(classQuantityAfter, classQuantityBefore - 1);

  //   // test annulFromAccount if there has not been an ascription before. should fail with OwnershipSystem_InvalidOwner
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidOwner.selector, 
  //     singletonObjectId, address(0)
  //   ));
  //   ownershipSystem.annulFromAccount(singletonObjectId, alice);
  //   vm.stopPrank();
  // }

  // function test_annulFromInventory() public {
  //   // First set up the inventory and item ownership
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToAccount(inventoryObjectId, alice);
  //   ownershipSystem.ascribeToInventory(singletonObjectId, inventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 1: Cannot annul if item is not in the inventory
  //   uint256 notInInventoryId = 7777;
  //   EntityRecord.set(notInInventoryId, true, itemId+2, typeId, 100, "tenant");
    
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidInventory.selector, 
  //     notInInventoryId, inventoryObjectId
  //   ));
  //   ownershipSystem.annulFromInventory(notInInventoryId, inventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 2: Cannot annul singleton with quantity != 1
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidQuantity.selector, 
  //     singletonObjectId, 2, 1
  //   ));
  //   ownershipSystem.annulFromInventory(singletonObjectId, inventoryObjectId, 2);
  //   vm.stopPrank();
    
  //   // Test success case
  //   // Get values before annulling
  //   uint256 inventoryIdBefore = InventoryByItem.getInventoryId(singletonObjectId);
  //   uint256 accountQuantityBefore = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityBefore = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
  //   uint256 classQuantityBefore = WorldOwnership.getQuantity(classId);

  //   assertEq(inventoryIdBefore, inventoryObjectId);
  //   assertEq(accountQuantityBefore, 1);
  //   assertEq(worldQuantityBefore, 1);
  //   assertEq(classQuantityBefore, 1);
    
  //   // Execute annulFromInventory
  //   vm.startPrank(deployer);
  //   ownershipSystem.annulFromInventory(singletonObjectId, inventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Verify state after annulling
  //   uint256 inventoryIdAfter = InventoryByItem.getInventoryId(singletonObjectId);
  //   uint256 accountQuantityAfter = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 worldQuantityAfter = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classQuantityAfter = WorldOwnership.getQuantity(classId);
    
  //   // Assert changes
  //   assertEq(inventoryIdAfter, 0); // Inventory ID should be cleared
  //   assertEq(accountQuantityAfter, 0); // Account quantity should be reduced to 0
  //   assertEq(worldQuantityAfter, worldQuantityBefore - 1);
  //   assertEq(classQuantityAfter, classQuantityBefore - 1);
    
  //   // Test non-singleton case
  //   // First set up non-singleton in inventory
  //   uint256 quantity = 5;
    
  //   vm.startPrank(deployer);
  //   // We need to add inventory item data for non-singleton to test quantity check
  //   InventoryItem.set(inventoryObjectId, nonSingletonObjectId, quantity, 0, 0);
  //   ownershipSystem.ascribeToInventory(nonSingletonObjectId, inventoryObjectId, quantity);
  //   vm.stopPrank();
    
  //   // Get values before annulling
  //   accountQuantityBefore = AccountOwnership.getQuantity(nonSingletonObjectId, alice);
  //   classQuantityBefore = WorldOwnership.getQuantity(classId);

  //   assertEq(accountQuantityBefore, quantity);
  //   assertEq(classQuantityBefore, quantity);
    
  //   // Execute annulFromInventory for non-singleton with valid quantity
  //   vm.startPrank(deployer);
  //   ownershipSystem.annulFromInventory(nonSingletonObjectId, inventoryObjectId, quantity);
  //   vm.stopPrank();
    
  //   // Verify state after annulling
  //   accountQuantityAfter = AccountOwnership.getQuantity(nonSingletonObjectId, alice);
  //   classQuantityAfter = WorldOwnership.getQuantity(classId);
    
  //   // Assert changes
  //   assertEq(accountQuantityAfter, 0); // Account quantity should be reduced to 0
  //   assertEq(classQuantityAfter, classQuantityBefore - quantity);
  // }
  
  // function test_transferInventory() public {
  //   // Setup both inventories with owners and place item in first inventory
  //   vm.startPrank(deployer);
  //   ownershipSystem.ascribeToAccount(inventoryObjectId, alice);
  //   ownershipSystem.ascribeToAccount(secondInventoryObjectId, bob);
  //   ownershipSystem.ascribeToInventory(singletonObjectId, inventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Test revert cases first
    
  //   // Revert Case 1: Cannot transfer if item is not in the from inventory
  //   uint256 nonInventoryItemId = 7777;
  //   EntityRecord.set(nonInventoryItemId, true, itemId+3, typeId, 100, "tenant");
    
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidInventory.selector, 
  //     nonInventoryItemId, inventoryObjectId
  //   ));
  //   ownershipSystem.transferInventory(nonInventoryItemId, inventoryObjectId, secondInventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 2: Cannot transfer if fromInventory doesn't exist
  //   uint256 nonExistentInventoryId = 9999;
    
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_NonexistentObject.selector, 
  //     nonExistentInventoryId
  //   ));
  //   ownershipSystem.transferInventory(singletonObjectId, nonExistentInventoryId, secondInventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 3: Cannot transfer if toInventory doesn't exist
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_NonexistentObject.selector, 
  //     nonExistentInventoryId
  //   ));
  //   ownershipSystem.transferInventory(singletonObjectId, inventoryObjectId, nonExistentInventoryId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 4: Cannot transfer if fromInventory has no owner
  //   uint256 unownedInventoryId = 8888;
  //   entitySystem.instantiate(inventoryTestClassId, unownedInventoryId, deployer);
  //   EntityRecord.set(unownedInventoryId, true, itemId+3, typeId, 200, "tenant");
    
  //   // First place item in unowned inventory
  //   vm.startPrank(deployer);
  //   OwnershipByObject.set(unownedInventoryId, alice); // Temporarily set owner to place item
  //   ownershipSystem.ascribeToInventory(nonInventoryItemId, unownedInventoryId, 1);
  //   OwnershipByObject.deleteRecord(unownedInventoryId); // Remove owner to test revert
    
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidOwner.selector, 
  //     unownedInventoryId, address(0)
  //   ));
  //   ownershipSystem.transferInventory(nonInventoryItemId, unownedInventoryId, secondInventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Revert Case 5: Cannot transfer if toInventory has no owner
  //   vm.startPrank(deployer);
  //   vm.expectRevert(abi.encodeWithSelector(
  //     OwnershipSystem.OwnershipSystem_InvalidOwner.selector, 
  //     unownedInventoryId, address(0)
  //   ));
  //   ownershipSystem.transferInventory(singletonObjectId, inventoryObjectId, unownedInventoryId, 1);
  //   vm.stopPrank();
    
  //   // Test success case
  //   // Get values before transfer
  //   uint256 inventoryIdBefore = InventoryByItem.getInventoryId(singletonObjectId);
  //   uint256 aliceQuantityBefore = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 bobQuantityBefore = AccountOwnership.getQuantity(singletonObjectId, bob);
  //   uint256 worldQuantityBefore = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
  //   uint256 classQuantityBefore = WorldOwnership.getQuantity(classId);
    
  //   assertEq(inventoryIdBefore, inventoryObjectId);
  //   assertEq(aliceQuantityBefore, 1);
  //   assertEq(bobQuantityBefore, 0);
  //   assertEq(worldQuantityBefore, 1);
  //   assertEq(classQuantityBefore, 1);
    
  //   // Execute transferInventory
  //   vm.startPrank(deployer);
  //   ownershipSystem.transferInventory(singletonObjectId, inventoryObjectId, secondInventoryObjectId, 1);
  //   vm.stopPrank();
    
  //   // Verify state after transfer
  //   uint256 inventoryIdAfter = InventoryByItem.getInventoryId(singletonObjectId);
  //   uint256 aliceQuantityAfter = AccountOwnership.getQuantity(singletonObjectId, alice);
  //   uint256 bobQuantityAfter = AccountOwnership.getQuantity(singletonObjectId, bob);
  //   uint256 worldQuantityAfter = WorldOwnership.getQuantity(singletonObjectId);
  //   uint256 classQuantityAfter = WorldOwnership.getQuantity(classId);
    
  //   // Assert changes
  //   assertEq(inventoryIdAfter, secondInventoryObjectId); // Inventory ID should be updated to new inventory
  //   assertEq(aliceQuantityAfter, 0); // Alice's quantity should be reduced to 0
  //   assertEq(bobQuantityAfter, 1); // Bob's quantity should be increased to 1
  //   assertEq(worldQuantityAfter, worldQuantityBefore); // World quantity should remain the same
  //   assertEq(classQuantityAfter, classQuantityBefore); // Class quantity should remain the same
    
  //   // Test non-singleton transfer
  //   // First setup non-singleton in first inventory
  //   uint256 quantity = 5;
    
  //   vm.startPrank(deployer);
  //   // Reset ownership for alice
  //   ownershipSystem.ascribeToAccount(inventoryObjectId, alice);
  //   // Add inventory item data for non-singleton
  //   InventoryItem.set(inventoryObjectId, nonSingletonObjectId, quantity, 0, 0);
  //   ownershipSystem.ascribeToInventory(nonSingletonObjectId, inventoryObjectId, quantity);
  //   vm.stopPrank();
    
  //   // Get values before transfer
  //   aliceQuantityBefore = AccountOwnership.getQuantity(nonSingletonObjectId, alice);
  //   bobQuantityBefore = AccountOwnership.getQuantity(nonSingletonObjectId, bob);
    
  //   assertEq(aliceQuantityBefore, quantity);
  //   assertEq(bobQuantityBefore, 0);
    
  //   // Execute transfer for partial quantity
  //   uint256 transferQuantity = 3;
    
  //   vm.startPrank(deployer);
  //   ownershipSystem.transferInventory(nonSingletonObjectId, inventoryObjectId, secondInventoryObjectId, transferQuantity);
  //   vm.stopPrank();
    
  //   // Verify state after transfer
  //   aliceQuantityAfter = AccountOwnership.getQuantity(nonSingletonObjectId, alice);
  //   bobQuantityAfter = AccountOwnership.getQuantity(nonSingletonObjectId, bob);
    
  //   // Assert changes
  //   assertEq(aliceQuantityAfter, quantity - transferQuantity); // Alice's quantity should be reduced
  //   assertEq(bobQuantityAfter, transferQuantity); // Bob's quantity should be increased
  // }
}