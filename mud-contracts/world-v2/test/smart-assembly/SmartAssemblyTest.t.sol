// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIdInstance } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, EntityRecordData, EntityRecordMetadata, EntityRecordMetadataData, CharactersByAccount, LocationData, EphemeralInventory, SmartAssembly, Fuel, Location } from "../../src/namespaces/evefrontier/codegen/index.sol";

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

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Create a mock system to properly test system-to-system calls
contract MockSmartAssemblyInteractSystem is System {
  function callCreateSmartAssembly(
    uint256 smartObjectId,
    string memory assemblyType,
    EntityRecordParams memory entityRecordParams
  ) public {
    smartAssemblySystem.createAssembly(smartObjectId, assemblyType, entityRecordParams);
  }

  function callCreateAndAnchor(CreateAndAnchorParams memory params) public {
    deployableSystem.createAndAnchor(params);
  }
}

contract SmartAssemblyTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 objectClassId;
  uint256 smartObjectId;
  uint256 deployableSmartObjectId;
  bytes32 tenantId;

  // Smart Object Entity Record variables
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant DEPLOYABLE_OBJECT_ID = 1236;

  EntityRecordParams entityRecordParams;

  EntityRecordParams deployableEntityRecordParams;
  LocationData locationDataParams;
  CreateAndAnchorParams createAndAnchorParams;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  // Mock system address
  MockSmartAssemblyInteractSystem mockSystem;
  ResourceId mockSystemId;

  function setUp() public virtual override {
    vm.pauseGasMetering();
    super.setUp();
    // Deploy a new World
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // Initialize addresses
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));
    alice = vm.addr(vm.deriveKey(mnemonic, 2));
    bob = vm.addr(vm.deriveKey(mnemonic, 3));

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice
    CharactersByAccount.set(alice, 1);

    // Setup tenant
    tenantId = Tenant.get();

    // Setup smart object ID
    smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);
    deployableSmartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, DEPLOYABLE_OBJECT_ID, true);
    // setup smart object class id
    objectClassId = _calculateObjectId(SMART_OBJECT_TYPE_ID, 0, false);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("MockSmartAssembl");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockSmartAssemblyInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = ownershipSystem.toResourceId();
    systemIds[6] = mockSystemId;

    entitySystem.registerClass(objectClassId, systemIds); // tags the systems to this class for scoping
    _setupEntityRecord(objectClassId, SMART_OBJECT_TYPE_ID, 0, 1000);

    // instantiate the mock smart object
    entitySystem.instantiate(objectClassId, smartObjectId, alice);

    // instantiate the deployable smart object
    entitySystem.instantiate(objectClassId, deployableSmartObjectId, alice);

    // set test parameters
    // generic
    entityRecordParams = EntityRecordParams(tenantId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    // deploable interaction specific
    deployableEntityRecordParams = EntityRecordParams(tenantId, SMART_OBJECT_TYPE_ID, DEPLOYABLE_OBJECT_ID, 1000);
    locationDataParams = LocationData(1, 1001, 1002, 1003);
    createAndAnchorParams = CreateAndAnchorParams(
      deployableSmartObjectId,
      "Deployable",
      deployableEntityRecordParams,
      alice,
      10,
      60,
      100000000,
      locationDataParams
    );

    vm.stopPrank();
  }

  function test_createSmartAssembly() public {
    // sanity check reverts are being handled in the EntityRecordTest SmartAssembly interaction test

    EntityRecordData memory entityRecordData = EntityRecord.get(smartObjectId);

    assertEq(entityRecordData.tenantId, 0);
    assertEq(entityRecordData.typeId, 0);
    assertEq(entityRecordData.itemId, 0);
    assertEq(entityRecordData.volume, 0);

    assertEq(SmartAssembly.get(smartObjectId), "");

    vm.startPrank(deployer);
    world.call(
      mockSystemId,
      abi.encodeCall(mockSystem.callCreateSmartAssembly, (smartObjectId, "ASSEMBLY", entityRecordParams))
    );
    vm.stopPrank();

    entityRecordData = EntityRecord.get(smartObjectId);

    assertEq(entityRecordData.tenantId, tenantId);
    assertEq(entityRecordData.typeId, SMART_OBJECT_TYPE_ID);
    assertEq(entityRecordData.itemId, SMART_OBJECT_ID);
    assertEq(entityRecordData.volume, 1000);

    assertEq(SmartAssembly.get(smartObjectId), "ASSEMBLY");
  }

  function test_Deployable_interaction() public {
    // to test that smart assembly data is tracked independently pre smart object currently let's call createAssembly for our defualt object first
    vm.startPrank(deployer);
    world.call(
      mockSystemId,
      abi.encodeCall(mockSystem.callCreateSmartAssembly, (smartObjectId, "ASSEMBLY", entityRecordParams))
    );
    vm.stopPrank();

    // check data for our deployable smart object (not the generic smart object)
    EntityRecordData memory entityRecordData = EntityRecord.get(deployableSmartObjectId);

    assertEq(entityRecordData.tenantId, 0);
    assertEq(entityRecordData.typeId, 0);
    assertEq(entityRecordData.itemId, 0);
    assertEq(entityRecordData.volume, 0);

    assertEq(SmartAssembly.get(deployableSmartObjectId), "");

    vm.startPrank(alice, deployer);
    world.call(mockSystemId, abi.encodeCall(mockSystem.callCreateAndAnchor, (createAndAnchorParams)));
    vm.stopPrank();

    entityRecordData = EntityRecord.get(deployableSmartObjectId);

    assertEq(entityRecordData.tenantId, tenantId);
    assertEq(entityRecordData.typeId, SMART_OBJECT_TYPE_ID);
    assertEq(entityRecordData.itemId, DEPLOYABLE_OBJECT_ID);
    assertEq(entityRecordData.volume, 1000);

    assertEq(SmartAssembly.get(deployableSmartObjectId), "Deployable");
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
