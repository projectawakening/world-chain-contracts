// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

// MUD imports
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
// for the custom interact system
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { Role, HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace tables
import { Inventory, InventoryData, Tenant, EntityRecord, EntityRecordData, DeployableState, DeployableStateData, InventoryItemData, InventoryItem, EphemeralInvCapacity, CharactersByAccount, SmartAssembly, Fuel, FuelData, Location, LocationData } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { EphemeralInteractSystem, ephemeralInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { InventoryInteractSystem, inventoryInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

contract SmartStorageUnitTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Item variables
  bytes32 tenantId;

  // Test addresses
  address deployer;
  address alice;

  uint256 constant SMART_OBJECT_ID = 1234;

  uint256 smartObjectId;

  // Location data
  LocationData locationParams;

  //entity record
  EntityRecordParams entityRecordParams;

  uint256 fuelUnitVolume = 10;
  uint256 fuelConsumptionIntervalInSeconds = 60;
  uint256 fuelMaxCapacity = 1000000;

  function setUp() public virtual override {
    vm.pauseGasMetering();
    // Deploy a new World
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // Initialize addresses
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));
    alice = vm.addr(vm.deriveKey(mnemonic, 2));

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice and bob
    CharactersByAccount.set(alice, 1);

    // Setup tenant
    tenantId = Tenant.get();

    // Setup smart object IDs
    smartObjectId = _calculateObjectId(
      EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
      SMART_OBJECT_ID,
      true
    );

    locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
      itemId: SMART_OBJECT_ID,
      volume: 1000
    });

    vm.stopPrank();

    // allow global resume for deployable activity
    vm.prank(deployer);
    deployableSystem.globalResume();
    vm.resumeGasMetering();
  }

  // all internal system checks, behavior and revert tests are done in DeployableTest, SmartAssemblyTest, FuelTest, EntityRecordTest, and InventoryTest

  function test_createAndAncorStorageUnit() public {
    vm.pauseGasMetering();
    // check entity record data before creating and anchoring
    assertEq(EntityRecord.getExists(smartObjectId), false);

    // smart assembly data before creating and anchoring
    assertEq(
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))),
      keccak256(abi.encodePacked(""))
    );

    // check deployable data before creating and anchoring
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);

    assertEq(deployableStateData.createdAt, 0);
    assertEq(uint8(deployableStateData.previousState), uint8(State.NULL));
    assertEq(uint8(deployableStateData.currentState), uint8(State.NULL));
    assertEq(deployableStateData.isValid, false);
    assertEq(deployableStateData.anchoredAt, 0);
    assertEq(deployableStateData.updatedBlockNumber, 0);
    assertEq(deployableStateData.updatedBlockTime, 0);

    // check fuel data before creating and anchoring
    FuelData memory fuelData = Fuel.get(smartObjectId);
    assertEq(fuelData.fuelUnitVolume, 0);
    assertEq(fuelData.fuelConsumptionIntervalInSeconds, 0);
    assertEq(fuelData.fuelMaxCapacity, 0);

    // check ownership data before creating and anchoring
    address owner = ownershipSystem.owner(smartObjectId);
    assertEq(owner, address(0));

    // check location data before creating and anchoring
    LocationData memory locationData = Location.get(smartObjectId);
    assertEq(locationData.solarSystemId, 0);
    assertEq(locationData.x, 0);
    assertEq(locationData.y, 0);
    assertEq(locationData.z, 0);

    InventoryData memory inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.capacity, 0);
    assertEq(inventoryData.version, 0);
    assertEq(EphemeralInvCapacity.get(smartObjectId), 0);

    vm.startPrank(alice, deployer);
    // create and anchor source gate
    world.call(
      smartStorageUnitSystem.toResourceId(),
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorStorageUnit,
        (
          CreateAndAnchorParams(
            smartObjectId,
            "SSU",
            entityRecordParams,
            alice,
            fuelUnitVolume,
            fuelConsumptionIntervalInSeconds,
            fuelMaxCapacity,
            locationParams
          ),
          1000,
          1000
        )
      )
    );
    vm.stopPrank();

    // check entity record data before creating and anchoring
    assertEq(EntityRecord.getExists(smartObjectId), true);

    EntityRecordData memory entityRecordData = EntityRecord.get(smartObjectId);
    assertEq(entityRecordData.tenantId, tenantId);
    assertEq(entityRecordData.typeId, EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()));
    assertEq(entityRecordData.itemId, SMART_OBJECT_ID);
    assertEq(entityRecordData.volume, 1000);

    // smart assembly data before creating and anchoring
    assertEq(
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))),
      keccak256(abi.encodePacked("SSU"))
    );

    // check deployable data before creating and anchoring
    deployableStateData = DeployableState.get(smartObjectId);

    assertEq(deployableStateData.createdAt, block.timestamp);
    assertEq(uint8(deployableStateData.previousState), uint8(State.UNANCHORED));
    assertEq(uint8(deployableStateData.currentState), uint8(State.ANCHORED));
    assertEq(deployableStateData.isValid, true);
    assertEq(deployableStateData.anchoredAt, block.timestamp);
    assertEq(deployableStateData.updatedBlockNumber, block.number);
    assertEq(deployableStateData.updatedBlockTime, block.timestamp);

    // check fuel data before creating and anchoring
    fuelData = Fuel.get(smartObjectId);
    assertEq(fuelData.fuelUnitVolume, fuelUnitVolume);
    assertEq(fuelData.fuelConsumptionIntervalInSeconds, fuelConsumptionIntervalInSeconds);
    assertEq(fuelData.fuelMaxCapacity, fuelMaxCapacity);

    // check ownership data before creating and anchoring
    owner = ownershipSystem.owner(smartObjectId);
    assertEq(owner, alice);

    // check location data before creating and anchoring
    locationData = Location.get(smartObjectId);
    assertEq(locationData.solarSystemId, locationParams.solarSystemId);
    assertEq(locationData.x, locationParams.x);
    assertEq(locationData.y, locationParams.y);
    assertEq(locationData.z, locationParams.z);

    inventoryData = Inventory.get(smartObjectId);
    assertEq(inventoryData.capacity, 1000);
    assertEq(inventoryData.version, 1);
    assertEq(EphemeralInvCapacity.get(smartObjectId), 1000);
    vm.resumeGasMetering();
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
