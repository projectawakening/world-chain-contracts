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

import { Utils } from "../../src/modules/smart-gate/Utils.sol";
import { SmartGateModule } from "../../src/modules/smart-gate/SmartGateModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { ERC721Module } from "../../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { SmartGateLib } from "../../src/modules/smart-gate/SmartGateLib.sol";
import { State, SmartAssemblyType } from "../../src/modules/smart-deployable/types.sol";
import { SmartGate as SmartGateSystem } from "../../src/modules/smart-gate/systems/SmartGate.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { EntityRecordData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { SmartCharacterModule } from "../../src/modules/smart-character/SmartCharacterModule.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as EntityRecordCharacter } from "../../src/modules/smart-character/types.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { SmartGateConfigTable } from "../../src/codegen/tables/SmartGateConfigTable.sol";
import { SmartGateLinkTable } from "../../src/codegen/tables/SmartGateLinkTable.sol";
import { CharactersTable, CharactersTableData } from "../../src/codegen/tables/CharactersTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { SmartAssemblyTable } from "../../src/codegen/tables/SmartAssemblyTable.sol";
import { DeployableState } from "../../src/codegen/tables/DeployableState.sol";

import { createCoreModule } from "../CreateCoreModule.sol";

contract SmartGateTestSystem is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return false;
  }
}

/**
 * @title SmartGateTest
 * @dev Not including Fuzz test as it has issues
 */
