// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { Fuel, Tenant, EntityRecord, EntityRecordData, DeployableState, DeployableStateData, CharactersByAccount, LocationData, SmartAssembly, Location, NetworkNode, NetworkNodeData, NetworkNodeAssemblyLink, AssemblyEnergyConfig, FuelEfficiencyConfig, FuelConsumptionState } from "../../src/namespaces/evefrontier/codegen/index.sol";

import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { NetworkNodeSystem, networkNodeSystem } from "../../src/namespaces/evefrontier/codegen/systems/NetworkNodeSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { SmartGateSystem, smartGateSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { SmartTurretSystem, smartTurretSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";

import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { FuelParams } from "../../src/namespaces/evefrontier/systems/fuel/types.sol";

contract NetworkNodeEnergyTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Item variables
  bytes32 tenantId;

  // Test addresses
  address deployer;
  address alice;

  uint256 constant NETWORK_NODE_ID = 1234;
  uint256 constant SMART_GATE_ID = 1235;
  uint256 constant SMART_STORAGE_ID = 1236;
  uint256 constant SMART_TURRET_ID = 1237;

  uint256 networkNodeId;
  uint256 smartGateId;
  uint256 smartStorageId;
  uint256 smartTurretId;
  uint256 fuelSmartObjectId;

  // Location data
  LocationData locationParams;

  // Entity record params
  EntityRecordParams entityRecordParams;
  EntityRecordParams fuelEntityRecordParams;

  // Fuel params
  FuelParams fuelParams;

  // Assembly Type IDs
  uint256 constant NETWORK_NODE_TYPE_ID = 88092;
  uint256 constant SMART_GATE_TYPE_ID = 84955;
  uint256 constant SMART_STORAGE_UNIT_TYPE_ID = 77917;
  uint256 constant SMART_TURRET_TYPE_ID = 84556;

  uint256 constant FUEL_TYPE_ID = 1;

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

    // Mock smart character data for alice
    CharactersByAccount.set(alice, 1);

    // Setup tenant
    tenantId = Tenant.get();

    // Setup smart object IDs
    networkNodeId = _calculateObjectId(
      EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
      NETWORK_NODE_ID,
      true
    );

    smartGateId = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      SMART_GATE_ID,
      true
    );

    smartStorageId = _calculateObjectId(
      EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
      SMART_STORAGE_ID,
      true
    );

    smartTurretId = _calculateObjectId(
      EntityRecord.getTypeId(smartTurretSystem.getSmartTurretClassId()),
      SMART_TURRET_ID,
      true
    );

    fuelSmartObjectId = _calculateObjectId(FUEL_TYPE_ID, 0, false);

    locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
      itemId: NETWORK_NODE_ID,
      volume: 100
    });

    fuelEntityRecordParams = EntityRecordParams({ tenantId: tenantId, typeId: FUEL_TYPE_ID, itemId: 0, volume: 100 });

    // Setup fuel parameters for Type B fuel (10/hr consumption, 10 GJ output)
    fuelParams = FuelParams({
      fuelMaxCapacity: 10000,
      fuelBurnRateInSeconds: 3600 // 1 hour
    });

    // Configure fuel efficiency for type 1 (100% efficiency)
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);

    // Configure energy requirements for different assembly types
    AssemblyEnergyConfig.setEnergyConstant(NETWORK_NODE_TYPE_ID, 10); // Network Node requires 10 GJ
    AssemblyEnergyConfig.setEnergyConstant(SMART_GATE_TYPE_ID, 50); // Smart Gate requires 50 GJ
    AssemblyEnergyConfig.setEnergyConstant(SMART_STORAGE_UNIT_TYPE_ID, 30); // Smart Storage Unit requires 30 GJ
    AssemblyEnergyConfig.setEnergyConstant(SMART_TURRET_TYPE_ID, 40); // Smart Turret requires 40 GJ

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_networkNodeDeploymentAndOperation() public {
    vm.startPrank(deployer, deployer);

    // 1. Deploy and anchor Network Node
    networkNodeSystem.createAndAnchorNetworkNode(
      CreateAndAnchorParams({
        smartObjectId: networkNodeId,
        assemblyType: "NWN",
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
          itemId: NETWORK_NODE_ID,
          volume: 100
        }),
        owner: alice,
        locationData: LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      }),
      fuelParams,
      80, // maxEnergyCapacity
      80 // currentProduction
    );

    // Verify Network Node is created and anchored
    assertTrue(NetworkNode.getExists(networkNodeId), "Network Node should exist");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ANCHORED),
      "Network Node should be anchored"
    );

    // 2. Deposit fuel and bring Network Node online (should automatically start burning fuel)
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    // Verify Network Node is online and consuming its own energy
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertTrue(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be active");
    assertEq(NetworkNode.getEnergyProduced(networkNodeId), 80, "Should be producing 80 GJ");
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 10, "Total reserved energy should be 10 GJ");
    assertEq(Fuel.getFuelAmount(networkNodeId), 9, "Fuel amount should be 9 units");

    vm.stopPrank();
  }

  function test_assemblyDeploymentAndEnergyManagement() public {
    vm.pauseGasMetering();
    // First setup a running Network Node
    test_networkNodeDeploymentAndOperation();

    vm.startPrank(deployer, deployer);

    // 1. Deploy and connect Smart Gate
    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams({
        smartObjectId: smartGateId,
        owner: alice,
        locationData: locationParams,
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
          itemId: SMART_GATE_ID,
          volume: 100
        }),
        assemblyType: "SG"
      }),
      10, // maxDistance
      networkNodeId
    );

    // Verify Smart Gate is connected
    assertTrue(NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartGateId), "Smart Gate should be connected");

    // Verify connectedAssemblies array after connecting Smart Gate
    uint256[] memory connectedAssemblies = NetworkNode.getConnectedAssemblies(networkNodeId);
    assertEq(connectedAssemblies.length, 1, "Should have 1 connected assembly");
    assertEq(connectedAssemblies[0], smartGateId, "Connected assembly should be Smart Gate");

    // 2. Try to bring Smart Gate online (should succeed as Network Node has enough energy)
    deployableSystem.bringOnline(smartGateId);

    // Verify Smart Gate is online and energy is reserved
    assertEq(uint8(DeployableState.getCurrentState(smartGateId)), uint8(State.ONLINE), "Smart Gate should be online");
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 60, "Total reserved energy should be 60 GJ (10 + 50)");

    // 3. Deploy Smart Storage Unit (should connect but fail to come online due to insufficient energy)
    smartStorageUnitSystem.createAndAnchorStorageUnit(
      CreateAndAnchorParams({
        smartObjectId: smartStorageId,
        owner: alice,
        locationData: locationParams,
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
          itemId: SMART_STORAGE_ID,
          volume: 100
        }),
        assemblyType: "SSU"
      }),
      1000, // storage capacity
      1000, // ephemeral capacity
      networkNodeId
    );

    // Verify Smart Storage Unit is connected but not online
    assertTrue(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be connected"
    );

    // Verify connectedAssemblies array after connecting Smart Storage Unit
    connectedAssemblies = NetworkNode.getConnectedAssemblies(networkNodeId);
    assertEq(connectedAssemblies.length, 2, "Should have 2 connected assemblies");
    assertEq(connectedAssemblies[0], smartGateId, "First connected assembly should be Smart Gate");
    assertEq(connectedAssemblies[1], smartStorageId, "Second connected assembly should be Smart Storage Unit");

    // Try to bring Smart Storage Unit online (should fail as only 40 GJ available)
    vm.expectRevert(
      abi.encodeWithSelector(NetworkNodeSystem.NetworkNode_InsufficientEnergy.selector, networkNodeId, 30, 20)
    );
    deployableSystem.bringOnline(smartStorageId);

    // Advance time
    vm.warp(block.timestamp + 3600);

    // Update fuel status
    fuelSystem.updateFuel(networkNodeId);

    //Check the remaining fuel
    assertEq(Fuel.getFuelAmount(networkNodeId), 8, "Fuel amount should be 8");

    // Advance time to consume remaining fuel
    vm.warp(block.timestamp + (3600 * 8));

    // Update fuel status
    fuelSystem.updateFuel(networkNodeId);

    //Check the remaining fuel
    assertEq(Fuel.getFuelAmount(networkNodeId), 0, "Fuel amount should be 0");

    // Verify Network Node and all assemblies are offline
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ANCHORED),
      "Network Node should be offline"
    );
    assertFalse(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be stopped");
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 0, "No energy should be reserved");

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  // Helper function to calculate itemObjectId
  function _calculateObjectId(uint256 typeId, uint256 itemId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}
