// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, SMART_TURRET_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/smart-turret/Utils.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { SmartTurretLib } from "../../src/modules/smart-turret/SmartTurretLib.sol";
import { State, SmartAssemblyType } from "../../src/modules/smart-deployable/types.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "../../src/modules/smart-turret/types.sol";
import { SmartTurretSystem } from "../../src/modules/smart-turret/systems/SmartTurretSystem.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { EntityRecordData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as EntityRecordCharacter } from "../../src/modules/smart-character/types.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

import { SmartTurretConfigTable } from "../../src/codegen/tables/SmartTurretConfigTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { SmartAssemblyTable } from "../../src/codegen/tables/SmartAssemblyTable.sol";

import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";

import { SmartTurretCustomMock } from "./SmartTurretCustomMock.sol";

/**
 * @title SmartTurretTest
 * @dev Not including Fuzz test as it has issues
 */
contract SmartTurretTest is MudTest {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartTurretLib for SmartTurretLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;

  IWorldWithEntryContext world;
  SmartCharacterLib.World smartCharacter;
  SmartTurretLib.World smartTurret;
  SmartDeployableLib.World smartDeployable;
  IERC721 erc721TurretToken;
  bytes14 constant SMART_DEPLOYABLE_ERC721_NAMESPACE = "erc721deploybl";
  IERC721 erc721CharacterToken;
  bytes14 constant SMART_CHAR_ERC721_NAMESPACE = "erc721charactr";

  SmartTurretCustomMock smartTurretCustomMock;
  bytes14 constant CUSTOM_NAMESPACE = "custom-namespa";

  ResourceId SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID;

  uint256 smartObjectId = 1234;
  uint256 characterId = 11111;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // BUILDER

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

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
      "aggression(uint256,uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256))"
    );
    vm.stopPrank();

    smartCharacter = SmartCharacterLib.World(world, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
    smartDeployable = SmartDeployableLib.World(world, DEPLOYMENT_NAMESPACE);
    smartTurret = SmartTurretLib.World(world, DEPLOYMENT_NAMESPACE);

    //Create a smart character
    smartCharacter.createCharacter(
      characterId,
      alice,
      100,
      EntityRecordCharacter({ typeId: 111, itemId: 1, volume: 10 }),
      EntityRecordOffchainTableData({ name: "characterName", dappURL: "noURL", description: "." }),
      "tokenCid"
    );

    erc721TurretToken = IERC721(
      ERC721Registry.get(
        ERC721_REGISTRY_TABLE_ID,
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_ERC721_NAMESPACE)
      )
    );
    erc721CharacterToken = IERC721(
      ERC721Registry.get(ERC721_REGISTRY_TABLE_ID, WorldResourceIdLib.encodeNamespace(SMART_CHAR_ERC721_NAMESPACE))
    );

    smartDeployable.globalResume();
  }

  function testSetup() public {
    address smartTurretSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartTurretSystemId());
    ResourceId smartTurretSystemId = SystemRegistry.get(smartTurretSystem);
    assertEq(smartTurretSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testAnchorSmartTurret() public {
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    uint256 fuelUnitVolume = 100;
    uint256 fuelConsumptionIntervalInSeconds = 100;
    uint256 fuelMaxCapacity = 100;

    smartTurret.createAndAnchorSmartTurret(
      smartObjectId,
      entityRecordData,
      smartObjectData,
      worldPosition,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18 // fuelMaxCapacity,
    );

    smartDeployable.depositFuel(smartObjectId, 1);
    smartDeployable.bringOnline(smartObjectId);

    assertEq(uint256(SmartAssemblyTable.get(smartObjectId)), uint256(SmartAssemblyType.SMART_TURRET));
  }

  function testConfigureSmartTurret() public {
    testAnchorSmartTurret();
    smartTurret.configureSmartTurret(smartObjectId, SMART_TURRET_CUSTOM_MOCK_SYSTEM_ID);

    ResourceId systemId = SmartTurretConfigTable.get(smartObjectId);
    assertEq(systemId.getNamespace(), CUSTOM_NAMESPACE);
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

    TargetPriority[] memory returnTargetQueue = smartTurret.inProximity(
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

    TargetPriority[] memory returnTargetQueue = smartTurret.inProximity(
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

    TargetPriority[] memory returnTargetQueue = smartTurret.inProximity(
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

    TargetPriority[] memory returnTargetQueue = smartTurret.aggression(
      smartObjectId,
      characterId,
      priorityQueue,
      turret,
      aggressor,
      victim
    );

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].weight, 100);
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

    TargetPriority[] memory returnTargetQueue = smartTurret.aggression(
      smartObjectId,
      characterId,
      priorityQueue,
      turret,
      aggressor,
      victim
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

    smartTurret.inProximity(smartObjectId, characterId, priorityQueue, turret, turretTarget);
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
      abi.encodeWithSelector(
        SmartDeployableErrors.SmartDeployable_IncorrectState.selector,
        smartObjectId,
        State.UNANCHORED
      )
    );

    smartTurret.inProximity(smartObjectId, characterId, priorityQueue, turret, turretTarget);
  }

  function testOnlyAdminOrOwnerCanConfigure() public {
    // TODO: only the owner of a gate can configure its logic
  }
}
