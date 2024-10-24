// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { DEPLOYMENT_NAMESPACE } from "../src/namespaces/evefrontier/constants.sol";
import { EntitySystem } from "../src/namespaces/evefrontier/systems/entity-system/EntitySystem.sol";
import { Utils as EntitySystemUtils } from "../src/namespaces/evefrontier/systems/entity-system/Utils.sol";

import { SystemMock } from "./mocks/SystemMock.sol";

import "../src/namespaces/evefrontier/codegen/index.sol";

import { Id, IdLib } from "../src/libs/Id.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../src/types/entityTypes.sol";
import { TAG_SYSTEM } from "../src/types/tagTypes.sol";

import { SmartObjectFramework } from "../src/inherit/SmartObjectFramework.sol";

contract SmartObjectFrameworkTest is MudTest {
  using EntitySystemUtils for bytes14;

  IBaseWorld world;
  SystemMock taggedSystemMock;
  SystemMock unTaggedSystemMock;

  bytes14 constant NAMESPACE = DEPLOYMENT_NAMESPACE;
  ResourceId constant NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, NAMESPACE)));
  ResourceId ENTITY_SYSTEM_ID = EntitySystemUtils.entitySystemId();
  ResourceId constant TAGGED_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystemMock")))));
  ResourceId constant UNTAGGED_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("UnTaggedSystemMo")))));

  Id classId = IdLib.encode(ENTITY_CLASS, bytes30("TEST_CLASS"));
  Id unTaggedClassId = IdLib.encode(ENTITY_CLASS, bytes30("TEST_FAIL_CLASS"));
  Id objectId = IdLib.encode(ENTITY_OBJECT, bytes30("TEST_OBJECT"));
  Id unTaggedObjectId = IdLib.encode(ENTITY_OBJECT, bytes30("TEST_FAIL_OBJECT"));
  Id taggedSystemTagId = IdLib.encode(TAG_SYSTEM, TAGGED_SYSTEM_ID.getResourceName());
  Id unTaggedSystemTagId = IdLib.encode(TAG_SYSTEM, UNTAGGED_SYSTEM_ID.getResourceName());

  function setUp() public override {
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPK = vm.deriveKey(mnemonic, 0);
    address deployer = vm.addr(deployerPK);

    // START: DEPLOY AND REGISTER A MUD WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IBaseWorld(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // START: deploy and register tagged and untagged SystemMock.sol, and functions
    vm.startPrank(deployer);
    taggedSystemMock = new SystemMock();
    world.registerSystem(TAGGED_SYSTEM_ID, System(taggedSystemMock), true);

    unTaggedSystemMock = new SystemMock();
    world.registerSystem(UNTAGGED_SYSTEM_ID, System(unTaggedSystemMock), true);

    // system tags (only add the tagged systems)
    Id[] memory tagIds = new Id[](1);
    tagIds[0] = taggedSystemTagId;

    // register Class (with a taggedSystem tag)
    world.call(ENTITY_SYSTEM_ID, abi.encodeCall(EntitySystem.registerClass, (classId, tagIds)));

    // register untagged Class
    world.call(ENTITY_SYSTEM_ID, abi.encodeCall(EntitySystem.registerClass, (unTaggedClassId, new Id[](0))));

    // instantiate tagged Class->Object
    world.call(ENTITY_SYSTEM_ID, abi.encodeCall(EntitySystem.instantiate, (classId, objectId)));

    // instantiate untagged Class->Object
    world.call(ENTITY_SYSTEM_ID, abi.encodeCall(EntitySystem.instantiate, (unTaggedClassId, unTaggedObjectId)));
    vm.stopPrank();
  }

  function testSetup() public {
    // mock systems are registered on the World
    assertEq(ResourceIds.getExists(TAGGED_SYSTEM_ID), true);
    assertEq(ResourceIds.getExists(UNTAGGED_SYSTEM_ID), true);

    // check Class is registered
    assertEq(Classes.getExists(classId), true);

    // check tagged SystemMock<>Class tag
    assertEq(ClassSystemTagMap.getHasTag(classId, taggedSystemTagId), true);

    // check Class->Object instantiation
    assertEq(ClassObjectMap.getInstanceOf(classId, objectId), true);

    // check Object is created
    assertEq(Objects.getExists(objectId), true);

    // check Untagged Class->Object instantiation
    assertEq(ClassObjectMap.getInstanceOf(unTaggedClassId, unTaggedObjectId), true);

    // check unTagged Object is created
    assertEq(Objects.getExists(unTaggedObjectId), true);
  }

  function testClassScope() public {
    // revert call TaggedSystemMock using unTaggedClassId
    vm.expectRevert(
      abi.encodeWithSelector(SmartObjectFramework.SOF_UnscopedSystemCall.selector, unTaggedClassId, TAGGED_SYSTEM_ID)
    );
    world.call(TAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.classLevelScope, (unTaggedClassId)));

    // revert call UntaggedSystemMock using classId
    vm.expectRevert(
      abi.encodeWithSelector(SmartObjectFramework.SOF_UnscopedSystemCall.selector, classId, UNTAGGED_SYSTEM_ID)
    );
    world.call(UNTAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.classLevelScope, (classId)));

    // success call TaggedSystemMock using classId
    bytes memory returnData = world.call(TAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.classLevelScope, (classId)));
    assertEq(abi.decode(returnData, (bool)), true);
  }

  function testObjectScope() public {
    // revert call SystemMock using untaggedObjectId
    vm.expectRevert(
      abi.encodeWithSelector(SmartObjectFramework.SOF_UnscopedSystemCall.selector, unTaggedObjectId, TAGGED_SYSTEM_ID)
    );
    world.call(TAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.objectLevelScope, (unTaggedObjectId)));

    // revert call UntaggedSystemMock using untagged objectId
    vm.expectRevert(
      abi.encodeWithSelector(SmartObjectFramework.SOF_UnscopedSystemCall.selector, objectId, UNTAGGED_SYSTEM_ID)
    );
    world.call(UNTAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.objectLevelScope, (objectId)));

    // success call SystemMock using the tagged objectId
    bytes memory returnData = world.call(TAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.objectLevelScope, (objectId)));

    assertEq(abi.decode(returnData, (bool)), true);
  }

  function testContext() public {
    // revert, test WorldContextProvider cannot be used to make direct calls
    vm.expectRevert(bytes(""));
    world.call(TAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.callFromWorldContextProviderLib, ()));

    // revert, test WorldContextProvider cannot be used to make direct delegatecalls to functions with context()
    vm.expectRevert(SmartObjectFramework.SOF_InvalidCall.selector);
    world.call(TAGGED_SYSTEM_ID, abi.encodeCall(SystemMock.delegatecallFromWorldContextProviderLib, ()));
  }
}
