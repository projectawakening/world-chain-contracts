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
import { Inventory, Tenant, EntityRecord, EntityRecordData, DeployableState, Characters, CharactersData, DeployableStateData, CharactersByAccount, LocationData, SmartAssembly, Fuel, FuelData, Location, SmartTurretConfig } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { SmartTurretSystem, smartTurretSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";

// Types and parameters
import { EntityRecordParams, EntityMetadataParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { TargetPriority, AggressionParams, Turret, SmartTurretTarget } from "../../src/namespaces/evefrontier/systems/smart-turret/types.sol";

// Create a mock custom system to call when inProximity or aggression is called
// This fits the expected builder pattern -
//   - create a custom contract that handles the inProximity or aggression logic, and
//   - then configure the smart turret to use this custom system
contract MockSmartTurretInteractSystem is System {
  // don't shoot your owner, but everyone else is fair game
  function inProximity(
    uint256 smartTurretId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    CharactersData memory characterData = Characters.get(turretTarget.characterId);
    address owner = ownershipSystem.owner(smartTurretId);
    uint256 turretOwnerCharacterId = CharactersByAccount.getSmartObjectId(owner);
    if (turretTarget.characterId == turretOwnerCharacterId) {
      // don't bite the hand that feeds you
      return priorityQueue;
    } else {
      // shoot to kill
      updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);
      for (uint256 i = 0; i < priorityQueue.length; i++) {
        updatedPriorityQueue[i] = priorityQueue[i];
      }
      updatedPriorityQueue[priorityQueue.length] = TargetPriority({ target: turretTarget, weight: 100 });
      return updatedPriorityQueue;
    }
  }

  // help your friends, shoot their enemies (victim or agressor)
  function aggression(AggressionParams memory params) public returns (TargetPriority[] memory updatedPriorityQueue) {
    address owner = ownershipSystem.owner(params.smartObjectId);
    uint256 turretOwnerCharacterId = CharactersByAccount.getSmartObjectId(owner);
    uint256 turretOwnerTribe = Characters.getTribeId(turretOwnerCharacterId);
    uint256 aggressorTribe = Characters.getTribeId(params.aggressor.characterId);
    uint256 victimTribe = Characters.getTribeId(params.victim.characterId);
    if (aggressorTribe == turretOwnerTribe && aggressorTribe != victimTribe) {
      updatedPriorityQueue = new TargetPriority[](params.priorityQueue.length + 1);
      for (uint256 i = 0; i < params.priorityQueue.length; i++) {
        // TODO: yul assembly to store mapping of charcterIds bools in the priority queue
        updatedPriorityQueue[i] = params.priorityQueue[i];
      }
      // TODO: yul assembly to load the apporpriate bool slot from the stored mapping keyed to the victim characterId, don't add the victim to the priority queue if the bool is true (they are already in the queue)
      updatedPriorityQueue[params.priorityQueue.length] = TargetPriority({ target: params.victim, weight: 100 });
    } else if (victimTribe == turretOwnerTribe && aggressorTribe != victimTribe) {
      updatedPriorityQueue = new TargetPriority[](params.priorityQueue.length + 1);
      for (uint256 i = 0; i < params.priorityQueue.length; i++) {
        updatedPriorityQueue[i] = params.priorityQueue[i];
      }
      updatedPriorityQueue[params.priorityQueue.length] = TargetPriority({ target: params.aggressor, weight: 100 });
    } else {
      return params.priorityQueue;
    }
  }
}

contract SmartGateTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // custom smart turret interact system variables
  ResourceId customSystemId;
  MockSmartTurretInteractSystem customSystem;

  // Item variables
  bytes32 tenantId;

  // Test addresses
  address deployer;
  address alice;
  address bob;
  address charlie;

  // character variables
  uint256 aliceCharacterId;
  uint256 bobCharacterId;
  uint256 charlieCharacterId;

  uint256 constant OWNER_SHIP_ID = 5;
  uint256 constant FRIENDLY_SHIP_ID = 1;
  uint256 constant ENEMY_SHIP_ID = 2;
  uint256 constant OWNER_CHARACTER_ID = 5555;
  uint256 constant FRIENDLY_CHARACTER_ID = 11111;
  uint256 constant ENEMY_CHARACTER_ID = 22222;

  uint256 constant FRIENDLY_TRIBE_ID = 101;
  uint256 constant ENEMY_TRIBE_ID = 202;

  uint256 constant SMART_OBJECT_ID = 1234;

  uint256 smartObjectId;

  // Location data
  LocationData locationParams;

  // entity record params
  EntityRecordParams aliceEntityRecordParams;
  EntityRecordParams bobEntityRecordParams;
  EntityRecordParams charlieEntityRecordParams;

  // entity metadata params
  EntityMetadataParams aliceEntityMetadataParams;
  EntityMetadataParams bobEntityMetadataParams;
  EntityMetadataParams charlieEntityMetadataParams;

  EntityRecordParams entityRecordParams;

  // fuel params
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
    bob = vm.addr(vm.deriveKey(mnemonic, 3));
    charlie = vm.addr(vm.deriveKey(mnemonic, 4));

    // Setup tenant
    tenantId = Tenant.get();

    uint256 smartCharacterTypeId = EntityRecord.getTypeId(smartCharacterSystem.getSmartCharacterClassId());

    aliceCharacterId = _calculateObjectId(smartCharacterTypeId, OWNER_CHARACTER_ID, true);
    bobCharacterId = _calculateObjectId(smartCharacterTypeId, FRIENDLY_CHARACTER_ID, true);
    charlieCharacterId = _calculateObjectId(smartCharacterTypeId, ENEMY_CHARACTER_ID, true);

    aliceEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartCharacterTypeId,
      itemId: OWNER_CHARACTER_ID,
      volume: 0
    });
    aliceEntityMetadataParams = EntityMetadataParams({
      name: "Alice",
      dappURL: "https://alice.dapp.com",
      description: "Lost in wonderland. Down the rabbit hole."
    });

    bobEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartCharacterTypeId,
      itemId: FRIENDLY_CHARACTER_ID,
      volume: 0
    });
    bobEntityMetadataParams = EntityMetadataParams({
      name: "Bob",
      dappURL: "https://bob.dapp.com",
      description: "Bob is a friendly character as long as you make sacrifices."
    });

    charlieEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartCharacterTypeId,
      itemId: ENEMY_CHARACTER_ID,
      volume: 0
    });
    charlieEntityMetadataParams = EntityMetadataParams({
      name: "Charlie",
      dappURL: "https://charlie.dapp.com",
      description: "Charlie bit me. Enemy of the state."
    });

    // smart character data for alice and bob and charlie
    vm.prank(alice, deployer);
    smartCharacterSystem.createCharacter(
      aliceCharacterId,
      alice,
      FRIENDLY_TRIBE_ID,
      aliceEntityRecordParams,
      aliceEntityMetadataParams
    );
    vm.prank(bob, deployer);
    smartCharacterSystem.createCharacter(
      bobCharacterId,
      bob,
      FRIENDLY_TRIBE_ID,
      bobEntityRecordParams,
      bobEntityMetadataParams
    );
    vm.prank(charlie, deployer);
    smartCharacterSystem.createCharacter(
      charlieCharacterId,
      charlie,
      ENEMY_TRIBE_ID,
      charlieEntityRecordParams,
      charlieEntityMetadataParams
    );

    // Setup smart object ID for this turret
    smartObjectId = _calculateObjectId(
      EntityRecord.getTypeId(smartTurretSystem.getSmartTurretClassId()),
      SMART_OBJECT_ID,
      true
    );

    locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1002, z: 1003 });

    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: EntityRecord.getTypeId(smartTurretSystem.getSmartTurretClassId()),
      itemId: SMART_OBJECT_ID,
      volume: 10000
    });

    // Mock builder deployment of custom canJumpsystem
    bytes14 namespace = bytes14("spaceforalice");
    bytes16 name = bytes16("MockSmartTurretI");
    // Create resource ID for the mock system using the proper format
    customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    vm.startPrank(alice);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Deploy and register the mock system
    customSystem = new MockSmartTurretInteractSystem();

    // Register the system with the world
    world.registerSystem(customSystemId, customSystem, true);

    vm.stopPrank();

    // allow global resume for deployable activity
    vm.prank(deployer);
    deployableSystem.globalResume();
    vm.resumeGasMetering();
  }

  function test_createAndAnchorSmartTurret() public {
    // all create and anchor internal reverts are tested in DeployableTest, SmartAssemblyTest and EntityRecordTest
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

    vm.startPrank(alice, deployer);
    // create and anchor smart turret
    world.call(
      smartTurretSystem.toResourceId(),
      abi.encodeCall(
        SmartTurretSystem.createAndAnchorTurret,
        (
          CreateAndAnchorParams(
            smartObjectId,
            "ST",
            entityRecordParams,
            alice,
            fuelUnitVolume,
            fuelConsumptionIntervalInSeconds,
            fuelMaxCapacity,
            locationParams
          )
        )
      )
    );
    vm.stopPrank();

    // check entity record data after creating and anchoring
    assertEq(EntityRecord.getExists(smartObjectId), true);

    EntityRecordData memory entityRecordData = EntityRecord.get(smartObjectId);
    assertEq(entityRecordData.tenantId, tenantId);
    assertEq(entityRecordData.typeId, EntityRecord.getTypeId(smartTurretSystem.getSmartTurretClassId()));
    assertEq(entityRecordData.itemId, SMART_OBJECT_ID);
    assertEq(entityRecordData.volume, 10000);

    // smart assembly data after creating and anchoring
    assertEq(
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))),
      keccak256(abi.encodePacked("ST"))
    );

    // check deployable data after creating and anchoring
    deployableStateData = DeployableState.get(smartObjectId);

    assertEq(deployableStateData.createdAt, block.timestamp);
    assertEq(uint8(deployableStateData.previousState), uint8(State.UNANCHORED));
    assertEq(uint8(deployableStateData.currentState), uint8(State.ANCHORED));
    assertEq(deployableStateData.isValid, true);
    assertEq(deployableStateData.anchoredAt, block.timestamp);
    assertEq(deployableStateData.updatedBlockNumber, block.number);
    assertEq(deployableStateData.updatedBlockTime, block.timestamp);

    // check fuel data after creating and anchoring
    fuelData = Fuel.get(smartObjectId);
    assertEq(fuelData.fuelUnitVolume, fuelUnitVolume);
    assertEq(fuelData.fuelConsumptionIntervalInSeconds, fuelConsumptionIntervalInSeconds);
    assertEq(fuelData.fuelMaxCapacity, fuelMaxCapacity);

    // check ownership data after creating and anchoring
    owner = ownershipSystem.owner(smartObjectId);
    assertEq(owner, alice);

    // check location data after creating and anchoring
    locationData = Location.get(smartObjectId);
    assertEq(locationData.solarSystemId, locationParams.solarSystemId);
    assertEq(locationData.x, locationParams.x);
    assertEq(locationData.y, locationParams.y);
    assertEq(locationData.z, locationParams.z);
    vm.resumeGasMetering();
  }

  function test_configureSmartTurret() public {
    test_createAndAnchorSmartTurret();

    vm.startPrank(alice);
    smartTurretSystem.configureTurret(smartObjectId, customSystemId);
    vm.stopPrank();

    ResourceId systemId = SmartTurretConfig.get(smartObjectId);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(customSystemId));
  }

  function test_inProximity() public {
    test_createAndAnchorSmartTurret();

    // bring the turret online
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    // let's assume that the new target is the first target to enter the zone everytime
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    // let's also use the same weapon and ammo stats for all tests
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    // default logic test (friendly tribe)
    turretTarget = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.inProximity(
      smartObjectId,
      priorityQueue,
      turret,
      turretTarget
    );

    assertEq(returnTargetQueue.length, 0);

    // default logic test (enemy tribe)
    turretTarget = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: charlieCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.inProximity(smartObjectId, priorityQueue, turret, turretTarget);

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].target.characterId, charlieCharacterId);

    // configure custom mock
    vm.startPrank(alice);
    smartTurretSystem.configureTurret(smartObjectId, customSystemId);
    vm.stopPrank();

    // custom mock test (friendly owner - don't shoot)
    turretTarget = SmartTurretTarget({
      shipId: OWNER_SHIP_ID,
      shipTypeId: 1,
      characterId: aliceCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.inProximity(smartObjectId, priorityQueue, turret, turretTarget);

    assertEq(returnTargetQueue.length, 0);

    // custom mock test (freindly tribe - shoot)
    turretTarget = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.inProximity(smartObjectId, priorityQueue, turret, turretTarget);

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].target.characterId, bobCharacterId);

    // custom mock test (enemy tribe - shoot)
    turretTarget = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: charlieCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.inProximity(smartObjectId, priorityQueue, turret, turretTarget);

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].target.characterId, charlieCharacterId);
  }

  function test_aggression() public {
    test_createAndAnchorSmartTurret();

    // bring the turret online
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    // default logic test (friendly tribe)
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory currentTarget = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: 77777,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
    priorityQueue[0] = TargetPriority({ target: currentTarget, weight: 100 });

    SmartTurretTarget memory aggressor = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    SmartTurretTarget memory victim = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: charlieCharacterId,
      hpRatio: 80,
      shieldRatio: 100,
      armorRatio: 100
    });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].target.characterId, 77777);

    // default logic test (enemy tribe)

    aggressor = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: charlieCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    victim = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 2);
    assertEq(returnTargetQueue[0].target.characterId, 77777);
    assertEq(returnTargetQueue[1].target.characterId, charlieCharacterId);

    vm.startPrank(alice);
    smartTurretSystem.configureTurret(smartObjectId, customSystemId);
    vm.stopPrank();

    // custom logic test (freindly agressor, hostile victim - shoot victim)
    aggressor = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    victim = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: charlieCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 2);
    assertEq(returnTargetQueue[0].target.characterId, 77777);
    assertEq(returnTargetQueue[1].target.characterId, charlieCharacterId);

    // custom logic test (hostile agressor, freindly victim - shoot agressor)
    aggressor = SmartTurretTarget({
      shipId: ENEMY_SHIP_ID,
      shipTypeId: 1,
      characterId: charlieCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    victim = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 2);
    assertEq(returnTargetQueue[0].target.characterId, 77777);
    assertEq(returnTargetQueue[1].target.characterId, charlieCharacterId);

    // otherwise no change to the priority queue
    aggressor = SmartTurretTarget({
      shipId: OWNER_SHIP_ID,
      shipTypeId: 1,
      characterId: aliceCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    victim = SmartTurretTarget({
      shipId: FRIENDLY_SHIP_ID,
      shipTypeId: 1,
      characterId: bobCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].target.characterId, 77777);
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

  // TODO: move this to the access system tests
  function testAdminCannotConfigureSmartTurret() public {
    test_createAndAnchorSmartTurret();

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotOwner.selector, deployer, smartObjectId));
    smartTurretSystem.configureTurret(smartObjectId, customSystemId);
    vm.stopPrank();
  }
}
