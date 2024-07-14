// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { console } from "forge-std/console.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

import { Entities } from "../src/systems/Entities.sol";
import { Tags } from "../src/systems/Tags.sol";
import { TaggedSystemMock } from "./mocks/TaggedSystemMock.sol";
import { UnTaggedSystemMock } from "./mocks/UnTaggedSystemMock.sol";

import "../src/codegen/index.sol";

import { Id, IdLib } from "../src/libs/Id.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../src/types/entityTypes.sol";
import { TAG_SYSTEM } from "../src/types/tagTypes.sol";

import { IErrors } from "../src/interfaces/IErrors.sol";

contract SmartObjectSystemTest is MudTest {
  IBaseWorld world;
  Entities entities;
  Tags tags;
  TaggedSystemMock taggedSystemMock;
  UnTaggedSystemMock unTaggedSystemMock;

  bytes14 constant NAMESPACE = bytes14("eveworld");
  ResourceId constant NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, NAMESPACE)));
  ResourceId constant ENTITIES_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("Entities")))));
  ResourceId constant TAGS_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("Tags")))));
  ResourceId constant TAGGED_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystemMock")))));
  ResourceId constant UNTAGGED_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("UnTaggedSystemMo")))));

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

    // START: deploy and register TaggedSystemMock.sol/UnTaggedSystemMock.sol, and functions
    vm.startPrank(deployer);
    taggedSystemMock = new TaggedSystemMock();
    world.registerSystem(TAGGED_SYSTEM_ID, System(taggedSystemMock), true);
    world.registerFunctionSelector(TAGGED_SYSTEM_ID, "allowClassLevelScope(bytes32)");
    world.registerFunctionSelector(TAGGED_SYSTEM_ID, "allowObjectLevelScope(bytes32)");

    unTaggedSystemMock = new UnTaggedSystemMock();
    world.registerSystem(UNTAGGED_SYSTEM_ID, System(unTaggedSystemMock), true);
    world.registerFunctionSelector(UNTAGGED_SYSTEM_ID, "blockClassLevelScope(bytes32)");
    world.registerFunctionSelector(UNTAGGED_SYSTEM_ID, "blockObjectLevelScope(bytes32)");

    // register tags
    Id[] memory tagIds = new Id[](2);
    tagIds[0] = taggedSystemTagId;
    tagIds[1] = unTaggedSystemTagId;

    // register Class with TaggedSystemMock tag
    Id[] memory systemTagIds = new Id[](1);
    systemTagIds[0] = taggedSystemTagId;
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.registerClass, (classId, systemTagIds))
    );

    // register UnTagged Class
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.registerClass, (unTaggedClassId, new Id[](0)))
    );

    // instantiate Class<>Object
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.instantiate, (classId, objectId))
    );

    // instantiate Untagged Class<>Object
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.instantiate, (unTaggedClassId, unTaggedObjectId))
    );
    vm.stopPrank();
  }

  function testSetup() public {
    // mock systems are registered on the World
    assertEq(ResourceIds.getExists(TAGGED_SYSTEM_ID), true);
    assertEq(ResourceIds.getExists(UNTAGGED_SYSTEM_ID), true);

    // mock functions are registered on the World
    string memory taggedSystemNamespaceString = WorldResourceIdLib.toTrimmedString(WorldResourceIdInstance.getNamespace(TAGGED_SYSTEM_ID));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(taggedSystemNamespaceString, "__", "allowClassLevelScope(bytes32)")))))), ResourceId.unwrap(TAGGED_SYSTEM_ID));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(taggedSystemNamespaceString, "__", "allowObjectLevelScope(bytes32)")))))), ResourceId.unwrap(TAGGED_SYSTEM_ID));

    string memory unTaggedSystemNamespaceString = WorldResourceIdLib.toTrimmedString(WorldResourceIdInstance.getNamespace(UNTAGGED_SYSTEM_ID));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(unTaggedSystemNamespaceString, "__", "blockClassLevelScope(bytes32)")))))), ResourceId.unwrap(UNTAGGED_SYSTEM_ID));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(unTaggedSystemNamespaceString, "__", "blockObjectLevelScope(bytes32)")))))), ResourceId.unwrap(UNTAGGED_SYSTEM_ID));
    
    // check Class is registered
    assertEq(Classes.getExists(classId), true);

    // check TaggedSystemMock<>Class tag
    assertEq(ClassSystemTagMap.getHasTag(classId, taggedSystemTagId), true);

    // check Class<>Object instantiation
    assertEq(ClassObjectMap.getInstanceOf(classId, objectId), true);

    // check Object is registered
    assertEq(Objects.getExists(objectId), true);

    // check Untagged Class<>Object instantiation
    assertEq(ClassObjectMap.getInstanceOf(unTaggedClassId, unTaggedObjectId), true);
  }

  function testClassScope() public {
    // revert call TaggedSystemMock using unTaggedClassId
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.InvalidSystemCall.selector,
        unTaggedClassId,
        TAGGED_SYSTEM_ID
      )
    );
    world.call(
      TAGGED_SYSTEM_ID,
      abi.encodeCall(TaggedSystemMock.allowClassLevelScope, (unTaggedClassId))
    );

    // revert call UntaggedSystemMock using classId
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.InvalidSystemCall.selector,
        classId,
        UNTAGGED_SYSTEM_ID
      )
    );
    world.call(
      UNTAGGED_SYSTEM_ID,
      abi.encodeCall(UnTaggedSystemMock.blockClassLevelScope, (classId))
    );

    // success call TaggedSystemMock using classId
    bytes memory returnData = world.call(
      TAGGED_SYSTEM_ID,
      abi.encodeCall(TaggedSystemMock.allowClassLevelScope, (classId))
    );
    assertEq(abi.decode(returnData, (bool)), true);
  }

  function testObjectScope() public {
    // revert call TaggedSystemMock using untaggedObjectId
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.InvalidSystemCall.selector,
        unTaggedObjectId,
        TAGGED_SYSTEM_ID
      )
    );
    world.call(
      TAGGED_SYSTEM_ID,
      abi.encodeCall(TaggedSystemMock.allowObjectLevelScope, (unTaggedObjectId))
    );

    // revert call UntaggedSystemMock using objectId
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.InvalidSystemCall.selector,
        objectId,
        UNTAGGED_SYSTEM_ID
      )
    );
    world.call(
      UNTAGGED_SYSTEM_ID,
      abi.encodeCall(UnTaggedSystemMock.blockObjectLevelScope, (objectId))
    );

    // success call TaggedSystemMock using the objectId
    bytes memory returnData = world.call(
      TAGGED_SYSTEM_ID,
      abi.encodeCall(TaggedSystemMock.allowObjectLevelScope, (objectId))
    );
    assertEq(abi.decode(returnData, (bool)), true);
  }
}
