// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIdInstance } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { tagSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { TagIdLib } from "@eveworld/smart-object-framework-v2/src/libs/TagId.sol";
import { TagParams, ResourceRelationValue, TAG_TYPE_RESOURCE_RELATION } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/types.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, EntityRecordData, EntityRecordMetadata, EntityRecordMetadataData, DeployableState, InventoryByItem, OwnershipByObject, EphemeralInvCapacity, CharactersByAccount, EphemeralInventory, InventoryByEphemeral, SmartAssembly } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { State } from "../../src/codegen/common.sol";

// Local namespace systems
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartAssemblySystem, smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { LocationSystem, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { SmartCharacterSystem, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";

// Types and parameters
import { EntityRecordParams, EntityMetadataParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateInventoryItemParams, InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";

// Create a mock system to properly test system-to-system calls
contract MockEntityRecordInteractSystem is System {
  function callCreateRecord(uint256 smartObjectId, EntityRecordParams memory params) public {
    entityRecordSystem.createRecord(smartObjectId, params);
  }

  function callCreateMetadata(uint256 smartObjectId, EntityMetadataParams memory params) public {
    entityRecordSystem.createMetadata(smartObjectId, params);
  }

  function callSetName(uint256 smartObjectId, string memory name) public {
    entityRecordSystem.setName(smartObjectId, name);
  }

  function callSetDescription(uint256 smartObjectId, string memory description) public {
    entityRecordSystem.setDescription(smartObjectId, description);
  }

  function callSetDappURL(uint256 smartObjectId, string memory dappURL) public {
    entityRecordSystem.setDappURL(smartObjectId, dappURL);
  }

  function callCreateAssembly(
    uint256 smartObjectId,
    string memory assemblyType,
    EntityRecordParams memory entityRecordParams
  ) public {
    smartAssemblySystem.createAssembly(smartObjectId, assemblyType, entityRecordParams);
  }

  function callCreateCharacter(
    uint256 smartObjectId,
    address owner,
    uint256 tribeId,
    EntityRecordParams memory entityRecordParams,
    EntityMetadataParams memory entityRecordMetadata
  ) public {
    smartCharacterSystem.createCharacter(smartObjectId, owner, tribeId, entityRecordParams, entityRecordMetadata);
  }

  function callCreateAndDepositInventory(uint256 smartObjectId, CreateInventoryItemParams[] memory items) public {
    inventorySystem.createAndDepositInventory(smartObjectId, items);
  }

  function callCreateAndDepositEphemeral(
    uint256 smartObjectId,
    address ephemeralOwner,
    CreateInventoryItemParams[] memory items
  ) public {
    ephemeralInventorySystem.createAndDepositEphemeral(smartObjectId, ephemeralOwner, items);
  }
}

contract EntityRecordTest is MudTest {
  using WorldResourceIdLib for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 objectClassId;
  uint256 smartObjectId;
  uint256 smartCharacterClassId;
  uint256 smartCharacterObjectId;
  uint256 invalidSmartCharacterObjectId;
  bytes32 tenantId;

  // Smart Object Entity Record variables
  uint256 constant SMART_CHARACTER_TYPE_ID = 42000000100;
  uint256 constant SMART_CHARACTER_ITEM_ID = 1337;
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;
  uint256 constant SMART_OBJECT_ID = 1234;

  // metadata variables
  string constant NAME = "Test Entity Record";
  string constant DAPP_URL = "https://test.com";
  string constant DESCRIPTION = "This is a test entity record";

  // character variables
  uint256 tribeId = 101;

  uint256 constant SINGLETON_TYPE_ID = 500;
  uint256 constant SINGLETON_ITEM_ID = 501;
  uint256 constant EPHEMERAL_ITEM_ID = 502;
  uint256 constant NON_SINGLETON_TYPE_ID = 600;

  uint256 singletonClassId;
  uint256 singletonObjectId;
  uint256 ephemeralSingletonClassId;
  uint256 ephemeralSingletonObjectId;
  uint256 nonSingletonObjectId;
  uint256 invalidSmartObjectId;

  EntityRecordParams entityRecordParams;
  EntityMetadataParams entityMetadataParams;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  // Mock system address
  MockEntityRecordInteractSystem mockSystem;
  ResourceId mockSystemId;
  TagParams mockTagParams;

  function setUp() public virtual override {
    vm.pauseGasMetering();
    super.setUp();
    // Deploy a new World
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);

    // Initialize addresses
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));
    alice = vm.addr(vm.deriveKey(mnemonic, 2));
    bob = vm.addr(vm.deriveKey(mnemonic, 3));

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice and bob
    CharactersByAccount.set(alice, 1);

    // Setup tenant
    tenantId = Tenant.get();

    // Setup smart object ID
    smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);

    // setup smart object class id
    objectClassId = _calculateObjectId(SMART_OBJECT_TYPE_ID, 0, false);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("MockEntityRecord");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockEntityRecordInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    ResourceId[] memory systemIds = new ResourceId[](6);
    systemIds[0] = smartAssemblySystem.toResourceId();
    systemIds[1] = smartCharacterSystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = inventorySystem.toResourceId();
    systemIds[4] = ephemeralInventorySystem.toResourceId();
    systemIds[5] = mockSystemId;

    // create a resource relation tag for the mock system
    mockTagParams = TagParams(
      TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(mockSystemId))),
      abi.encode(
        ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, ResourceIdInstance.getResourceName(mockSystemId))
      )
    );

    smartCharacterClassId = _calculateObjectId(SMART_CHARACTER_TYPE_ID, 0, false);
    smartCharacterObjectId = _calculateObjectId(SMART_CHARACTER_TYPE_ID, SMART_CHARACTER_ITEM_ID, true);
    invalidSmartCharacterObjectId = _calculateObjectId(SMART_CHARACTER_TYPE_ID, SMART_CHARACTER_ITEM_ID + 1, true);

    // tag the smart character class with the mock system
    tagSystem.setTag(smartCharacterClassId, mockTagParams);

    // add our mock system to the entity record system call access for all functions (because EntityRecord requires CallAccess permissions currently)
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      address(mockSystem),
      true
    );
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createMetadata.selector,
      address(mockSystem),
      true
    );
    CallAccess.set(entityRecordSystem.toResourceId(), EntityRecordSystem.setName.selector, address(mockSystem), true);
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setDappURL.selector,
      address(mockSystem),
      true
    );
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setDescription.selector,
      address(mockSystem),
      true
    );

    // add our mock to the EphemeralInventorySystem call access
    CallAccess.set(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.createAndDepositEphemeral.selector,
      address(mockSystem),
      true
    );

    entitySystem.registerClass(objectClassId, systemIds); // tags the system to this class for scoping

    // instantiate the smart object
    entitySystem.instantiate(objectClassId, smartObjectId, alice);

    // invalid smartObjectIds
    invalidSmartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 2, true);
    entitySystem.instantiate(objectClassId, invalidSmartObjectId, alice);

    // mock inventory data
    Inventory.set(smartObjectId, 100, 0, 1, new uint256[](0));

    // set alice as owner of the mock inventory
    InventoryByItem.set(singletonObjectId, smartObjectId);
    OwnershipByObject.set(smartObjectId, alice);

    // mock ephermaral inventory data
    EphemeralInvCapacity.set(smartObjectId, 100);
    EphemeralInventory.set(smartObjectId, bob, 100, 0, 1, new uint256[](0));

    // set bob as owner of the mock ephemeral inventory
    uint256 ephermaObjectId = uint256(keccak256(abi.encodePacked(smartObjectId, bob)));
    InventoryByItem.set(ephemeralSingletonObjectId, ephermaObjectId);
    InventoryByEphemeral.set(ephermaObjectId, true, smartObjectId, bob);

    // set test parameters
    entityRecordParams = EntityRecordParams(tenantId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 100);
    entityMetadataParams = EntityMetadataParams({ name: NAME, dappURL: DAPP_URL, description: DESCRIPTION });

    // mock Deployable state ONLINE
    DeployableState.set(
      smartObjectId,
      block.timestamp,
      State.ANCHORED,
      State.ONLINE,
      true,
      0,
      block.number,
      block.timestamp
    );

    vm.stopPrank();
  }

  function test_createRecord() public {
    vm.startPrank(deployer);

    assertEq(EntityRecord.getExists(smartObjectId), false);

    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateRecord, (smartObjectId, entityRecordParams))
    );

    EntityRecordData memory entityRecord = EntityRecord.get(smartObjectId);

    assertEq(entityRecord.exists, true);
    assertEq(entityRecord.tenantId, tenantId);
    assertEq(entityRecord.typeId, SMART_OBJECT_TYPE_ID);
    assertEq(entityRecord.itemId, SMART_OBJECT_ID);
    assertEq(entityRecord.volume, 100);

    vm.stopPrank();
  }

  function test_createMetadata() public {
    vm.startPrank(deployer);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.name, "");
    assertEq(entityRecordMetaData.dappURL, "");
    assertEq(entityRecordMetaData.description, "");

    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateMetadata, (smartObjectId, entityMetadataParams))
    );

    entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.name, NAME);
    assertEq(entityRecordMetaData.dappURL, DAPP_URL);
    assertEq(entityRecordMetaData.description, DESCRIPTION);
    vm.stopPrank();
  }

  function test_setName() public {
    vm.startPrank(deployer);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.name, "");

    world.call(mockSystemId, abi.encodeCall(MockEntityRecordInteractSystem.callSetName, (smartObjectId, NAME)));

    entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.name, NAME);
    vm.stopPrank();
  }

  function test_setDappURL() public {
    vm.startPrank(deployer);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.dappURL, "");

    world.call(mockSystemId, abi.encodeCall(MockEntityRecordInteractSystem.callSetDappURL, (smartObjectId, DAPP_URL)));

    entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.dappURL, DAPP_URL);
  }

  function test_setDescription() public {
    vm.startPrank(deployer);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.description, "");

    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callSetDescription, (smartObjectId, DESCRIPTION))
    );

    entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.description, DESCRIPTION);
  }

  function test_SmartAssembly_interaction() public {
    vm.startPrank(deployer);

    // First test revert cases for invalid parameters
    // Test InvalidTypeId
    EntityRecordParams memory invalidParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: SMART_OBJECT_TYPE_ID + 1, // incorrect typeId
      itemId: SMART_OBJECT_ID,
      volume: 100
    });

    vm.expectRevert(
      abi.encodeWithSelector(AccessSystem.Access_NotClassScoped.selector, address(mockSystem), smartObjectId)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAssembly, (smartObjectId, "SSU", invalidParams))
    );

    // Test InvalidTenantId
    bytes32 wrongTenantId = keccak256(abi.encodePacked("WRONG_TENANT"));
    invalidParams = EntityRecordParams({
      tenantId: wrongTenantId, // incorrect tenantId
      typeId: SMART_OBJECT_TYPE_ID,
      itemId: SMART_OBJECT_ID,
      volume: 100
    });

    vm.expectRevert(
      abi.encodeWithSelector(AccessSystem.Access_NotClassScoped.selector, address(mockSystem), smartObjectId)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAssembly, (smartObjectId, "SSU", invalidParams))
    );

    // Test InvalidObjectId
    vm.expectRevert(
      abi.encodeWithSelector(SmartAssemblySystem.SmartAssembly_InvalidObjectId.selector, invalidSmartObjectId)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(
        MockEntityRecordInteractSystem.callCreateAssembly,
        (invalidSmartObjectId, "SSU", entityRecordParams)
      )
    );

    // Now test the successful case
    // check initial empty record state
    assertEq(EntityRecord.getExists(smartObjectId), false);

    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAssembly, (smartObjectId, "SSU", entityRecordParams))
    );

    // check that the record was created and values are correct
    assertEq(EntityRecord.getExists(smartObjectId), true);
    assertEq(EntityRecord.getTenantId(smartObjectId), tenantId);
    assertEq(EntityRecord.getTypeId(smartObjectId), SMART_OBJECT_TYPE_ID);
    assertEq(EntityRecord.getItemId(smartObjectId), SMART_OBJECT_ID);
    assertEq(EntityRecord.getVolume(smartObjectId), 100);

    vm.stopPrank();
  }

  function test_SmartCharacter_interaction() public {
    vm.startPrank(bob, deployer);
    // First test revert cases for invalid parameters

    // Test InvalidTenantId
    bytes32 wrongTenantId = keccak256(abi.encodePacked("WRONG_TENANT"));
    EntityRecordParams memory invalidParams = EntityRecordParams({
      tenantId: wrongTenantId, // incorrect tenantId
      typeId: SMART_CHARACTER_TYPE_ID,
      itemId: SMART_CHARACTER_ITEM_ID,
      volume: 0
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartCharacterSystem.SmartCharacter_InvalidTenantId.selector,
        smartCharacterObjectId,
        invalidParams.tenantId
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(
        MockEntityRecordInteractSystem.callCreateCharacter,
        (smartCharacterObjectId, bob, tribeId, invalidParams, entityMetadataParams)
      )
    );

    // Test InvalidTypeId
    invalidParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: SMART_CHARACTER_TYPE_ID + 1, // incorrect typeId
      itemId: SMART_CHARACTER_ITEM_ID,
      volume: 0
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartCharacterSystem.SmartCharacter_InvalidTypeId.selector,
        smartCharacterObjectId,
        invalidParams.typeId
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(
        MockEntityRecordInteractSystem.callCreateCharacter,
        (smartCharacterObjectId, bob, tribeId, invalidParams, entityMetadataParams)
      )
    );

    // Test InvalidObjectId
    // acutally valid now contrary to its name
    invalidParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: SMART_CHARACTER_TYPE_ID,
      itemId: SMART_CHARACTER_ITEM_ID,
      volume: 0
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartCharacterSystem.SmartCharacter_InvalidObjectId.selector,
        invalidSmartCharacterObjectId
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(
        MockEntityRecordInteractSystem.callCreateCharacter,
        (invalidSmartCharacterObjectId, bob, tribeId, invalidParams, entityMetadataParams)
      )
    );

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(entityRecordMetaData.name, "");
    assertEq(entityRecordMetaData.dappURL, "");
    assertEq(entityRecordMetaData.description, "");

    // check record is not created
    assertEq(EntityRecord.getExists(smartObjectId), false);

    // create character interaction - successful case
    world.call(
      mockSystemId,
      abi.encodeCall(
        MockEntityRecordInteractSystem.callCreateCharacter,
        (smartCharacterObjectId, bob, tribeId, invalidParams, entityMetadataParams)
      )
    );

    // check record + metadata is created and values are correct
    assertEq(EntityRecord.getExists(smartCharacterObjectId), true);
    assertEq(EntityRecord.getTenantId(smartCharacterObjectId), tenantId);
    assertEq(EntityRecord.getTypeId(smartCharacterObjectId), SMART_CHARACTER_TYPE_ID);
    assertEq(EntityRecord.getItemId(smartCharacterObjectId), SMART_CHARACTER_ITEM_ID);
    assertEq(EntityRecord.getVolume(smartCharacterObjectId), 0);

    entityRecordMetaData = EntityRecordMetadata.get(smartCharacterObjectId);

    assertEq(entityRecordMetaData.name, NAME);
    assertEq(entityRecordMetaData.dappURL, DAPP_URL);
    assertEq(entityRecordMetaData.description, DESCRIPTION);

    vm.stopPrank();
  }

  function test_Inventory_interaction() public {
    vm.startPrank(alice, deployer);

    // Define item types for testing
    singletonObjectId = _calculateObjectId(SINGLETON_TYPE_ID, SINGLETON_ITEM_ID, true);
    singletonClassId = _calculateObjectId(SINGLETON_TYPE_ID, 0, false);
    nonSingletonObjectId = _calculateObjectId(NON_SINGLETON_TYPE_ID, 0, false);

    // Create a single reusable item array for revert tests
    CreateInventoryItemParams[] memory testItems = new CreateInventoryItemParams[](1);

    // Initial valid values
    testItems[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_TYPE_ID,
      itemId: SINGLETON_ITEM_ID,
      volume: 10,
      quantity: 1
    });

    // Test failure cases

    // 1. Invalid tenant ID for singleton
    bytes32 wrongTenantId = keccak256(abi.encodePacked("WRONG_TENANT"));
    testItems[0].tenantId = wrongTenantId;

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidTenantId.selector, singletonObjectId, wrongTenantId)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositInventory, (smartObjectId, testItems))
    );

    // Reset tenant ID to valid value
    testItems[0].tenantId = tenantId;

    // 2. Invalid object ID for singleton
    uint256 incorrectSingletonObjectId = singletonObjectId + 1;
    testItems[0].smartObjectId = incorrectSingletonObjectId;

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemObjectId.selector, incorrectSingletonObjectId)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositInventory, (smartObjectId, testItems))
    );

    // Reset to valid object ID
    testItems[0].smartObjectId = singletonObjectId;

    // 3. Invalid quantity for singleton
    testItems[0].quantity = 2; // Should be 1 for singleton

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemDepositQuantity.selector, singletonObjectId, 2)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositInventory, (smartObjectId, testItems))
    );

    // Reset to valid quantity
    testItems[0].quantity = 1;

    // 4. Invalid object ID for non-singleton
    uint256 incorrectNonSingletonObjectId = nonSingletonObjectId + 1;
    testItems[0].smartObjectId = incorrectNonSingletonObjectId;
    testItems[0].typeId = NON_SINGLETON_TYPE_ID;
    testItems[0].itemId = 0;

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemObjectId.selector, incorrectNonSingletonObjectId)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositInventory, (smartObjectId, testItems))
    );

    // Reset to valid non-singleton values
    testItems[0].smartObjectId = nonSingletonObjectId;

    // 5. Invalid quantity (zero) for non-singleton
    testItems[0].quantity = 0; // Should be > 0 for non-singleton

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemDepositQuantity.selector, nonSingletonObjectId, 0)
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositInventory, (smartObjectId, testItems))
    );

    // Setup for successful test case
    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);

    // Singleton item
    items[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_TYPE_ID,
      itemId: SINGLETON_ITEM_ID,
      volume: 10,
      quantity: 1
    });

    // Non-singleton item
    items[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: NON_SINGLETON_TYPE_ID,
      itemId: 0,
      volume: 5,
      quantity: 5
    });

    // Check initial state - records should not exist
    assertEq(EntityRecord.getExists(singletonObjectId), false);
    assertEq(EntityRecord.getExists(singletonClassId), false);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), false);

    // Create and deposit inventory items
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositInventory, (smartObjectId, items))
    );

    // Verify records were created with correct values
    // Singleton item
    assertEq(EntityRecord.getExists(singletonObjectId), true);
    assertEq(EntityRecord.getTenantId(singletonObjectId), tenantId);
    assertEq(EntityRecord.getTypeId(singletonObjectId), SINGLETON_TYPE_ID);
    assertEq(EntityRecord.getItemId(singletonObjectId), SINGLETON_ITEM_ID);
    assertEq(EntityRecord.getVolume(singletonObjectId), 10);

    // singleton class record
    assertEq(EntityRecord.getExists(singletonClassId), true);
    assertEq(EntityRecord.getTenantId(singletonClassId), tenantId);
    assertEq(EntityRecord.getTypeId(singletonClassId), SINGLETON_TYPE_ID);
    assertEq(EntityRecord.getItemId(singletonClassId), 0);
    assertEq(EntityRecord.getVolume(singletonClassId), 10);

    // Non-singleton item
    assertEq(EntityRecord.getExists(nonSingletonObjectId), true);
    assertEq(EntityRecord.getTenantId(nonSingletonObjectId), tenantId);
    assertEq(EntityRecord.getTypeId(nonSingletonObjectId), NON_SINGLETON_TYPE_ID);
    assertEq(EntityRecord.getItemId(nonSingletonObjectId), 0);
    assertEq(EntityRecord.getVolume(nonSingletonObjectId), 5);

    vm.stopPrank();
  }

  function test_EphemeralInventory_interaction() public {
    vm.startPrank(bob, deployer);

    // Define item types for testing
    ephemeralSingletonObjectId = _calculateObjectId(SINGLETON_TYPE_ID, EPHEMERAL_ITEM_ID, true);
    ephemeralSingletonClassId = _calculateObjectId(SINGLETON_TYPE_ID, 0, false);
    nonSingletonObjectId = _calculateObjectId(NON_SINGLETON_TYPE_ID, 0, false);

    // Create a single reusable item array for revert tests
    CreateInventoryItemParams[] memory testItems = new CreateInventoryItemParams[](1);

    // Initial valid values
    testItems[0] = CreateInventoryItemParams({
      smartObjectId: ephemeralSingletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_TYPE_ID,
      itemId: EPHEMERAL_ITEM_ID,
      volume: 10,
      quantity: 1
    });

    // Test failure cases

    // 1. Invalid tenant ID for singleton
    bytes32 wrongTenantId = keccak256(abi.encodePacked("WRONG_TENANT"));
    testItems[0].tenantId = wrongTenantId;

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidTenantId.selector,
        ephemeralSingletonObjectId,
        wrongTenantId
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositEphemeral, (smartObjectId, bob, testItems))
    );

    // Reset tenant ID to valid value
    testItems[0].tenantId = tenantId;

    // 2. Invalid object ID for singleton
    uint256 incorrectSingletonObjectId = ephemeralSingletonObjectId + 1;
    testItems[0].smartObjectId = incorrectSingletonObjectId;

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemObjectId.selector,
        incorrectSingletonObjectId
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositEphemeral, (smartObjectId, bob, testItems))
    );

    // Reset to valid object ID
    testItems[0].smartObjectId = ephemeralSingletonObjectId;

    // 3. Invalid quantity for singleton
    testItems[0].quantity = 2; // Should be 1 for singleton

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemDepositQuantity.selector,
        ephemeralSingletonObjectId,
        2
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositEphemeral, (smartObjectId, bob, testItems))
    );

    // Reset to valid quantity
    testItems[0].quantity = 1;

    // 4. Invalid object ID for non-singleton
    uint256 incorrectNonSingletonObjectId = nonSingletonObjectId + 1;
    testItems[0].smartObjectId = incorrectNonSingletonObjectId;
    testItems[0].typeId = NON_SINGLETON_TYPE_ID;
    testItems[0].itemId = 0;

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemObjectId.selector,
        incorrectNonSingletonObjectId
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositEphemeral, (smartObjectId, bob, testItems))
    );

    // Reset to valid non-singleton values
    testItems[0].smartObjectId = nonSingletonObjectId;

    // 5. Invalid quantity (zero) for non-singleton
    testItems[0].quantity = 0; // Should be > 0 for non-singleton

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemDepositQuantity.selector,
        nonSingletonObjectId,
        0
      )
    );
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositEphemeral, (smartObjectId, bob, testItems))
    );

    // Setup for successful test case
    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);

    // Singleton item
    items[0] = CreateInventoryItemParams({
      smartObjectId: ephemeralSingletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_TYPE_ID,
      itemId: EPHEMERAL_ITEM_ID,
      volume: 10,
      quantity: 1
    });

    // Non-singleton item
    items[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: NON_SINGLETON_TYPE_ID,
      itemId: 0,
      volume: 5,
      quantity: 5
    });

    // Check initial state - records should not exist
    assertEq(EntityRecord.getExists(ephemeralSingletonObjectId), false);
    assertEq(EntityRecord.getExists(ephemeralSingletonClassId), false);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), false);

    // Create and deposit ephemeral inventory items
    world.call(
      mockSystemId,
      abi.encodeCall(MockEntityRecordInteractSystem.callCreateAndDepositEphemeral, (smartObjectId, bob, items))
    );

    // Verify records were created with correct values
    // Singleton item
    assertEq(EntityRecord.getExists(ephemeralSingletonObjectId), true);
    assertEq(EntityRecord.getTenantId(ephemeralSingletonObjectId), tenantId);
    assertEq(EntityRecord.getTypeId(ephemeralSingletonObjectId), SINGLETON_TYPE_ID);
    assertEq(EntityRecord.getItemId(ephemeralSingletonObjectId), EPHEMERAL_ITEM_ID);
    assertEq(EntityRecord.getVolume(ephemeralSingletonObjectId), 10);

    // ephermaral singleton class record
    assertEq(EntityRecord.getExists(ephemeralSingletonClassId), true);
    assertEq(EntityRecord.getTenantId(ephemeralSingletonClassId), tenantId);
    assertEq(EntityRecord.getTypeId(ephemeralSingletonClassId), SINGLETON_TYPE_ID);
    assertEq(EntityRecord.getItemId(ephemeralSingletonClassId), 0);
    assertEq(EntityRecord.getVolume(ephemeralSingletonClassId), 10);

    // Non-singleton item
    assertEq(EntityRecord.getExists(nonSingletonObjectId), true);
    assertEq(EntityRecord.getTenantId(nonSingletonObjectId), tenantId);
    assertEq(EntityRecord.getTypeId(nonSingletonObjectId), NON_SINGLETON_TYPE_ID);
    assertEq(EntityRecord.getItemId(nonSingletonObjectId), 0);
    assertEq(EntityRecord.getVolume(nonSingletonObjectId), 5);

    vm.stopPrank();
  }

  // Helper function to setup item records
  function _setupEntityRecord(uint256 entityId, uint256 typeId, uint256 itemId, uint256 volume) internal {
    uint256 classId = uint256(keccak256(abi.encodePacked(tenantId, typeId)));

    if (itemId != 0) {
      // For singleton items
      EntityRecord.set(entityId, true, tenantId, typeId, itemId, volume);

      if (!EntityRecord.getExists(classId)) {
        EntityRecord.set(classId, true, tenantId, typeId, 0, volume);
      }
    } else {
      // For non-singleton items
      EntityRecord.set(classId, true, tenantId, typeId, 0, volume);
    }

    if (!Entity.getExists(classId)) {
      entitySystem.registerClass(classId, new ResourceId[](0));
    }
  }

  // Helper function to calculate itemObjectId
  function _calculateObjectId(uint256 typeId, uint256 itemId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}
