// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, SMART_TURRET_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { STATIC_DATA_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE, LOCATION_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { Utils } from "../../src/modules/smart-turret/Utils.sol";
import { SmartTurretModule } from "../../src/modules/smart-turret/SmartTurretModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { ERC721Module } from "../../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { SmartTurretLib } from "../../src/modules/smart-turret/SmartTurretLib.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Target, HPratio } from "../../src/modules/smart-turret/types.sol";
import { SmartTurret as SmartTurretSystem } from "../../src/modules/smart-turret/systems/SmartTurret.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { EntityRecordData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { SmartCharacterModule } from "../../src/modules/smart-character/SmartCharacterModule.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as EntityRecordCharacter } from "../../src/modules/smart-character/types.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { SmartTurretConfigTable } from "../../src/codegen/tables/SmartTurretConfigTable.sol";
import { CharactersTable, CharactersTableData } from "../../src/codegen/tables/CharactersTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

import { createCoreModule } from "../CreateCoreModule.sol";

contract SmartTurretTestSystem is System {
  using SmartCharacterUtils for bytes14;

  function inProximity(
    uint256 smartTurretId,
    uint256 characterId,
    Target[] memory priorityQueue,
    uint256 remainingAmmo,
    uint256 hpRatio
  ) public returns (Target[] memory returnTargetQueue) {
    //TODO: Implement the logic for the system
    CharactersTableData memory characterData = CharactersTable.get(
      DEPLOYMENT_NAMESPACE.charactersTableId(),
      characterId
    );
    if (characterData.corpId == 100) {
      return priorityQueue;
    }

    return returnTargetQueue;
  }

  function aggression(
    uint256 smartTurretId,
    uint256 aggressorCharacterId,
    uint256 aggressorHp,
    uint256 victimItemId,
    uint256 victimHp,
    Target[] memory priorityQueue,
    uint256 chargesLeft
  ) public returns (Target[] memory returnTargetQueue) {
    return priorityQueue;
  }
}

/**
 * @title SmartTurretTest
 * @dev Not including Fuzz test as it has issues
 */
