// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

import { SmartGateConfig } from "../../src/namespaces/evefrontier/codegen/tables/SmartGateConfig.sol";
import { DeployableState } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { SmartAssembly } from "../../src/namespaces/evefrontier/codegen/tables/SmartAssembly.sol";
import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { SmartGateCustomMock } from "./SmartGateCustomMock.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { WorldPosition, Coord } from "../../src/namespaces/evefrontier/systems/location/types.sol";

import { SmartGateSystem } from "../../src/namespaces/evefrontier/systems/smart-gate/SmartGateSystem.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { SmartGateSystemLib, smartGateSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { CreateAndAnchorDeployableParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

import { LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";

import { SMART_GATE } from "../../src/namespaces/evefrontier/systems/constants.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";

contract SmartGateTest is MudTest {
  IWorldWithContext world;
  SmartGateCustomMock smartGateCustomMock;
  bytes14 constant CUSTOM_NAMESPACE = "custom-namespa";

  ResourceId SMART_GATE_CUSTOM_MOCK_SYSTEM_ID;

  uint256 smartObjectId = 777777;
  uint256 sourceGateId = 1234;
  uint256 destinationGateId = 1235;

  uint256 characterId = 1111;
  uint256 tribeId = 1122;
  string tokenCID = "Qm1234abcdxxxx";
  uint256 fuelUnitVolume = 100;
  uint256 fuelConsumptionIntervalInSeconds = 100;
  uint256 fuelMaxCapacity = 100;
  uint256 maxDistance = 100000000 * 1e18;

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

    SMART_GATE_CUSTOM_MOCK_SYSTEM_ID = ResourceId.wrap(
      (bytes32(abi.encodePacked(RESOURCE_SYSTEM, CUSTOM_NAMESPACE, "SmartGateCustomM")))
    );
    // BUILDER deploy and register mock
    smartGateCustomMock = new SmartGateCustomMock();
    world.registerSystem(SMART_GATE_CUSTOM_MOCK_SYSTEM_ID, smartGateCustomMock, true);
    world.registerFunctionSelector(SMART_GATE_CUSTOM_MOCK_SYSTEM_ID, "canJump(uint256,uint256,uint256)");
    vm.stopPrank();

    vm.startPrank(deployer);
    deployableSystem.globalResume();
    smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);
    vm.stopPrank();
  }

  function testAnchorSmartGate() public {
    _anchorSmartGate(smartObjectId);

    assertEq(SmartAssembly.getSmartAssemblyType(smartObjectId), SMART_GATE);

    State currentState = DeployableState.getCurrentState(smartObjectId);
    assertEq(uint8(currentState), uint8(State.ONLINE));
  }

  function testLinkSmartGates() public {
    _anchorSmartGate(sourceGateId);
    _anchorSmartGate(destinationGateId);
    _linkSmartGates(sourceGateId, destinationGateId);

    bool isLinked = smartGateSystem.isGateLinked(sourceGateId, destinationGateId);
    assert(isLinked);

    isLinked = smartGateSystem.isGateLinked(destinationGateId, sourceGateId);
    assert(isLinked);
  }

  function tesRevertLinkSmartGates() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        SmartGateSystem.SmartGate_SameSourceAndDestination.selector,
        sourceGateId,
        destinationGateId
      )
    );

    vm.startPrank(alice);
    smartGateSystem.linkSmartGates(sourceGateId, sourceGateId);
    vm.stopPrank();
  }

  function testUnlinkSmartGates() public {
    _anchorSmartGate(sourceGateId);
    _anchorSmartGate(destinationGateId);
    _linkSmartGates(sourceGateId, destinationGateId);

    vm.startPrank(alice);
    smartGateSystem.unlinkSmartGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    bool isLinked = smartGateSystem.isGateLinked(sourceGateId, destinationGateId);
    assert(!isLinked);
  }

  function testRevertExistingLink() public {
    _anchorSmartGate(sourceGateId);
    _anchorSmartGate(destinationGateId);
    _linkSmartGates(sourceGateId, destinationGateId);

    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateAlreadyLinked.selector, sourceGateId, destinationGateId)
    );

    vm.startPrank(alice);
    smartGateSystem.linkSmartGates(sourceGateId, destinationGateId);
    vm.stopPrank();
  }

  function testLinkRevertDistanceAboveMax() public {
    uint256 smartObjectIdA = 234;
    uint256 smartObjectIdB = 345;
    WorldPosition memory worldPositionA = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 10000, y: 10000, z: 10000 })
    });

    WorldPosition memory worldPositionB = WorldPosition({
      solarSystemId: 1,
      position: Coord({ x: 1000000000, y: 1000000000, z: 1000000000 })
    });

    vm.startPrank(deployer);
    smartGateSystem.createAndAnchorSmartGate(
      CreateAndAnchorDeployableParams({
        smartObjectId: smartObjectIdA,
        smartAssemblyType: SMART_GATE,
        entityRecordData: entityRecord,
        smartObjectData: smartObjectData,
        fuelUnitVolume: fuelUnitVolume,
        fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity: fuelMaxCapacity,
        locationData: LocationData({
          solarSystemId: worldPositionA.solarSystemId,
          x: worldPositionA.position.x,
          y: worldPositionA.position.y,
          z: worldPositionA.position.z
        })
      }),
      1 // maxDistance
    );

    fuelSystem.depositFuel(smartObjectIdA, 1);
    deployableSystem.bringOnline(smartObjectIdA);

    smartGateSystem.createAndAnchorSmartGate(
      CreateAndAnchorDeployableParams({
        smartObjectId: smartObjectIdB,
        smartAssemblyType: SMART_GATE,
        entityRecordData: entityRecord,
        smartObjectData: smartObjectData,
        fuelUnitVolume: fuelUnitVolume,
        fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity: fuelMaxCapacity,
        locationData: LocationData({
          solarSystemId: worldPositionB.solarSystemId,
          x: worldPositionB.position.x,
          y: worldPositionB.position.y,
          z: worldPositionB.position.z
        })
      }),
      1 // maxDistance
    );

    fuelSystem.depositFuel(smartObjectIdB, 1);
    deployableSystem.bringOnline(smartObjectIdB);
    vm.stopPrank();

    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_NotWithtinRange.selector, smartObjectIdA, smartObjectIdB)
    );

    vm.startPrank(alice);
    smartGateSystem.linkSmartGates(smartObjectIdA, smartObjectIdB);
    vm.stopPrank();
  }

  function testRevertUnlinkSmartGates() public {
    _anchorSmartGate(sourceGateId);
    _anchorSmartGate(destinationGateId);

    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateNotLinked.selector, sourceGateId, destinationGateId)
    );

    vm.startPrank(alice);
    smartGateSystem.unlinkSmartGates(sourceGateId, destinationGateId);
    vm.stopPrank();
  }

  function testConfigureSmartGate() public {
    _anchorSmartGate(sourceGateId);
    _configureSmartGate(sourceGateId, SMART_GATE_CUSTOM_MOCK_SYSTEM_ID);

    ResourceId systemId = SmartGateConfig.getSystemId(sourceGateId);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(SMART_GATE_CUSTOM_MOCK_SYSTEM_ID));
  }

  function testCanJump() public {
    _anchorSmartGate(sourceGateId);
    _anchorSmartGate(destinationGateId);
    _linkSmartGates(sourceGateId, destinationGateId);

    bool canJump = smartGateSystem.canJump(characterId, sourceGateId, destinationGateId);
    assert(canJump);
  }

  function testCanJumpFalse() public {
    _anchorSmartGate(sourceGateId);
    _configureSmartGate(sourceGateId, SMART_GATE_CUSTOM_MOCK_SYSTEM_ID);
    _anchorSmartGate(destinationGateId);
    _linkSmartGates(sourceGateId, destinationGateId);

    bool canJump = smartGateSystem.canJump(characterId, sourceGateId, destinationGateId);
    assert(!canJump);
  }

  function testCanJump2way() public {
    _anchorSmartGate(destinationGateId);
    _anchorSmartGate(sourceGateId);
    _linkSmartGates(destinationGateId, sourceGateId);

    bool canJump = smartGateSystem.canJump(characterId, destinationGateId, sourceGateId);
    assert(canJump);
  }

  function testDeployerCannotConfigureSmartGate() public {
    _anchorSmartGate(sourceGateId);

    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotDeployableOwner.selector, deployer, sourceGateId));

    vm.startPrank(deployer);
    smartGateSystem.configureSmartGate(sourceGateId, SMART_GATE_CUSTOM_MOCK_SYSTEM_ID);
    vm.stopPrank();
  }

  function testDeployerCannotLinkSmartGates() public {
    _anchorSmartGate(sourceGateId);
    _anchorSmartGate(destinationGateId);

    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotDeployableOwner.selector, deployer, sourceGateId));

    vm.startPrank(deployer);
    smartGateSystem.linkSmartGates(sourceGateId, destinationGateId);
    vm.stopPrank();
  }

  function _anchorSmartGate(uint256 _id) internal {
    vm.startPrank(deployer);
    smartGateSystem.createAndAnchorSmartGate(
      CreateAndAnchorDeployableParams({
        smartObjectId: _id,
        smartAssemblyType: SMART_GATE,
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
      }),
      maxDistance
    );

    fuelSystem.depositFuel(_id, 1);
    deployableSystem.bringOnline(_id);
    vm.stopPrank();
  }

  function _configureSmartGate(uint256 _id, ResourceId _systemId) internal {
    vm.startPrank(alice);
    smartGateSystem.configureSmartGate(_id, _systemId);
    vm.stopPrank();
  }

  function _linkSmartGates(uint256 _sourceId, uint256 _destinationId) internal {
    vm.startPrank(alice);
    smartGateSystem.linkSmartGates(_sourceId, _destinationId);
    vm.stopPrank();
  }
}