contract SmartGateTest is Test {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartGateLib for SmartGateLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartObjectLib for SmartObjectLib.World;

  IBaseWorld world;
  SmartCharacterLib.World smartCharacter;
  SmartGateLib.World smartGate;
  SmartDeployableLib.World smartDeployable;
  IERC721Mintable erc721GateToken;
  IERC721Mintable erc721CharacterToken;
  SmartObjectLib.World SOFInterface;

  SmartGateTestSystem smartGateTestSystem = new SmartGateTestSystem();
  ResourceId smartGateTesStystemId =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, "SmartGateTestS"))));

  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";
  bytes14 constant SMART_CHAR_ERC721 = "ERC721Char";
  uint256 smartCharacterClassId = uint256(keccak256("SmartCharacterClass"));
  uint256[] smartCharClassIds;

  uint256 sourceGateId = 1234;
  uint256 destinationGateId = 1235;
  uint256 characterId = 11111;

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
    _installModule(new SmartGateModule(), DEPLOYMENT_NAMESPACE);

    erc721GateToken = registerERC721(
      world,
      ERC721_DEPLOYABLE,
      StaticDataGlobalTableData({ name: "SmartGate", symbol: "ST", baseURI: "" })
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
    smartDeployable.registerDeployableToken(address(erc721GateToken));

    smartGate = SmartGateLib.World(world, DEPLOYMENT_NAMESPACE);

    // register the smart turret system
    world.registerSystem(smartGateTesStystemId, smartGateTestSystem, true);
    //register the function selector
    world.registerFunctionSelector(smartGateTesStystemId, "canJump(uint256, uint256, uint256)");

    //Create a smart character
    smartCharacter.createCharacter(
      characterId,
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
    address smartGateSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartGateSystemId());
    ResourceId smartGateSystemId = SystemRegistry.get(smartGateSystem);
    assertEq(smartGateSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testAnchorSmartGate(uint256 smartObjectId) public {
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: address(1), tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 10000, y: 10000, z: 10000 })
    });

    uint256 fuelUnitVolume = 100;
    uint256 fuelConsumptionIntervalInSeconds = 100;
    uint256 fuelMaxCapacity = 100;
    smartDeployable.globalResume();
    smartGate.createAndAnchorSmartGate(
      smartObjectId,
      entityRecordData,
      smartObjectData,
      worldPosition,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18, // fuelMaxCapacity,
      100000000 * 1e18 // maxDistance
    );

    smartDeployable.depositFuel(smartObjectId, 1);
    smartDeployable.bringOnline(smartObjectId);

    assertEq(
      uint256(SmartAssemblyTable.get(DEPLOYMENT_NAMESPACE.smartAssemblyTableId(), smartObjectId)),
      uint256(SmartAssemblyType.SMART_GATE)
    );

    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId
    );

    assertEq(uint8(currentState), uint8(State.ONLINE));
  }

  function testLinkSmartGates() public {
    smartGate.linkSmartGates(sourceGateId, destinationGateId);
    assert(smartGate.isGateLinked(sourceGateId, destinationGateId));
    assert(smartGate.isGateLinked(destinationGateId, sourceGateId));
  }

  function tesReverttLinkSmartGates() public {
     vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_SameSourceAndDestination.selector, sourceGateId, destinationGateId)
    );
    smartGate.linkSmartGates(sourceGateId, sourceGateId);
  }

  function testUnlinkSmartGates() public {
    testLinkSmartGates();
    smartGate.unlinkSmartGates(sourceGateId, destinationGateId);

    assert(!smartGate.isGateLinked(sourceGateId, destinationGateId));
  }

  function testRevertExistingLink() public {
    testLinkSmartGates();
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateAlreadyLinked.selector, sourceGateId, destinationGateId)
    );
    smartGate.linkSmartGates(sourceGateId, destinationGateId);
  }

  function testLinkRevertDistanceAboveMax() public {
    uint256 smartObjectIdA = 234;
    uint256 smartObjectIdB = 345;
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: address(1), tokenURI: "test" });
    WorldPosition memory worldPositionA = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 10000, y: 10000, z: 10000 })
    });

    WorldPosition memory worldPositionB = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 1000000000, y: 1000000000, z: 1000000000 })
    });

    uint256 fuelUnitVolume = 100;
    uint256 fuelConsumptionIntervalInSeconds = 100;
    uint256 fuelMaxCapacity = 100;
    smartDeployable.globalResume();
    smartGate.createAndAnchorSmartGate(
      smartObjectIdA,
      entityRecordData,
      smartObjectData,
      worldPositionA,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18, // fuelMaxCapacity,
      1 // maxDistance
    );

    smartDeployable.depositFuel(smartObjectIdA, 1);
    smartDeployable.bringOnline(smartObjectIdA);

    smartGate.createAndAnchorSmartGate(
      smartObjectIdB,
      entityRecordData,
      smartObjectData,
      worldPositionB,
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18, // fuelMaxCapacity,
      1 // maxDistance
    );

    smartDeployable.depositFuel(smartObjectIdB, 1);
    smartDeployable.bringOnline(smartObjectIdB);

    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_NotWithtinRange.selector, smartObjectIdA, smartObjectIdB)
    );
    smartGate.linkSmartGates(smartObjectIdA, smartObjectIdB);
  }

  function testRevertUnlinkSmartGates() public {
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateNotLinked.selector, sourceGateId, destinationGateId)
    );
    smartGate.unlinkSmartGates(sourceGateId, destinationGateId);
  }

  function testConfigureSmartGate() public {
    smartGate.configureSmartGate(sourceGateId, smartGateTesStystemId);

    ResourceId systemId = SmartGateConfigTable.getSystemId(DEPLOYMENT_NAMESPACE.smartGateConfigTableId(), sourceGateId);
    assertEq(systemId.getNamespace(), DEPLOYMENT_NAMESPACE);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(smartGateTesStystemId));
  }

  function testCanJump() public {
    testAnchorSmartGate(sourceGateId);
    testAnchorSmartGate(destinationGateId);
    testLinkSmartGates();
    assert(smartGate.canJump(characterId, sourceGateId, destinationGateId));
  }

  function testCanJumpFalse() public {
    testConfigureSmartGate();

    testAnchorSmartGate(sourceGateId);
    testAnchorSmartGate(destinationGateId);
    testLinkSmartGates();
    assert(!smartGate.canJump(characterId, sourceGateId, destinationGateId));
  }

  function testCanJump2way() public {
    testAnchorSmartGate(sourceGateId);
    testAnchorSmartGate(destinationGateId);
    testLinkSmartGates();
    assert(smartGate.canJump(characterId, destinationGateId, sourceGateId));
  }
}