contract SmartTurretTest is Test {
  using Utils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartTurretLib for SmartTurretLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartObjectLib for SmartObjectLib.World;

  IBaseWorld world;
  SmartCharacterLib.World smartCharacter;
  SmartTurretLib.World smartTurret;
  SmartDeployableLib.World smartDeployable;
  IERC721Mintable erc721TurretToken;
  IERC721Mintable erc721CharacterToken;
  SmartObjectLib.World SOFInterface;

  SmartTurretTestSystem smartTurretTestSystem = new SmartTurretTestSystem();
  ResourceId smartTurretTesStystemId =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, "SmartTurretTestS"))));

  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";
  bytes14 constant SMART_CHAR_ERC721 = "ERC721Char";
  uint256 smartCharacterClassId = uint256(keccak256("SmartCharacterClass"));
  uint256[] smartCharClassIds;

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    // installing SOF module (dependancy)
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );
    SOFInterface = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);

    // install smartCharacterModule
    _installModule(new SmartCharacterModule(), SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
    smartCharacter = SmartCharacterLib.World(world, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);

    SmartDeployableModule deployableModule = new SmartDeployableModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE), address(deployableModule));
    world.installModule(deployableModule, abi.encode(DEPLOYMENT_NAMESPACE, new SmartDeployable()));
    smartDeployable = SmartDeployableLib.World(world, DEPLOYMENT_NAMESPACE);

    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    _installModule(new LocationModule(), LOCATION_DEPLOYMENT_NAMESPACE);
    _installModule(new SmartTurretModule(), DEPLOYMENT_NAMESPACE);

    erc721TurretToken = registerERC721(
      world,
      ERC721_DEPLOYABLE,
      StaticDataGlobalTableData({ name: "SmartTurret", symbol: "ST", baseURI: "" })
    );
    erc721CharacterToken = registerERC721(
      world,
      SMART_CHAR_ERC721,
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: "" })
    );

    // create class and object types
    SOFInterface.registerEntityType(2, "CLASS");
    SOFInterface.registerEntityType(1, "OBJECT");
    // allow object to class tagging
    SOFInterface.registerEntityTypeAssociation(1, 2);

    // initalize the smart character class
    SOFInterface.registerEntity(smartCharacterClassId, 2);
    smartCharacter.setCharClassId(smartCharacterClassId);

    smartCharacter.registerERC721Token(address(erc721CharacterToken));
    smartDeployable.registerDeployableToken(address(erc721TurretToken));

    smartTurret = SmartTurretLib.World(world, DEPLOYMENT_NAMESPACE);

    // register the smart turret system
    world.registerSystem(smartTurretTesStystemId, smartTurretTestSystem, true);
    //register the function selector
    world.registerFunctionSelector(smartTurretTesStystemId, "inProximity(uint256, uint256,Target[],uint256,uint256)");

    //Create a smart character
    smartCharacter.createCharacter(
      11111,
      address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
      100,
      EntityRecordCharacter({ typeId: 111, itemId: 1, volume: 10 }),
      EntityRecordOffchainTableData({ name: "characterName", dappURL: "noURL", description: "." }),
      "tokenCid"
    );
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function testSetup() public {
    address smartTurretSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartTurretSystemId());
    ResourceId smartTurretSystemId = SystemRegistry.get(smartTurretSystem);
    assertEq(smartTurretSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testAnchorSmartTurret() public {
    uint256 smartObjectId = 1234;
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: address(1), tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    uint256 fuelUnitVolume = 100;
    uint256 fuelConsumptionIntervalInSeconds = 100;
    uint256 fuelMaxCapacity = 100;
    smartDeployable.globalResume();
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
  }

  function testConfigureSmartTurret() public {
    testAnchorSmartTurret();
    uint256 smartObjectId = 1234;
    smartTurret.configureSmartTurret(smartObjectId, smartTurretTesStystemId);

    ResourceId systemId = SmartTurretConfigTable.get(DEPLOYMENT_NAMESPACE.smartTurretConfigTableId(), smartObjectId);
    assertEq(systemId.getNamespace(), DEPLOYMENT_NAMESPACE);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(smartTurretTesStystemId));
  }

  function testInProximity() public {
    testConfigureSmartTurret();
    uint256 smartObjectId = 1234;
    Target[] memory targetQueue = new Target[](1);
    HPratio memory hpRatio = HPratio({ armor: 100, hp: 100, shield: 100 });
    targetQueue[0] = Target({ char: "ch", shipType: "sp", weight: 100, hpRatio: hpRatio });
    uint256 remainingAmmo = 100;
    uint256 charHpRatio = 100;
    uint256 characterId = 11111;

    Target[] memory returnTargetQueue = smartTurret.inProximity(
      smartObjectId,
      characterId,
      targetQueue,
      remainingAmmo,
      charHpRatio
    );

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].char, "ch");
    assertEq(returnTargetQueue[0].shipType, "sp");
    assertEq(returnTargetQueue[0].weight, 100);
  }

  function testInProximityWrongCorpId() public {
    testConfigureSmartTurret();
    uint256 smartObjectId = 1234;
    Target[] memory targetQueue = new Target[](1);
    HPratio memory hpRatio = HPratio({ armor: 100, hp: 100, shield: 100 });
    targetQueue[0] = Target({ char: "ch", shipType: "sp", weight: 100, hpRatio: hpRatio });
    uint256 remainingAmmo = 100;
    uint256 charHpRatio = 100;
    uint256 characterId = 5555;

    Target[] memory returnTargetQueue = smartTurret.inProximity(
      smartObjectId,
      characterId,
      targetQueue,
      remainingAmmo,
      charHpRatio
    );

    assertEq(returnTargetQueue.length, 0);
  }

  function testAggression() public {
    testConfigureSmartTurret();
    uint256 smartObjectId = 1234;
    Target[] memory priorityQueue = new Target[](1);
    HPratio memory hpRatio = HPratio({ armor: 100, hp: 100, shield: 100 });
    priorityQueue[0] = Target({ char: "ch", shipType: "sp", weight: 100, hpRatio: hpRatio });
    uint256 chargesLeft = 100;
    uint256 aggressorCharacterId = 11111;
    uint256 aggressorHp = 100;
    uint256 victimItemId = 1234;
    uint256 victimHp = 100;

    Target[] memory returnTargetQueue = smartTurret.aggression(
      smartObjectId,
      aggressorCharacterId,
      aggressorHp,
      victimItemId,
      victimHp,
      priorityQueue,
      chargesLeft
    );

    assertEq(returnTargetQueue.length, 1);
    assertEq(returnTargetQueue[0].char, "ch");
    assertEq(returnTargetQueue[0].shipType, "sp");
    assertEq(returnTargetQueue[0].weight, 100);
  }

  function revertInProximity() public {
    uint256 smartObjectId = 1234;
    Target[] memory targetQueue = new Target[](1);
    HPratio memory hpRatio = HPratio({ armor: 100, hp: 100, shield: 100 });
    targetQueue[0] = Target({ char: "ch", shipType: "sp", weight: 100, hpRatio: hpRatio });
    uint256 remainingAmmo = 100;
    uint256 charHpRatio = 100;
    uint256 characterId = 11111;

    vm.expectRevert(abi.encodeWithSelector(SmartTurretSystem.SmartTurret_NotConfigured.selector, smartObjectId));

    smartTurret.inProximity(smartObjectId, characterId, targetQueue, remainingAmmo, charHpRatio);
  }

  function revertInProximityIncorrectState() public {
    uint256 smartObjectId = 1234;
    Target[] memory targetQueue = new Target[](1);
    HPratio memory hpRatio = HPratio({ armor: 100, hp: 100, shield: 100 });
    targetQueue[0] = Target({ char: "ch", shipType: "sp", weight: 100, hpRatio: hpRatio });
    uint256 remainingAmmo = 100;
    uint256 charHpRatio = 100;
    uint256 characterId = 11111;

    vm.expectRevert(
      abi.encodeWithSelector(
        SmartDeployableErrors.SmartDeployable_IncorrectState.selector,
        smartObjectId,
        State.UNANCHORED
      )
    );

    smartTurret.inProximity(smartObjectId, characterId, targetQueue, remainingAmmo, charHpRatio);
  }
}
