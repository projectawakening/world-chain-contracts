// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

// MUD imports
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { Role, HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace tables
import { GlobalDeployableState, Inventory, Tenant, EntityRecord, EntityRecordData, DeployableState, DeployableStateData, InventoryItemData, InventoryItem, InventoryByItem, OwnershipByObject, EphemeralInvCapacity, CharactersByAccount, LocationData, ObjectByEphemeral, ObjectByEphemeralData, SmartAssembly, SmartGateConfig, SmartGateConfigData, SmartGateLink, SmartGateLinkData, Fuel, FuelData, Location } from "../../src/namespaces/evefrontier/codegen/index.sol";

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
import { SmartGateSystem, smartGateSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { AnchorSystem, anchorSystem } from "../../src/namespaces/evefrontier/codegen/systems/AnchorSystemLib.sol";
import { FlagSystem, flagSystem } from "../../src/namespaces/evefrontier/codegen/systems/FlagSystemLib.sol";
// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

contract EveTest is MudTest {
    using WorldResourceIdInstance for ResourceId;

    IWorldWithContext public world;

    uint256 smartObjectId;
    uint256 constant SMART_OBJECT_ID = 1234;
    uint256 constant SMART_OBJECT_TYPE_ID = 1235;

    // Test addresses
    address deployer;
    address alice;
    address bob;
    address charlie;

    uint256 aliceCharacterId;
    uint256 bobCharacterId;
    uint256 charlieCharacterId;
    uint256 deployerCharacterId;

    // Common test data
    bytes32 tenantId;

    uint256 ANCHOR_ID = 9001;
    uint256 anchorId;

    function setUp() public virtual override {
        vm.pauseGasMetering();
        
        // Deploy a new World
        worldAddress = vm.envAddress("WORLD_ADDRESS");
        world = IWorldWithContext(worldAddress);
        StoreSwitch.setStoreAddress(worldAddress);

        tenantId = keccak256(abi.encodePacked("TEST"));

        // Initialize addresses
        string memory mnemonic = "test test test test test test test test test test test junk";
        deployer = vm.addr(vm.deriveKey(mnemonic, 0));
        alice = vm.addr(vm.deriveKey(mnemonic, 1));
        bob = vm.addr(vm.deriveKey(mnemonic, 2));
        charlie = vm.addr(vm.deriveKey(mnemonic, 3));

        vm.startPrank(deployer, deployer);

        anchorId = _calculateObjectId(vm.envUint("FLAG_TYPE_ID"), ANCHOR_ID, true);

        aliceCharacterId = 1;
        bobCharacterId = 2;
        charlieCharacterId = 3;

        // Mock smart character data for alice and bob
        CharactersByAccount.set(alice, aliceCharacterId);
        CharactersByAccount.set(bob, bobCharacterId);
        CharactersByAccount.set(charlie, charlieCharacterId);

        smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);

        // allow global resume for deployable activity
        deployableSystem.globalResume();

        CreateAndAnchorParams memory flagParams = CreateAndAnchorParams({
            smartObjectId: anchorId,
            assemblyType: "FLAG",
            entityRecordParams: EntityRecordParams({
                tenantId: tenantId,
                typeId: vm.envUint("FLAG_TYPE_ID"),
                itemId: ANCHOR_ID,
                volume: vm.envUint("FLAG_VOLUME")
            }),
            owner: alice,
            fuelUnitVolume: 10,
            fuelConsumptionIntervalInSeconds: 3600,
            fuelMaxCapacity: 100000000,
            locationData: LocationData({
                solarSystemId: 1,
                x: 1000,
                y: 1000,
                z: 1000
            }),
            anchorId: 0
        });

        flagSystem.createFlag(flagParams);

        vm.stopPrank();
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

    // Helper function to create and register a custom system
    function _createAndRegisterCustomSystem(
        bytes14 namespace,
        bytes16 name,
        System system
    ) internal returns (ResourceId) {
        ResourceId systemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);
        
        vm.startPrank(alice);
        world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
        world.registerSystem(systemId, system, true);
        vm.stopPrank();
        
        return systemId;
    }

    // Helper function to bring an object online with fuel
    function _bringObjectOnlineWithFuel(uint256 objectId, uint256 fuelAmount) internal {
        vm.startPrank(deployer);
        fuelSystem.depositFuel(objectId, fuelAmount);
        deployableSystem.bringOnline(objectId);
        vm.stopPrank();
    }

    // Helper function to set object ownership
    function _setObjectOwnership(uint256 objectId, address owner) internal {
        vm.startPrank(deployer);
        OwnershipByObject.set(objectId, owner);
        vm.stopPrank();
    }

    // Helper function to set object state
    function _setObjectState(uint256 objectId, State state) internal {
        vm.startPrank(deployer);
        DeployableState.setCurrentState(objectId, state);
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
} 