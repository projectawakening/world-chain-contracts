// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Testing frameworks
import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { EveTest } from "../EveTest.sol";

// External dependencies
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

// Core interfaces and types
import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { State } from "../../src/codegen/common.sol";
import { ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

// Tables and data structures
import { DeployableState, Anchor, AnchorData, AnchoredTo } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { Location, LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { Fuel, FuelData } from "../../src/namespaces/evefrontier/codegen/tables/Fuel.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorDeployableParams, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// System contracts
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";
import { AnchorSystem } from "../../src/namespaces/evefrontier/systems/anchor/AnchorSystem.sol";

// System libraries
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { AnchorSystemLib, anchorSystem } from "../../src/namespaces/evefrontier/codegen/systems/AnchorSystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { eveSystem } from "../../src/namespaces/evefrontier/codegen/systems/EveSystemLib.sol";

contract AnchorSystemTest is EveTest {
  uint256 characterId = 1111;
  uint256 tribeId = 1122;
  uint256 anchorId = 12345;
  uint256 deployableId1 = 54321;
  uint256 deployableId2 = 98765;

  uint256 initialFuel = 150;

  EntityRecordData entityRecord;
  SmartObjectData smartObjectData;
  LocationData locationData;

  function setUp() public virtual override {
    super.setUp();
    world = IWorldWithContext(worldAddress);

    entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "Anchor",
      dappURL: "dappURL",
      description: "A simple anchor deployable"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    locationData = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    vm.startPrank(deployer);

    // Register classes and configure access using EveSystem library
    eveSystem.registerAnchorClass(uint256(bytes32("ANCHOR")));
    eveSystem.configureAnchorAccess();

    deployableSystem.globalResume();
    smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);
    vm.stopPrank();
  }

  function testCreateAnchor() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Verify the anchor was created
    uint256 createdAt = Anchor.getCreatedAt(anchorId);
    assertGt(createdAt, 0, "Anchor should have been created");

    // Verify the anchor has no anchored objects
    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    assertEq(anchoredObjects.length, 0, "Newly created anchor should have no anchored objects");

    vm.stopPrank();
  }

  function testCreateAnchorAlreadyExists() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Try to create the same anchor again, should revert
    vm.expectRevert(abi.encodeWithSelector(AnchorSystem.AnchorSystem_AnchorAlreadyExists.selector, anchorId));
    anchorSystem.createAnchor(anchorId);

    vm.stopPrank();
  }

  function testAnchorDeployable() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Create a deployable
    _createDeployable(deployableId1);

    // Anchor the deployable
    anchorSystem.anchorDeployable(anchorId, deployableId1);

    // Verify the deployable is anchored
    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    assertEq(anchoredObjects.length, 1, "Anchor should have one anchored object");
    assertEq(anchoredObjects[0], deployableId1, "Anchored object should be the deployable");

    // Verify the deployable is anchored to the anchor
    uint256 anchoredAt = AnchoredTo.getAnchoredAt(deployableId1, anchorId);
    assertGt(anchoredAt, 0, "Deployable should be anchored to the anchor");

    vm.stopPrank();
  }

  function testAnchorDeployableAnchorNotFound() public {
    vm.startPrank(deployer);

    // Create a deployable
    _createDeployable(deployableId1);

    // Try to anchor the deployable to a non-existent anchor, should revert
    vm.expectRevert(abi.encodeWithSelector(AnchorSystem.AnchorSystem_AnchorNotFound.selector, anchorId));
    anchorSystem.anchorDeployable(anchorId, deployableId1);

    vm.stopPrank();
  }

  function testAnchorDeployableDeployableNotFound() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Try to anchor a non-existent deployable, should revert
    vm.expectRevert(abi.encodeWithSelector(AnchorSystem.AnchorSystem_DeployableNotFound.selector, deployableId1));
    anchorSystem.anchorDeployable(anchorId, deployableId1);

    vm.stopPrank();
  }

  function testAnchorMultipleDeployables() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Create two deployables
    _createDeployable(deployableId1);
    _createDeployable(deployableId2);

    // Anchor both deployables
    anchorSystem.anchorDeployable(anchorId, deployableId1);
    anchorSystem.anchorDeployable(anchorId, deployableId2);

    // Verify both deployables are anchored
    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    assertEq(anchoredObjects.length, 2, "Anchor should have two anchored objects");

    // Check that both deployables are in the anchored objects array
    bool foundDeployable1 = false;
    bool foundDeployable2 = false;

    for (uint256 i = 0; i < anchoredObjects.length; i++) {
      if (anchoredObjects[i] == deployableId1) {
        foundDeployable1 = true;
      } else if (anchoredObjects[i] == deployableId2) {
        foundDeployable2 = true;
      }
    }

    assertTrue(foundDeployable1, "Deployable 1 should be anchored");
    assertTrue(foundDeployable2, "Deployable 2 should be anchored");

    vm.stopPrank();
  }

  function testUnanchorDeployable() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Create a deployable
    _createDeployable(deployableId1);

    // Anchor the deployable
    anchorSystem.anchorDeployable(anchorId, deployableId1);

    // Unanchor the deployable
    anchorSystem.unanchorDeployable(anchorId, deployableId1);

    // Verify the deployable is no longer anchored
    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    assertEq(anchoredObjects.length, 0, "Anchor should have no anchored objects after unanchoring");

    // Verify the deployable is no longer anchored to the anchor
    uint256 anchoredAt = AnchoredTo.getAnchoredAt(deployableId1, anchorId);
    assertEq(anchoredAt, 0, "Deployable should not be anchored to the anchor after unanchoring");

    vm.stopPrank();
  }

  function testUnanchorDeployableAnchorNotFound() public {
    vm.startPrank(deployer);

    // Create a deployable
    _createDeployable(deployableId1);

    // Try to unanchor the deployable from a non-existent anchor, should revert
    vm.expectRevert(abi.encodeWithSelector(AnchorSystem.AnchorSystem_AnchorNotFound.selector, anchorId));
    anchorSystem.unanchorDeployable(anchorId, deployableId1);

    vm.stopPrank();
  }

  function testUnanchorDeployableNotAnchored() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Create a deployable
    _createDeployable(deployableId1);

    // Try to unanchor a deployable that is not anchored, should revert
    vm.expectRevert(
      abi.encodeWithSelector(AnchorSystem.AnchorSystem_DeployableNotAnchored.selector, deployableId1, anchorId)
    );
    anchorSystem.unanchorDeployable(anchorId, deployableId1);

    vm.stopPrank();
  }

  function testUnanchorOneOfMultipleDeployables() public {
    vm.startPrank(deployer);

    // Create an anchor
    anchorSystem.createAnchor(anchorId);

    // Create two deployables
    _createDeployable(deployableId1);
    _createDeployable(deployableId2);

    // Anchor both deployables
    anchorSystem.anchorDeployable(anchorId, deployableId1);
    anchorSystem.anchorDeployable(anchorId, deployableId2);

    // Unanchor one deployable
    anchorSystem.unanchorDeployable(anchorId, deployableId1);

    // Verify only one deployable remains anchored
    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    assertEq(anchoredObjects.length, 1, "Anchor should have one anchored object after unanchoring one");
    assertEq(anchoredObjects[0], deployableId2, "The remaining anchored object should be deployable 2");

    // Verify deployable 1 is no longer anchored
    uint256 anchoredAt1 = AnchoredTo.getAnchoredAt(deployableId1, anchorId);
    assertEq(anchoredAt1, 0, "Deployable 1 should not be anchored after unanchoring");

    // Verify deployable 2 is still anchored
    uint256 anchoredAt2 = AnchoredTo.getAnchoredAt(deployableId2, anchorId);
    assertGt(anchoredAt2, 0, "Deployable 2 should still be anchored");

    vm.stopPrank();
  }

  // Helper function to create a deployable
  function _createDeployable(uint256 deployableId) internal {
    uint256 fuelUnitVolume = 1;
    uint256 fuelConsumptionIntervalInSeconds = 1;
    uint256 fuelMaxCapacity = 100_000;

    CreateAndAnchorDeployableParams memory params = CreateAndAnchorDeployableParams({
      smartObjectId: deployableId,
      smartAssemblyType: "TEST",
      entityRecordData: entityRecord,
      smartObjectData: smartObjectData,
      locationData: locationData,
      fuelUnitVolume: fuelUnitVolume,
      fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity: fuelMaxCapacity
    });

    deployableSystem.createAndAnchorDeployable(params);
  }
}
