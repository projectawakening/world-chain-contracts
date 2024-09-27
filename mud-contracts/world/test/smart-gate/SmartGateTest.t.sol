// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_GATE_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/smart-gate/Utils.sol";
import { SmartGateLib } from "../../src/modules/smart-gate/SmartGateLib.sol";
import { State, SmartAssemblyType } from "../../src/modules/smart-deployable/types.sol";
import { SmartGateSystem } from "../../src/modules/smart-gate/systems/SmartGateSystem.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { EntityRecordData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as EntityRecordCharacter } from "../../src/modules/smart-character/types.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

import { SmartGateConfigTable } from "../../src/codegen/tables/SmartGateConfigTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { SmartAssemblyTable } from "../../src/codegen/tables/SmartAssemblyTable.sol";
import { DeployableState } from "../../src/codegen/tables/DeployableState.sol";

import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";

import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityRecordData as CharEntityRecordData } from "../../src/modules/smart-character/types.sol";

import { SmartGateCustomMock } from "./SmartGateCustomMock.sol";

/**
 * @title SmartGateTest
 * @dev Not including Fuzz test as it has issues
 */
contract SmartGateTest is MudTest {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartGateLib for SmartGateLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;

  IWorldWithEntryContext world;
  SmartCharacterLib.World smartCharacter;
  SmartGateLib.World smartGate;
  SmartDeployableLib.World smartDeployable;
  IERC721 erc721GateToken;
  bytes14 constant SMART_DEPLOYABLE_ERC721_NAMESPACE = "erc721deploybl";
  IERC721 erc721CharacterToken;
  bytes14 constant SMART_CHAR_ERC721_NAMESPACE = "erc721charactr";

  SmartGateCustomMock smartGateCustomMock;
  bytes14 constant CUSTOM_NAMESPACE = "custom-namespa";

  ResourceId SMART_GATE_CUSTOM_MOCK_SYSTEM_ID;

  uint256 sourceGateId = 1234;
  uint256 destinationGateId = 1235;

  uint256 characterId = 1111;

  uint256 tribeId = 1122;
  CharEntityRecordData charEntityRecordData = CharEntityRecordData({ itemId: 1234, typeId: 2345, volume: 0 });

  EntityRecordOffchainTableData charOffchainData =
    EntityRecordOffchainTableData({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });

  string tokenCID = "Qm1234abcdxxxx";

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // gate depoyable owner

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // BUILDER register a custom namespace
    vm.startPrank(alice);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(CUSTOM_NAMESPACE));
    SMART_GATE_CUSTOM_MOCK_SYSTEM_ID = ResourceId.wrap(
      (bytes32(abi.encodePacked(RESOURCE_SYSTEM, CUSTOM_NAMESPACE, "SmartGateCustomM")))
    );
    // BUILER deploy and register mock
    smartGateCustomMock = new SmartGateCustomMock();
    world.registerSystem(SMART_GATE_CUSTOM_MOCK_SYSTEM_ID, smartGateCustomMock, true);
    world.registerFunctionSelector(SMART_GATE_CUSTOM_MOCK_SYSTEM_ID, "canJump(uint256,uint256,uint256)");
    vm.stopPrank();

    vm.startPrank(deployer);
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartGate = SmartGateLib.World(world, DEPLOYMENT_NAMESPACE);
    smartCharacter = SmartCharacterLib.World(world, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);

    // create Smart Deployable Owner as Smart Character
    smartCharacter.createCharacter(characterId, alice, tribeId, charEntityRecordData, charOffchainData, tokenCID);

    erc721GateToken = IERC721(
      ERC721Registry.get(
        ERC721_REGISTRY_TABLE_ID,
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_ERC721_NAMESPACE)
      )
    );
    erc721CharacterToken = IERC721(
      ERC721Registry.get(ERC721_REGISTRY_TABLE_ID, WorldResourceIdLib.encodeNamespace(SMART_CHAR_ERC721_NAMESPACE))
    );

    smartDeployable.globalResume();
    vm.stopPrank();
  }

  function testSetup() public {
    address smartGateSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartGateSystemId());
    ResourceId smartGateSystemId = SystemRegistry.get(smartGateSystem);
    assertEq(smartGateSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testAnchorSmartGate(uint256 smartObjectId) public {
    vm.assume(smartObjectId != 0);
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 12345, itemId: 45, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 10000, y: 10000, z: 10000 })
    });

    uint256 fuelUnitVolume = 100;
    uint256 fuelConsumptionIntervalInSeconds = 100;
    uint256 fuelMaxCapacity = 100;

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

    assertEq(uint256(SmartAssemblyTable.get(smartObjectId)), uint256(SmartAssemblyType.SMART_GATE));

    State currentState = DeployableState.getCurrentState(smartObjectId);

    assertEq(uint8(currentState), uint8(State.ONLINE));
  }

  function testLinkSmartGates() public {
    smartGate.linkSmartGates(sourceGateId, destinationGateId);
    assert(smartGate.isGateLinked(sourceGateId, destinationGateId));
    assert(smartGate.isGateLinked(destinationGateId, sourceGateId));
  }

  function tesReverttLinkSmartGates() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        SmartGateSystem.SmartGate_SameSourceAndDestination.selector,
        sourceGateId,
        destinationGateId
      )
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
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });
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
    smartGate.configureSmartGate(sourceGateId, SMART_GATE_CUSTOM_MOCK_SYSTEM_ID);

    ResourceId systemId = SmartGateConfigTable.getSystemId(sourceGateId);
    assertEq(systemId.getNamespace(), CUSTOM_NAMESPACE);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(SMART_GATE_CUSTOM_MOCK_SYSTEM_ID));
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
