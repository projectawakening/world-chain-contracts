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
import { Inventory, Tenant, EntityRecord, EntityRecordData, EntityRecordMetadata, EntityRecordMetadataData, DeployableState, CharactersByAccount, LocationData, EphemeralInventory, SmartAssembly, Fuel, Location } from "../../src/namespaces/evefrontier/codegen/index.sol";

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
contract MockLocationInteractSystem is System {
  function callSaveLocation(uint256 smartObjectId, LocationData memory location) public {
    locationSystem.saveLocation(smartObjectId, location);
  }

  function callCreateAndAnchor(CreateAndAnchorParams memory params) public {
    deployableSystem.createAndAnchor(params);
  }

  function callAnchor(uint256 smartObjectId, address owner, LocationData memory location) public {
    deployableSystem.anchor(smartObjectId, owner, location);
  }

  function callUnanchor(uint256 smartObjectId) public {
    deployableSystem.unanchor(smartObjectId);
  }
}

contract LocationTest is MudTest {
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

  CreateAndAnchorParams createAndAnchorParams;
  LocationData locationDataParams;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  // Mock system address
  MockLocationInteractSystem mockSystem;
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
    bytes16 name = bytes16("MockLocationInte");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockLocationInteractSystem();

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

    entitySystem.registerClass(objectClassId, systemIds); // tags the system to this class for scoping
    _setupEntityRecord(objectClassId, SMART_OBJECT_TYPE_ID, 0, 1000);

    // instantiate the smart object
    entitySystem.instantiate(objectClassId, smartObjectId, alice);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);

    entitySystem.instantiate(objectClassId, deployableSmartObjectId, alice);

    // set test parameters
    locationDataParams = LocationData(1, 1001, 1002, 1003);

    // mock Deployable state UNANCHORED for raw location system testing
    DeployableState.set(
      smartObjectId,
      block.timestamp,
      State.NULL,
      State.UNANCHORED,
      true,
      0,
      block.number,
      block.timestamp
    );
    vm.stopPrank();

    vm.startPrank(alice, deployer);
    // create and anchor deploybale for interaction testing
    createAndAnchorParams = CreateAndAnchorParams(
      deployableSmartObjectId,
      "Deployable",
      EntityRecordParams(tenantId, SMART_OBJECT_TYPE_ID, DEPLOYABLE_OBJECT_ID, 1000),
      alice,
      10,
      60,
      100000000,
      locationDataParams
    );
    vm.stopPrank();
  }

  function test_saveLocation() public {
    LocationData memory locationData = Location.get(smartObjectId);

    assertEq(locationData.solarSystemId, 0);
    assertEq(locationData.x, 0);
    assertEq(locationData.y, 0);
    assertEq(locationData.z, 0);

    vm.startPrank(deployer);
    world.call(mockSystemId, abi.encodeCall(mockSystem.callSaveLocation, (smartObjectId, locationDataParams)));
    vm.stopPrank();

    locationData = Location.get(smartObjectId);

    assertEq(locationDataParams.solarSystemId, locationData.solarSystemId);
    assertEq(locationDataParams.x, locationData.x);
    assertEq(locationDataParams.y, locationData.y);
    assertEq(locationDataParams.z, locationData.z);
  }

  function test_deployable_interaction() public {
    LocationData memory locationData = Location.get(deployableSmartObjectId);
    assertEq(locationData.solarSystemId, 0);
    assertEq(locationData.x, 0);
    assertEq(locationData.y, 0);
    assertEq(locationData.z, 0);

    vm.startPrank(alice, deployer);
    world.call(mockSystemId, abi.encodeCall(mockSystem.callCreateAndAnchor, (createAndAnchorParams)));
    vm.stopPrank();

    locationData = Location.get(deployableSmartObjectId);
    assertEq(locationData.solarSystemId, locationDataParams.solarSystemId);
    assertEq(locationData.x, locationDataParams.x);
    assertEq(locationData.y, locationDataParams.y);
    assertEq(locationData.z, locationDataParams.z);

    vm.startPrank(alice, deployer);
    world.call(mockSystemId, abi.encodeCall(mockSystem.callUnanchor, (deployableSmartObjectId)));
    vm.stopPrank();

    locationData = Location.get(deployableSmartObjectId);
    assertEq(locationData.solarSystemId, 0);
    assertEq(locationData.x, 0);
    assertEq(locationData.y, 0);
    assertEq(locationData.z, 0);
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
