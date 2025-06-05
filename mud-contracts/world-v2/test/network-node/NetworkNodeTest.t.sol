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
  uint256 constant PORTABLE_REFINERY_ID = 1238;

  uint256 networkNodeId;
  uint256 smartGateId;
  uint256 smartStorageId;
  uint256 smartTurretId;
  uint256 portableRefineryId;
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
  uint256 constant SMART_TURRET_TYPE_ID = 84556;
  uint256 constant SSU_TYPE_ID = 77917;
  uint256 constant SMART_GATE_TYPE_ID = 84955;
  uint256 constant REFINERY_TYPE_ID = 88086;

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

    smartGateId = _calculateObjectId(SMART_GATE_TYPE_ID, SMART_GATE_ID, true);

    smartStorageId = _calculateObjectId(SSU_TYPE_ID, SMART_STORAGE_ID, true);

    smartTurretId = _calculateObjectId(SMART_TURRET_TYPE_ID, SMART_TURRET_ID, true);

    portableRefineryId = _calculateObjectId(REFINERY_TYPE_ID, PORTABLE_REFINERY_ID, true);

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
    AssemblyEnergyConfig.setEnergyConstant(SSU_TYPE_ID, 30); // Smart Storage Unit requires 30 GJ
    AssemblyEnergyConfig.setEnergyConstant(SMART_TURRET_TYPE_ID, 40); // Smart Turret requires 40 GJ

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_networkNodeDeploymentAndOperation() public {
    vm.startPrank(deployer, deployer);

    // 1. Deploy and anchor Network Node
    _setupNetworkNode(80, 80);

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
    _setupSmartGate(smartGateId);

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
    _setupSmartStorageUnit(smartStorageId);

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

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_OutOfEnergy() public {
    test_assemblyDeploymentAndEnergyManagement();

    vm.startPrank(deployer, deployer);
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

    // Verify Smart Gate is offline
    assertEq(
      uint8(DeployableState.getCurrentState(smartGateId)),
      uint8(State.ANCHORED),
      "Smart Gate should be offline"
    );

    // Verify Smart Storage Unit is offline
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ANCHORED),
      "Smart Storage Unit should be offline"
    );

    vm.stopPrank();
  }

  function test_destroyConnectedAssembly() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    // Setup Network Node and bring it online
    _setupNetworkNode(90, 90);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    _setupSmartGate(smartGateId);
    deployableSystem.bringOnline(smartGateId);

    // Verify initial state
    assertTrue(NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartGateId), "Smart Gate should be connected");
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 60, "Total reserved energy should be 60 GJ");
    assertEq(uint8(DeployableState.getCurrentState(smartGateId)), uint8(State.ONLINE), "Smart Gate should be online");

    // Destroy the Smart Gate
    deployableSystem.destroyDeployable(smartGateId);

    // Verify Smart Gate is destroyed and disconnected
    assertFalse(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartGateId),
      "Smart Gate should be disconnected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 10, "Total reserved energy should be 10 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(smartGateId)),
      uint8(State.DESTROYED),
      "Smart Gate should be destroyed"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(
      NetworkNode.getConnectedAssemblies(networkNodeId).length,
      0,
      "Network Node should have no connected assemblies"
    );

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_unanchorConnectedAssembly() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    // Setup Network Node and Smart Storage Unit
    _setupNetworkNode(90, 90);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    _setupSmartStorageUnit(smartStorageId);
    deployableSystem.bringOnline(smartStorageId);

    // Verify initial state
    assertTrue(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be connected"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ONLINE),
      "Smart Storage Unit should be online"
    );
    vm.stopPrank();

    // Unanchor the Smart Storage Unit
    vm.prank(alice, deployer);
    deployableSystem.unanchor(smartStorageId);
    vm.stopPrank();

    // Verify Smart Storage Unit is unanchored and disconnected
    assertFalse(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be disconnected"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.UNANCHORED),
      "Smart Storage Unit should be unanchored"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 10, "Total reserved energy should be 10 GJ");

    vm.resumeGasMetering();
  }

  function test_destroyNetworkNodeWithAssemblies() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    // Setup Network Node and Smart Storage Unit
    _setupNetworkNode(90, 90);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    _setupSmartStorageUnit(smartStorageId);
    deployableSystem.bringOnline(smartStorageId);

    // Verify initial state
    assertTrue(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be connected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 40, "Total reserved energy should be 40 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ONLINE),
      "Smart Storage Unit should be online"
    );

    // Destroy the Network Node
    deployableSystem.destroyDeployable(networkNodeId);

    // Verify Network Node is destroyed and all assemblies are offline
    assertFalse(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be disconnected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 0, "Total reserved energy should be 0 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.DESTROYED),
      "Network Node should be destroyed"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ANCHORED),
      "Smart Storage Unit should be anchored"
    );
    assertFalse(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be stopped");

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_unanchorNetworkNodeWithAssemblies() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    // Setup Network Node and Smart Storage Unit
    _setupNetworkNode(90, 90);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    _setupSmartStorageUnit(smartStorageId);
    deployableSystem.bringOnline(smartStorageId);
    vm.stopPrank();

    // Verify initial state
    assertTrue(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be connected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 40, "Total reserved energy should be 40 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ONLINE),
      "Smart Storage Unit should be online"
    );

    // Unanchor the Network Node (using deployer who is the owner)
    vm.prank(alice, deployer);
    deployableSystem.unanchor(networkNodeId);
    vm.stopPrank();

    // Verify Network Node is unanchored and all assemblies are offline
    assertFalse(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be disconnected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 0, "Total reserved energy should be 0 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.UNANCHORED),
      "Network Node should be unanchored"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ANCHORED),
      "Smart Storage Unit should be offline"
    );
    assertFalse(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be stopped");

    vm.resumeGasMetering();
  }

  function test_connectOrphanedAssembliesWithNewNetworkNode() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    uint256 newNetworkNodeId = _calculateObjectId(
      EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
      NETWORK_NODE_ID + 1,
      true
    );
    networkNodeSystem.createAndAnchorNetworkNode(
      CreateAndAnchorParams({
        smartObjectId: newNetworkNodeId,
        assemblyType: "NWN",
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
          itemId: NETWORK_NODE_ID + 1,
          volume: 100
        }),
        owner: alice,
        locationData: LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      }),
      fuelParams,
      90,
      90
    );

    // Setup Network Node and Smart Storage Unit
    _setupNetworkNode(90, 90);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    _setupSmartStorageUnit(smartStorageId);
    deployableSystem.bringOnline(smartStorageId);

    // Verify initial state
    assertTrue(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be connected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 40, "Total reserved energy should be 40 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ONLINE),
      "Smart Storage Unit should be online"
    );

    // Unanchor the Network Node (using deployer who is the owner)
    deployableSystem.unanchor(networkNodeId);

    // Verify Network Node is unanchored and all assemblies are offline
    assertFalse(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      "Smart Storage Unit should be disconnected"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 0, "Total reserved energy should be 0 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.UNANCHORED),
      "Network Node should be unanchored"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ANCHORED),
      "Smart Storage Unit should be offline"
    );
    assertFalse(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be stopped");

    //Set up new network node and connect the orphaned assemblies
    uint256[] memory assemblyIds = new uint256[](1);
    assemblyIds[0] = smartStorageId;
    networkNodeSystem.connectAssemblies(newNetworkNodeId, assemblyIds);

    // Verify the assemblies are connected to the new network node
    assertEq(NetworkNode.getConnectedAssemblies(newNetworkNodeId).length, 1, "New network node should have 1 assembly");
    assertEq(
      NetworkNode.getConnectedAssemblies(newNetworkNodeId)[0],
      smartStorageId,
      "Smart Storage Unit should be connected to the new network node"
    );
    assertEq(
      NetworkNodeAssemblyLink.getIsConnected(newNetworkNodeId, smartStorageId),
      true,
      "Smart Storage Unit should be connected to the new network node"
    );
    assertEq(
      NetworkNodeAssemblyLink.getConnectedAssemblyIndex(newNetworkNodeId, smartStorageId),
      0,
      "Smart Storage Unit should be connected to the new network node"
    );
    assertEq(
      NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartStorageId),
      false,
      "Smart Storage Unit should be disconnected from the old network node"
    );

    // Bring online and check the fuel consumption
    fuelSystem.depositFuel(newNetworkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(newNetworkNodeId);
    deployableSystem.bringOnline(smartStorageId);

    assertEq(NetworkNode.getTotalReservedEnergy(newNetworkNodeId), 40, "Total reserved energy should be 40 GJ");
    assertEq(
      uint8(DeployableState.getCurrentState(newNetworkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ONLINE),
      "Smart Storage Unit should be online"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.UNANCHORED),
      "Network Node should be unanchored"
    );

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_invalidOrphansConnection() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    uint256 newNetworkNodeId = _calculateObjectId(
      EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
      NETWORK_NODE_ID + 1,
      true
    );
    networkNodeSystem.createAndAnchorNetworkNode(
      CreateAndAnchorParams({
        smartObjectId: newNetworkNodeId,
        assemblyType: "NWN",
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(networkNodeSystem.getNetworkNodeClassId()),
          itemId: NETWORK_NODE_ID + 1,
          volume: 100
        }),
        owner: alice,
        locationData: LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      }),
      fuelParams,
      90,
      90
    );

    // Setup Network Node and Smart Storage Unit
    _setupNetworkNode(90, 90);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(networkNodeId);

    _setupSmartStorageUnit(smartStorageId);
    deployableSystem.bringOnline(smartStorageId);

    assertEq(NetworkNode.getConnectedAssemblies(networkNodeId).length, 1, "Network node should have 1 assembly");
    assertEq(NetworkNode.getConnectedAssemblies(newNetworkNodeId).length, 0, "New network node should have 0 assembly");

    //Skip the connection if its already connected
    uint256[] memory assemblyIds = new uint256[](1);
    assemblyIds[0] = smartStorageId;
    networkNodeSystem.connectAssemblies(newNetworkNodeId, assemblyIds);

    assertEq(NetworkNode.getConnectedAssemblies(newNetworkNodeId).length, 0, "New network node should have 0 assembly");

    //Skip the connection if its a network node
    assemblyIds[0] = networkNodeId;
    networkNodeSystem.connectAssemblies(newNetworkNodeId, assemblyIds);
    assertEq(NetworkNode.getConnectedAssemblies(newNetworkNodeId).length, 0, "New network node should have 0 assembly");

    // Unanchor the Network Node (using deployer who is the owner)
    deployableSystem.unanchor(networkNodeId);
    assertEq(NetworkNode.getConnectedAssemblies(networkNodeId).length, 0, "Network node should have 0 assembly");

    // Verify Network Node is unanchored and all assemblies are offline
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.UNANCHORED),
      "Network Node should be unanchored"
    );

    //Set up new network node and connect the orphaned assemblies, skip if its network node
    assemblyIds = new uint256[](2);
    assemblyIds[0] = smartStorageId;
    assemblyIds[1] = networkNodeId;

    networkNodeSystem.connectAssemblies(newNetworkNodeId, assemblyIds);

    // Verify the assemblies are connected to the new network node
    assertEq(NetworkNode.getConnectedAssemblies(newNetworkNodeId).length, 1, "New network node should have 1 assembly");
    assertEq(
      NetworkNodeAssemblyLink.getIsConnected(newNetworkNodeId, smartStorageId),
      true,
      "Smart Storage Unit should be connected to the new network node"
    );

    //Work as expected
    fuelSystem.depositFuel(newNetworkNodeId, fuelSmartObjectId, 10);
    deployableSystem.bringOnline(newNetworkNodeId);
    deployableSystem.bringOnline(smartStorageId);

    assertEq(
      uint8(DeployableState.getCurrentState(newNetworkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartStorageId)),
      uint8(State.ONLINE),
      "Smart Storage Unit should be online"
    );
    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_networkNodeOnlineOfflineCycle() public {
    vm.startPrank(deployer, deployer);

    // Setup Network Node with 100 GJ capacity and 100 GJ production
    _setupNetworkNode(100, 100);

    // Deposit initial fuel
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);

    // 1. Bring Network Node online (should start burning fuel)
    deployableSystem.bringOnline(networkNodeId);

    // Verify initial state
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertTrue(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be active");
    assertEq(Fuel.getFuelAmount(networkNodeId), 9, "Initial fuel amount should be 9");
    assertEq(FuelConsumptionState.getElapsedTime(networkNodeId), 0, "Initial elapsed time should be 0");

    // 2. Update after 30 minutes
    vm.warp(block.timestamp + 1800);
    fuelSystem.updateFuel(networkNodeId);

    // Verify state after 30 minutes
    assertEq(Fuel.getFuelAmount(networkNodeId), 9, "Fuel amount should still be 9 after 30 minutes");
    assertEq(FuelConsumptionState.getElapsedTime(networkNodeId), 1800, "Elapsed time should be 1800 seconds");

    // 3. Update after 1 hour
    vm.warp(block.timestamp + 2000);
    fuelSystem.updateFuel(networkNodeId);

    // Verify state after 1 hour
    assertEq(Fuel.getFuelAmount(networkNodeId), 8, "Fuel amount should be 8 after 1 hour");
    assertEq(FuelConsumptionState.getElapsedTime(networkNodeId), 200, "Elapsed time should reset to 200");

    // 4. Bring Network Node offline
    deployableSystem.bringOffline(networkNodeId);

    // Verify state after bringing offline
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ANCHORED),
      "Network Node should be offline"
    );
    assertFalse(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be stopped");
    assertEq(
      FuelConsumptionState.getPreviousCycleElapsedTime(networkNodeId),
      200,
      "Previous cycle elapsed time should be 200"
    );
    assertEq(FuelConsumptionState.getElapsedTime(networkNodeId), 0, "Elapsed time should be 0");

    // 5. Wait 30 minutes while offline
    vm.warp(block.timestamp + 1800);
    fuelSystem.updateFuel(networkNodeId);

    // Verify no fuel consumption while offline
    assertEq(Fuel.getFuelAmount(networkNodeId), 8, "Fuel amount should remain 8 while offline");
    assertFalse(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be stopped");
    assertEq(
      FuelConsumptionState.getPreviousCycleElapsedTime(networkNodeId),
      200,
      "Previous cycle elapsed time should be 200"
    );
    assertEq(FuelConsumptionState.getElapsedTime(networkNodeId), 0, "Elapsed time should be 0");

    // 6. Bring Network Node back online
    deployableSystem.bringOnline(networkNodeId);

    // Verify state after bringing back online
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online again"
    );
    assertTrue(FuelConsumptionState.getBurnState(networkNodeId), "Burn should be active again");
    assertEq(Fuel.getFuelAmount(networkNodeId), 8, "One unit should be consumed on bringing online");

    // 7. Update after 1 hour
    vm.warp(block.timestamp + 3600);
    fuelSystem.updateFuel(networkNodeId);

    // Verify final state
    assertEq(Fuel.getFuelAmount(networkNodeId), 7, "Fuel amount should be 7 after another hour");
    assertEq(FuelConsumptionState.getElapsedTime(networkNodeId), 200, "Elapsed time should be 200");

    vm.stopPrank();
  }

  function test_networkNodeOnlineOfflineWithAssemblies() public {
    vm.pauseGasMetering();
    vm.startPrank(deployer, deployer);

    // Setup Network Node with 100 GJ capacity and 100 GJ production
    _setupNetworkNode(100, 100);

    // Deposit initial fuel
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);

    // Setup and connect Smart Gate (requires 50 GJ)
    _setupSmartGate(smartGateId);

    // 1. Bring Network Node online
    deployableSystem.bringOnline(networkNodeId);

    // Verify initial Network Node state
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ONLINE),
      "Network Node should be online"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 10, "Network Node should reserve 10 GJ for itself");

    // 2. Bring Smart Gate online
    deployableSystem.bringOnline(smartGateId);

    // Verify Smart Gate is online and energy is reserved
    assertEq(uint8(DeployableState.getCurrentState(smartGateId)), uint8(State.ONLINE), "Smart Gate should be online");
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 60, "Total reserved energy should be 60 GJ (10 + 50)");

    // 3. Update after 1 hour
    vm.warp(block.timestamp + 3600);
    fuelSystem.updateFuel(networkNodeId);

    // Verify fuel consumption with connected assembly
    assertEq(Fuel.getFuelAmount(networkNodeId), 8, "Fuel amount should be 8 after 1 hour");

    // 4. Bring Network Node offline
    deployableSystem.bringOffline(networkNodeId);

    // Verify all connected assemblies are offline
    assertEq(
      uint8(DeployableState.getCurrentState(networkNodeId)),
      uint8(State.ANCHORED),
      "Network Node should be offline"
    );
    assertEq(
      uint8(DeployableState.getCurrentState(smartGateId)),
      uint8(State.ANCHORED),
      "Smart Gate should be offline"
    );
    assertEq(NetworkNode.getTotalReservedEnergy(networkNodeId), 0, "No energy should be reserved");

    // 5. Wait 30 minutes while offline
    vm.warp(block.timestamp + 1800);
    fuelSystem.updateFuel(networkNodeId);

    // Verify no fuel consumption while offline
    assertEq(Fuel.getFuelAmount(networkNodeId), 8, "Fuel amount should remain 8 while offline");

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  // Helper functions for common setup and operations
  function _setupNetworkNode(uint256 maxEnergyCapacity, uint256 currentProduction) internal {
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
      maxEnergyCapacity,
      currentProduction
    );
  }

  function _setupSmartGate(uint256 gateId) internal {
    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams({
        smartObjectId: gateId,
        owner: alice,
        locationData: locationParams,
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: SMART_GATE_TYPE_ID,
          itemId: SMART_GATE_ID,
          volume: 100
        }),
        assemblyType: "SG"
      }),
      10, // maxDistance
      networkNodeId
    );
  }

  function _setupSmartStorageUnit(uint256 storageId) internal {
    smartStorageUnitSystem.createAndAnchorStorageUnit(
      CreateAndAnchorParams({
        smartObjectId: storageId,
        owner: alice,
        locationData: locationParams,
        entityRecordParams: EntityRecordParams({
          tenantId: tenantId,
          typeId: SSU_TYPE_ID,
          itemId: SMART_STORAGE_ID,
          volume: 100
        }),
        assemblyType: "SSU"
      }),
      1000, // storage capacity
      1000, // ephemeral capacity
      networkNodeId
    );
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
