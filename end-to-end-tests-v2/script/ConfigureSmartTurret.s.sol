pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { Tenant, CharactersByAccount, CharactersData, Characters } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { OwnershipSystem, ownershipSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartTurretSystem, smartTurretSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";
import { TargetPriority, AggressionParams, Turret, SmartTurretTarget } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/types.sol";

contract ConfigureSmartTurret is Script {
  using WorldResourceIdInstance for ResourceId;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    IWorldWithContext world = IWorldWithContext(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);
    address bob = vm.addr(vm.deriveKey(mnemonic, 3));
    address charlie = vm.addr(vm.deriveKey(mnemonic, 4));

    bytes32 tenantId = Tenant.get();
    uint256 aliceSmartTurretId = ObjectIdLib.calculateObjectId(tenantId, 1559);

    uint256 aliceCharacterId = CharactersByAccount.getSmartObjectId(alice);
    uint256 bobCharacterId = CharactersByAccount.getSmartObjectId(bob);
    uint256 charlieCharacterId = CharactersByAccount.getSmartObjectId(charlie);
    uint256 aliceShipId = 22;
    uint256 bobShipId = 23;
    uint256 charlieShipId = 24;

    vm.startBroadcast(alicePrivateKey);

    //Register the custom system
    bytes14 namespace = bytes14("turretspace");
    bytes16 name = bytes16("SmartTurretTestS");
    ResourceId customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    SmartTurretTestSystem customSystem = new SmartTurretTestSystem();
    world.registerSystem(customSystemId, customSystem, true);

    smartTurretSystem.configureTurret(aliceSmartTurretId, customSystemId);
    deployableSystem.bringOnline(aliceSmartTurretId);
    vm.stopBroadcast();

    //Test inProximity for owner through custom system
    uint256 returnTargetQueueLength = callInProximity(aliceSmartTurretId, aliceShipId, aliceCharacterId);
    console.log("returnTargetQueueLength", returnTargetQueueLength); // should be 0

    //Test inProximity for non owner through custom system
    returnTargetQueueLength = callInProximity(aliceSmartTurretId, charlieShipId, charlieCharacterId);
    console.log("returnTargetQueueLength", returnTargetQueueLength); // should be 1

    // Test aggression for friendly tribe
    returnTargetQueueLength = callAggression(
      aliceSmartTurretId,
      bobShipId,
      bobCharacterId,
      charlieShipId,
      charlieCharacterId
    );
    console.log("returnTargetQueueLength", returnTargetQueueLength); // should be 1

    // Test aggression for enemy tribe
    returnTargetQueueLength = callAggression(
      aliceSmartTurretId,
      charlieShipId,
      charlieCharacterId,
      bobShipId,
      bobCharacterId
    );
    console.log("returnTargetQueueLength", returnTargetQueueLength); // should be 1

    // Test case where both aggressor and victim are from enemy tribe
    returnTargetQueueLength = callAggression(
      aliceSmartTurretId, // turret owner: Alice (FRIENDLY_TRIBE_ID)
      bobShipId, // aggressor: Bob (FRIENDLY_TRIBE_ID)
      bobCharacterId,
      aliceShipId, // victim: Alice (FRIENDLY_TRIBE_ID)
      aliceCharacterId
    );
    console.log("returnTargetQueueLength for enemy vs enemy:", returnTargetQueueLength); // should be 0
  }

  function callInProximity(
    uint256 smartTurretId,
    uint256 turretTargetId,
    uint256 turretTargetCharacterId
  ) public returns (uint256) {
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: turretTargetId,
      shipTypeId: 1,
      characterId: turretTargetCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.inProximity(
      smartTurretId,
      priorityQueue,
      turret,
      turretTarget
    );
    return returnTargetQueue.length;
  }

  function callAggression(
    uint256 smartTurretId,
    uint256 aggressorSmartTurretId,
    uint256 aggressorCharacterId,
    uint256 victimSmartTurretId,
    uint256 victimCharacterId
  ) public returns (uint256) {
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    SmartTurretTarget memory aggressor = SmartTurretTarget({
      shipId: aggressorSmartTurretId,
      shipTypeId: 1,
      characterId: aggressorCharacterId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    SmartTurretTarget memory victim = SmartTurretTarget({
      shipId: victimSmartTurretId,
      shipTypeId: 1,
      characterId: victimCharacterId,
      hpRatio: 80,
      shieldRatio: 100,
      armorRatio: 100
    });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartTurretId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );
    return returnTargetQueue.length;
  }
}

// Create a mock custom system to call when inProximity or aggression is called
// This fits the expected builder pattern -
//   - create a custom contract that handles the inProximity or aggression logic, and
//   - then configure the smart turret to use this custom system
contract SmartTurretTestSystem is System {
  // don't shoot your owner, but everyone else is fair game
  function inProximity(
    uint256 smartTurretId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
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
    address owner = abi.decode(
      IWorldWithContext(_world()).callStatic(
        ownershipSystem.toResourceId(),
        abi.encodeWithSelector(OwnershipSystem.owner.selector, params.smartObjectId)
      ),
      (address)
    );

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
