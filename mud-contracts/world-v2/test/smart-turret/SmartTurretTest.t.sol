// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

import { SmartAssembly } from "../../src/namespaces/evefrontier/codegen/tables/SmartAssembly.sol";
import { SmartTurretConfig } from "../../src/namespaces/evefrontier/codegen/tables/SmartTurretConfig.sol";
import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { WorldPosition, Coord } from "../../src/namespaces/evefrontier/systems/location/types.sol";
import { SMART_TURRET } from "../../src/namespaces/evefrontier/systems/constants.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "../../src/namespaces/evefrontier/systems/smart-turret/types.sol";
import { SmartTurretCustomMock } from "./SmartTurretCustomMock.sol";

import { SmartTurretSystem } from "../../src/namespaces/evefrontier/systems/smart-turret/SmartTurretSystem.sol";
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";

import { SmartTurretSystemLib, smartTurretSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { CreateAndAnchorDeployableParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { AggressionParams } from "../../src/namespaces/evefrontier/systems/smart-turret/types.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";

contract SmartTurretTest is MudTest {
  IWorldWithContext world;
  SmartTurretCustomMock smartTurretCustomMock;
  bytes14 constant CUSTOM_NAMESPACE = "custom-namespa";

  ResourceId SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID;

  uint256 smartObjectId = 1234;
  uint256 characterId = 11111;
  uint256 tribeId = 100;

  SmartObjectData smartObjectData;
  EntityRecordData entityRecord;
  WorldPosition worldPosition;

  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));
  address alice = vm.addr(vm.deriveKey(mnemonic, 2));

  function setUp() public virtual override {
    super.setUp();
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);

    entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    Coord memory position = Coord({ x: 1, y: 1, z: 1 });
    worldPosition = WorldPosition({ solarSystemId: 1, position: position });

    // BUILDER register a custom namespace
    vm.startPrank(alice);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(CUSTOM_NAMESPACE));
    SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID = ResourceId.wrap(
      (bytes32(abi.encodePacked(RESOURCE_SYSTEM, CUSTOM_NAMESPACE, "SmartTurretCusto")))
    );
    // BUILER deploy and register mock
    smartTurretCustomMock = new SmartTurretCustomMock();
    world.registerSystem(SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID, smartTurretCustomMock, true);
    world.registerFunctionSelector(
      SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID,
      "inProximity(uint256,uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256))"
    );
    world.registerFunctionSelector(
      SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID,
      "aggression((uint256,uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256)))"
    );
    vm.stopPrank();

    vm.startPrank(deployer);
    deployableSystem.globalResume();
    smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);
    vm.stopPrank();
  }

  function testAnchorSmartTurret() public {
    uint256 fuelUnitVolume = 100;
    uint256 fuelConsumptionIntervalInSeconds = 100;
    uint256 fuelMaxCapacity = 100;

    vm.startPrank(deployer);
    smartTurretSystem.createAndAnchorSmartTurret(
      CreateAndAnchorDeployableParams({
        smartObjectId: smartObjectId,
        smartAssemblyType: SMART_TURRET,
        entityRecordData: entityRecord,
        smartObjectData: smartObjectData,
        fuelUnitVolume: fuelUnitVolume,
        fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity: fuelMaxCapacity,
        locationData: LocationData({
          solarSystemId: worldPosition.solarSystemId,
          x: worldPosition.position.x,
          y: worldPosition.position.y,
          z: worldPosition.position.z
        })
      })
    );

    fuelSystem.depositFuel(smartObjectId, 1);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();
    assertEq(SmartAssembly.getSmartAssemblyType(smartObjectId), SMART_TURRET);
  }

  function testConfigureSmartTurret() public {
    testAnchorSmartTurret();
    vm.startPrank(alice);
    smartTurretSystem.configureSmartTurret(smartObjectId, SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID);
    vm.stopPrank();

    ResourceId systemId = SmartTurretConfig.get(smartObjectId);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID));
  }

  function testInProximity() public {
    testConfigureSmartTurret();
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 11111,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.inProximity(
      smartObjectId,
      characterId,
      priorityQueue,
      turret,
      turretTarget
    );

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].weight, 100);
  }

  function testInProximityDefaultLogic() public {
    testAnchorSmartTurret();
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 11112,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.inProximity(
      smartObjectId,
      characterId,
      priorityQueue,
      turret,
      turretTarget
    );

    assertEq(returnTargetQueue.length, 2);
  }

  function testInProximityWrongCorpId() public {
    testConfigureSmartTurret();
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 5555,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.inProximity(
      smartObjectId,
      characterId,
      priorityQueue,
      turret,
      turretTarget
    );

    assertEq(returnTargetQueue.length, 0);
  }

  function testAggression() public {
    testConfigureSmartTurret();
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 4444,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
    SmartTurretTarget memory aggressor = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 5555,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    SmartTurretTarget memory victim = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 6666,
      hpRatio: 80,
      shieldRatio: 100,
      armorRatio: 100
    });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        turretOwnerCharacterId: characterId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 1, "returnTargetQueue.length incorrect");
    assertEq(returnTargetQueue[0].weight, 100, "returnTargetQueue[0].weight incorrect");
  }

  function testAggressionDefaultLogic() public {
    testAnchorSmartTurret();
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 4444,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
    SmartTurretTarget memory aggressor = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 5555,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    SmartTurretTarget memory victim = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 6666,
      hpRatio: 80,
      shieldRatio: 100,
      armorRatio: 100
    });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    TargetPriority[] memory returnTargetQueue = smartTurretSystem.aggression(
      AggressionParams({
        smartObjectId: smartObjectId,
        turretOwnerCharacterId: characterId,
        priorityQueue: priorityQueue,
        turret: turret,
        aggressor: aggressor,
        victim: victim
      })
    );

    assertEq(returnTargetQueue.length, 2);
    assertEq(returnTargetQueue[1].weight, 1);
  }

  function revertInProximity() public {
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 5555,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    vm.expectRevert(abi.encodeWithSelector(SmartTurretSystem.SmartTurret_NotConfigured.selector, smartObjectId));

    smartTurretSystem.inProximity(smartObjectId, characterId, priorityQueue, turret, turretTarget);
  }

  function revertInProximityIncorrectState() public {
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 5555,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );

    smartTurretSystem.inProximity(smartObjectId, characterId, priorityQueue, turret, turretTarget);
  }

  function testAdminCannotConfigureSmartTurret() public {
    testAnchorSmartTurret();

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotDeployableOwner.selector, deployer, smartObjectId));
    smartTurretSystem.configureSmartTurret(smartObjectId, SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID);
    vm.stopPrank();
  }
}
