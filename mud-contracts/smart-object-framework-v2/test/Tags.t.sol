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
import { TaggedSystemMock2 } from "./mocks/TaggedSystemMock2.sol";
import { TaggedSystemMock3 } from "./mocks/TaggedSystemMock3.sol";
import { UnTaggedSystemMock } from "./mocks/UnTaggedSystemMock.sol";

import "../src/codegen/index.sol";

import { Id, IdLib } from "../src/libs/Id.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../src/types/entityTypes.sol";
import { TAG_SYSTEM } from "../src/types/tagTypes.sol";

import { IErrors } from "../src/interfaces/IErrors.sol";

contract TagsTest is MudTest {
  IBaseWorld world;
  Entities entities;
  Tags tags;
  TaggedSystemMock taggedSystemMock;
  TaggedSystemMock2 taggedSystemMock2;
  TaggedSystemMock3 taggedSystemMock3;
  UnTaggedSystemMock unTaggedSystemMock;

  bytes14 constant NAMESPACE = bytes14("eveworld");
  ResourceId constant NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, NAMESPACE)));
  ResourceId constant ENTITIES_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("Entities")))));
  ResourceId constant TAGS_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("Tags")))));
  ResourceId constant TAGGED_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystemMock")))));
  ResourceId constant TAGGED_SYSTEM_ID_2 = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystemMoc2")))));
  ResourceId constant TAGGED_SYSTEM_ID_3 = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystemMoc3")))));
  ResourceId constant UNTAGGED_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("UnTaggedSystemMo")))));
  ResourceId constant UNREGISTERED_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("UnregisteredSyst")))));

  Id classId = IdLib.encode(ENTITY_CLASS, bytes30("TEST_CLASS"));
  Id classId2 = IdLib.encode(ENTITY_CLASS, bytes30("TEST_CLASS_2"));
  Id objectId = IdLib.encode(ENTITY_OBJECT, bytes30("TEST_OBJECT"));
  Id unregisteredClassId = IdLib.encode(ENTITY_CLASS, bytes30("FAIL_REGISTER_CLASS"));
  Id taggedSystemTagId = IdLib.encode(TAG_SYSTEM, TAGGED_SYSTEM_ID.getResourceName());
  Id taggedSystemTagId2 = IdLib.encode(TAG_SYSTEM, TAGGED_SYSTEM_ID_2.getResourceName());
  Id taggedSystemTagId3 = IdLib.encode(TAG_SYSTEM, TAGGED_SYSTEM_ID_3.getResourceName());
  Id untaggedSystemTagId = IdLib.encode(TAG_SYSTEM, UNTAGGED_SYSTEM_ID.getResourceName());
  Id nonSystemTagId = IdLib.encode(bytes2("no"), TAGGED_SYSTEM_ID.getResourceName());
  Id unregisteredSystemTagId = IdLib.encode(TAG_SYSTEM, UNREGISTERED_SYSTEM_ID.getResourceName());
  
  function setUp() public override {
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPK = vm.deriveKey(mnemonic, 0);
    address deployer = vm.addr(deployerPK);

    // START: DEPLOY AND REGISTER A MUD WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IBaseWorld(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // START: deploy and register mock systems and functions
    vm.startPrank(deployer);
    taggedSystemMock = new TaggedSystemMock();
    world.registerSystem(TAGGED_SYSTEM_ID, System(taggedSystemMock), true);
    world.registerFunctionSelector(TAGGED_SYSTEM_ID, "allowClassLevelScope(bytes32)");
    world.registerFunctionSelector(TAGGED_SYSTEM_ID, "allowObjectLevelScope(bytes32)");

    taggedSystemMock2 = new TaggedSystemMock2();
    world.registerSystem(TAGGED_SYSTEM_ID_2, System(taggedSystemMock2), true);
    world.registerFunctionSelector(TAGGED_SYSTEM_ID_2, "allowClassLevelScope2(bytes32)");
    world.registerFunctionSelector(TAGGED_SYSTEM_ID_2, "allowObjectLevelScope2(bytes32)");

    taggedSystemMock3 = new TaggedSystemMock3();
    world.registerSystem(TAGGED_SYSTEM_ID_3, System(taggedSystemMock3), true);
    world.registerFunctionSelector(TAGGED_SYSTEM_ID_3, "allowClassLevelScope3(bytes32)");
    world.registerFunctionSelector(TAGGED_SYSTEM_ID_3, "allowObjectLevelScope3(bytes32)");

    unTaggedSystemMock = new UnTaggedSystemMock();
    world.registerSystem(UNTAGGED_SYSTEM_ID, System(unTaggedSystemMock), true);
    world.registerFunctionSelector(UNTAGGED_SYSTEM_ID, "blockClassLevelScope(bytes32)");
    world.registerFunctionSelector(UNTAGGED_SYSTEM_ID, "blockObjectLevelScope(bytes32)");

    // register Class without any tags
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.registerClass, (classId, new Id[](0)))
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

    string memory mockTagged2NamespaceString = WorldResourceIdLib.toTrimmedString(WorldResourceIdInstance.getNamespace(TAGGED_SYSTEM_ID_2));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(mockTagged2NamespaceString, "__", "allowClassLevelScope2(bytes32)")))))), ResourceId.unwrap(TAGGED_SYSTEM_ID_2));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(mockTagged2NamespaceString, "__", "allowObjectLevelScope2(bytes32)")))))), ResourceId.unwrap(TAGGED_SYSTEM_ID_2));
    
    string memory mockTagged3NamespaceString = WorldResourceIdLib.toTrimmedString(WorldResourceIdInstance.getNamespace(TAGGED_SYSTEM_ID_3));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(mockTagged3NamespaceString, "__", "allowClassLevelScope3(bytes32)")))))), ResourceId.unwrap(TAGGED_SYSTEM_ID_3));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(mockTagged3NamespaceString, "__", "allowObjectLevelScope3(bytes32)")))))), ResourceId.unwrap(TAGGED_SYSTEM_ID_3)); 
    
    string memory unTaggedSystemNamespaceString = WorldResourceIdLib.toTrimmedString(WorldResourceIdInstance.getNamespace(UNTAGGED_SYSTEM_ID));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(unTaggedSystemNamespaceString, "__", "blockClassLevelScope(bytes32)")))))), ResourceId.unwrap(UNTAGGED_SYSTEM_ID));
    assertEq(ResourceId.unwrap(FunctionSelectors.getSystemId(bytes4(keccak256(bytes(string.concat(unTaggedSystemNamespaceString, "__", "blockObjectLevelScope(bytes32)")))))), ResourceId.unwrap(UNTAGGED_SYSTEM_ID));
    
    // check Class is registered
    assertEq(Classes.getExists(classId), true);
  }

  function testSetSystemTag() public {
    // reverts if classId has NOT been registered
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.ClassDoesNotExist.selector,
        unregisteredClassId
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (unregisteredClassId, taggedSystemTagId))
    );

    // revert for bytes32(0) tagId
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.InvalidTagId.selector,
        Id.wrap(bytes32(0))
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (classId, Id.wrap(bytes32(0))))
    );

    // revert if tag type is not TAG_SYSTEM
    bytes2[] memory expected = new bytes2[](1);
    expected[0] = TAG_SYSTEM;
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.WrongTagType.selector,
        nonSystemTagId.getType(),
        expected
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (classId, nonSystemTagId))
    );

    // reverts if correlated systemId has not been registered on the World
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.SystemNotRegistered.selector,
        UNREGISTERED_SYSTEM_ID
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (classId, unregisteredSystemTagId))
    );

    // check that the data tables have been correctly updated
    
    // before
    bytes32[] memory classSystemTagsBefore = Classes.getSystemTags(classId);
    assertEq(classSystemTagsBefore.length, 0);

    bool systemTagExistsBefore = SystemTags.getExists(taggedSystemTagId);
    assertEq(systemTagExistsBefore, false);

    bytes32[] memory systemTagClassessBefore = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTagClassessBefore.length, 0);

    ClassSystemTagMapData memory class1Tag1MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapDataBefore.hasTag, false);
    // successfull call
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (classId, taggedSystemTagId))
    );
    // after
    bytes32[] memory class1SystemTagsAfter = Classes.getSystemTags(classId);
    assertEq(class1SystemTagsAfter.length, 1);
    assertEq(class1SystemTagsAfter[0], Id.unwrap(taggedSystemTagId));

    bool systemTagExistsAfter = SystemTags.getExists(taggedSystemTagId);
    assertEq(systemTagExistsAfter, true);

    bytes32[] memory tagClassesAfter = SystemTags.getClasses(taggedSystemTagId);
    assertEq(tagClassesAfter.length, 1);
    assertEq(tagClassesAfter[0], Id.unwrap(classId));

    ClassSystemTagMapData memory classTagMapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(classTagMapDataAfter.hasTag, true);

    // revert if Class already has this SystemTag
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.EntityAlreadyHasTag.selector,
        classId,
        taggedSystemTagId
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (classId, taggedSystemTagId))
    );

    // check multi-class tagging data
    // register TEST_CLASS_2 without any tags
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.registerClass, (classId2, new Id[](0)))
    );
    // add our tag to classId2
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTag, (classId2, taggedSystemTagId))
    );
    bytes32[] memory systemTagClassesAfter = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTagClassesAfter.length, 2);
    assertEq(systemTagClassesAfter[0], Id.unwrap(classId));
    assertEq(systemTagClassesAfter[1], Id.unwrap(classId2));

    ClassSystemTagMapData memory class2Tag1MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId);
    assertEq(class2Tag1MapDataAfter.hasTag, true);
    assertEq(class2Tag1MapDataAfter.classIndex, 1);
    assertEq(class2Tag1MapDataAfter.tagIndex, 0);
  }

  function testSetSystemTags() public {
    // check that multiple tag data is correctly updated
    // before
    bytes32[] memory classSystemTagsBefore = Classes.getSystemTags(classId);
    assertEq(classSystemTagsBefore.length, 0);

    bytes32[] memory systemTagClassessBefore = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTagClassessBefore.length, 0);

    ClassSystemTagMapData memory class1Tag1MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapDataBefore.hasTag, false);

    // successful call
    Id[] memory ids = new Id[](3);
    ids[0] = taggedSystemTagId;
    ids[1] = taggedSystemTagId2;
    ids[2] = taggedSystemTagId3;

    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTags, (classId, ids))
    );
    // after
    bytes32[] memory classSystemTagsAfter = Classes.getSystemTags(classId);
    assertEq(classSystemTagsAfter.length, 3);
    assertEq(classSystemTagsAfter[0], Id.unwrap(taggedSystemTagId));
    assertEq(classSystemTagsAfter[1], Id.unwrap(taggedSystemTagId2));
    assertEq(classSystemTagsAfter[2], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory systemTag1ClassesAfter = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTag1ClassesAfter.length, 1);
    assertEq(systemTag1ClassesAfter[0], Id.unwrap(classId));

    bytes32[] memory systemTag2ClassesAfter = SystemTags.getClasses(taggedSystemTagId2);
    assertEq(systemTag2ClassesAfter.length, 1);
    assertEq(systemTag2ClassesAfter[0], Id.unwrap(classId));

    bytes32[] memory systemTag3ClassesAfter = SystemTags.getClasses(taggedSystemTagId3);
    assertEq(systemTag3ClassesAfter.length, 1);
    assertEq(systemTag3ClassesAfter[0], Id.unwrap(classId));

    ClassSystemTagMapData memory class1Tag1MapAfter = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapAfter.hasTag, true);

    ClassSystemTagMapData memory class1Tag2MapAfter = ClassSystemTagMap.get(classId, taggedSystemTagId2);
    assertEq(class1Tag2MapAfter.hasTag, true);
    assertEq(class1Tag2MapAfter.tagIndex, 1);

    ClassSystemTagMapData memory class1Tag3MapAfter = ClassSystemTagMap.get(classId, taggedSystemTagId3);
    assertEq(class1Tag3MapAfter.hasTag, true);
    assertEq(class1Tag3MapAfter.tagIndex, 2);
  }

  function testRemoveSystemTag() public {
    // add 3 system tags to classId & classId2
    Id[] memory ids = new Id[](3);
    ids[0] = taggedSystemTagId;
    ids[1] = taggedSystemTagId2;
    ids[2] = taggedSystemTagId3;

    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTags, (classId, ids))
    );
    // register TEST_CLASS_2 with the same tags as TEST_CLASS
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.registerClass, (classId2, ids))
    );

    // reverts if classId has NOT been registered
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.ClassDoesNotExist.selector,
        unregisteredClassId
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.removeSystemTag, (unregisteredClassId, taggedSystemTagId))
    );

    // reverts if tagId does NOT exist
    vm.expectRevert(
      abi.encodeWithSelector(
        IErrors.TagDoesNotExist.selector,
        untaggedSystemTagId
      )
    );
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.removeSystemTag, (classId, untaggedSystemTagId))
    );

    // correctly updates data: Classes.systemTags, SystemTags.classes, ClasSystemTagMap
    // before
    bytes32[] memory class1SystemTagsBefore = Classes.getSystemTags(classId);
    assertEq(class1SystemTagsBefore.length, 3);
    assertEq(class1SystemTagsBefore[0], Id.unwrap(taggedSystemTagId));
    assertEq(class1SystemTagsBefore[1], Id.unwrap(taggedSystemTagId2));
    assertEq(class1SystemTagsBefore[2], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory class2SystemTagsBefore = Classes.getSystemTags(classId2);
    assertEq(class2SystemTagsBefore.length, 3);
    assertEq(class2SystemTagsBefore[0], Id.unwrap(taggedSystemTagId));
    assertEq(class2SystemTagsBefore[1], Id.unwrap(taggedSystemTagId2));
    assertEq(class2SystemTagsBefore[2], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory systemTag1ClassesBefore = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTag1ClassesBefore.length, 2);
    assertEq(systemTag1ClassesBefore[0], Id.unwrap(classId));
    assertEq(systemTag1ClassesBefore[1], Id.unwrap(classId2));

    bytes32[] memory systemTag2ClassesBefore = SystemTags.getClasses(taggedSystemTagId2);
    assertEq(systemTag2ClassesBefore.length, 2);
    assertEq(systemTag2ClassesBefore[0], Id.unwrap(classId));
    assertEq(systemTag2ClassesBefore[1], Id.unwrap(classId2));

    bytes32[] memory systemTag3ClassesBefore = SystemTags.getClasses(taggedSystemTagId3);
    assertEq(systemTag3ClassesBefore.length, 2);
    assertEq(systemTag3ClassesBefore[0], Id.unwrap(classId));
    assertEq(systemTag3ClassesBefore[1], Id.unwrap(classId2));

    ClassSystemTagMapData memory class1Tag1MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapDataBefore.hasTag, true);
    assertEq(class1Tag1MapDataBefore.classIndex, 0);
    assertEq(class1Tag1MapDataBefore.tagIndex, 0);

    ClassSystemTagMapData memory class1Tag2MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId2);
    assertEq(class1Tag2MapDataBefore.hasTag, true);
    assertEq(class1Tag2MapDataBefore.classIndex, 0);
    assertEq(class1Tag2MapDataBefore.tagIndex, 1);

    ClassSystemTagMapData memory class1Tag3MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId3);
    assertEq(class1Tag3MapDataBefore.hasTag, true);
    assertEq(class1Tag3MapDataBefore.classIndex, 0);
    assertEq(class1Tag3MapDataBefore.tagIndex, 2);

    ClassSystemTagMapData memory class2Tag1MapDataBefore = ClassSystemTagMap.get(classId2, taggedSystemTagId);
    assertEq(class2Tag1MapDataBefore.hasTag, true);
    assertEq(class2Tag1MapDataBefore.classIndex, 1);
    assertEq(class2Tag1MapDataBefore.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag2MapDataBefore = ClassSystemTagMap.get(classId2, taggedSystemTagId2);
    assertEq(class2Tag2MapDataBefore.hasTag, true);
    assertEq(class2Tag2MapDataBefore.classIndex, 1);
    assertEq(class2Tag2MapDataBefore.tagIndex, 1);

    ClassSystemTagMapData memory class2Tag3MapDataBefore = ClassSystemTagMap.get(classId2, taggedSystemTagId3);
    assertEq(class2Tag3MapDataBefore.hasTag, true);
    assertEq(class2Tag3MapDataBefore.classIndex, 1);
    assertEq(class2Tag3MapDataBefore.tagIndex, 2);
    
    // successful call
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.removeSystemTag, (classId, taggedSystemTagId))
    );

    // after
    bytes32[] memory class1SystemTagsAfter = Classes.getSystemTags(classId);
    assertEq(class1SystemTagsAfter.length, 2);
    assertEq(class1SystemTagsAfter[0], Id.unwrap(taggedSystemTagId3));
    assertEq(class1SystemTagsAfter[1], Id.unwrap(taggedSystemTagId2));

    bytes32[] memory class2SystemTagsAfter = Classes.getSystemTags(classId2);
    assertEq(class2SystemTagsAfter.length, 3);
    assertEq(class2SystemTagsAfter[0], Id.unwrap(taggedSystemTagId));
    assertEq(class2SystemTagsAfter[1], Id.unwrap(taggedSystemTagId2));
    assertEq(class2SystemTagsAfter[2], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory systemTag1ClassesAfter = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTag1ClassesAfter.length, 1);
    assertEq(systemTag1ClassesAfter[0], Id.unwrap(classId2));

    bytes32[] memory systemTag2ClassesAfter = SystemTags.getClasses(taggedSystemTagId2);
    assertEq(systemTag2ClassesAfter.length, 2);
    assertEq(systemTag2ClassesAfter[0], Id.unwrap(classId));
    assertEq(systemTag2ClassesAfter[1], Id.unwrap(classId2));

    bytes32[] memory systemTag3ClassesAfter = SystemTags.getClasses(taggedSystemTagId3);
    assertEq(systemTag3ClassesAfter.length, 2);
    assertEq(systemTag3ClassesAfter[0], Id.unwrap(classId));
    assertEq(systemTag3ClassesAfter[1], Id.unwrap(classId2));

    ClassSystemTagMapData memory class1Tag1MapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapDataAfter.hasTag, false);
    assertEq(class1Tag1MapDataAfter.classIndex, 0);
    assertEq(class1Tag1MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class1Tag2MapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId2);
    assertEq(class1Tag2MapDataAfter.hasTag, true);
    assertEq(class1Tag2MapDataAfter.classIndex, 0);
    assertEq(class1Tag2MapDataAfter.tagIndex, 1);

    ClassSystemTagMapData memory class1Tag3MapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId3);
    assertEq(class1Tag3MapDataAfter.hasTag, true);
    assertEq(class1Tag3MapDataAfter.classIndex, 0);
    assertEq(class1Tag3MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag1MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId);
    assertEq(class2Tag1MapDataAfter.hasTag, true);
    assertEq(class2Tag1MapDataAfter.classIndex, 0);
    assertEq(class2Tag1MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag2MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId2);
    assertEq(class2Tag2MapDataAfter.hasTag, true);
    assertEq(class2Tag2MapDataAfter.classIndex, 1);
    assertEq(class2Tag2MapDataAfter.tagIndex, 1);

    ClassSystemTagMapData memory class2Tag3MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId3);
    assertEq(class2Tag3MapDataAfter.hasTag, true);
    assertEq(class2Tag3MapDataAfter.classIndex, 1);
    assertEq(class2Tag3MapDataAfter.tagIndex, 2);
  }

  function testRemoveSystemTags() public {
    // add 3 system tags to classId & classId2
    Id[] memory ids = new Id[](3);
    ids[0] = taggedSystemTagId;
    ids[1] = taggedSystemTagId2;
    ids[2] = taggedSystemTagId3;

    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.setSystemTags, (classId, ids))
    );
    // register TEST_CLASS_2 with the same tags as TEST_CLASS
    world.call(
      ENTITIES_SYSTEM_ID,
      abi.encodeCall(Entities.registerClass, (classId2, ids))
    );

    // correctly updates data: Classes.systemTags, SystemTags.classes, ClasSystemTagMap
    // before
    bytes32[] memory class1SystemTagsBefore = Classes.getSystemTags(classId);
    assertEq(class1SystemTagsBefore.length, 3);
    assertEq(class1SystemTagsBefore[0], Id.unwrap(taggedSystemTagId));
    assertEq(class1SystemTagsBefore[1], Id.unwrap(taggedSystemTagId2));
    assertEq(class1SystemTagsBefore[2], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory class2SystemTagsBefore = Classes.getSystemTags(classId2);
    assertEq(class2SystemTagsBefore.length, 3);
    assertEq(class2SystemTagsBefore[0], Id.unwrap(taggedSystemTagId));
    assertEq(class2SystemTagsBefore[1], Id.unwrap(taggedSystemTagId2));
    assertEq(class2SystemTagsBefore[2], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory systemTag1ClassesBefore = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTag1ClassesBefore.length, 2);
    assertEq(systemTag1ClassesBefore[0], Id.unwrap(classId));
    assertEq(systemTag1ClassesBefore[1], Id.unwrap(classId2));

    bytes32[] memory systemTag2ClassesBefore = SystemTags.getClasses(taggedSystemTagId2);
    assertEq(systemTag2ClassesBefore.length, 2);
    assertEq(systemTag2ClassesBefore[0], Id.unwrap(classId));
    assertEq(systemTag2ClassesBefore[1], Id.unwrap(classId2));

    bytes32[] memory systemTag3ClassesBefore = SystemTags.getClasses(taggedSystemTagId3);
    assertEq(systemTag3ClassesBefore.length, 2);
    assertEq(systemTag3ClassesBefore[0], Id.unwrap(classId));
    assertEq(systemTag3ClassesBefore[1], Id.unwrap(classId2));

    ClassSystemTagMapData memory class1Tag1MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapDataBefore.hasTag, true);
    assertEq(class1Tag1MapDataBefore.classIndex, 0);
    assertEq(class1Tag1MapDataBefore.tagIndex, 0);

    ClassSystemTagMapData memory class1Tag2MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId2);
    assertEq(class1Tag2MapDataBefore.hasTag, true);
    assertEq(class1Tag2MapDataBefore.classIndex, 0);
    assertEq(class1Tag2MapDataBefore.tagIndex, 1);

    ClassSystemTagMapData memory class1Tag3MapDataBefore = ClassSystemTagMap.get(classId, taggedSystemTagId3);
    assertEq(class1Tag3MapDataBefore.hasTag, true);
    assertEq(class1Tag3MapDataBefore.classIndex, 0);
    assertEq(class1Tag3MapDataBefore.tagIndex, 2);

    ClassSystemTagMapData memory class2Tag1MapDataBefore = ClassSystemTagMap.get(classId2, taggedSystemTagId);
    assertEq(class2Tag1MapDataBefore.hasTag, true);
    assertEq(class2Tag1MapDataBefore.classIndex, 1);
    assertEq(class2Tag1MapDataBefore.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag2MapDataBefore = ClassSystemTagMap.get(classId2, taggedSystemTagId2);
    assertEq(class2Tag2MapDataBefore.hasTag, true);
    assertEq(class2Tag2MapDataBefore.classIndex, 1);
    assertEq(class2Tag2MapDataBefore.tagIndex, 1);

    ClassSystemTagMapData memory class2Tag3MapDataBefore = ClassSystemTagMap.get(classId2, taggedSystemTagId3);
    assertEq(class2Tag3MapDataBefore.hasTag, true);
    assertEq(class2Tag3MapDataBefore.classIndex, 1);
    assertEq(class2Tag3MapDataBefore.tagIndex, 2);

    // successfull call
    // remove tags
    Id[] memory class1RemoveIds = new Id[](2);
    class1RemoveIds[0] = taggedSystemTagId3;
    class1RemoveIds[1] = taggedSystemTagId;
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.removeSystemTags, (classId, class1RemoveIds))
    );

    Id[] memory class2RemoveIds = new Id[](2);
    class2RemoveIds[0] = taggedSystemTagId;
    class2RemoveIds[1] = taggedSystemTagId2;
    world.call(
      TAGS_SYSTEM_ID,
      abi.encodeCall(Tags.removeSystemTags, (classId2, class2RemoveIds))
    );

    // after
    bytes32[] memory class1SystemTagsAfter = Classes.getSystemTags(classId);
    assertEq(class1SystemTagsAfter.length, 1);
    assertEq(class1SystemTagsAfter[0], Id.unwrap(taggedSystemTagId2));

    bytes32[] memory class2SystemTagsAfter = Classes.getSystemTags(classId2);
    assertEq(class2SystemTagsAfter.length, 1);
    assertEq(class2SystemTagsAfter[0], Id.unwrap(taggedSystemTagId3));

    bytes32[] memory systemTag1ClassesAfter = SystemTags.getClasses(taggedSystemTagId);
    assertEq(systemTag1ClassesAfter.length, 0);

    bytes32[] memory systemTag2ClassesAfter = SystemTags.getClasses(taggedSystemTagId2);
    assertEq(systemTag2ClassesAfter.length, 1);
    assertEq(systemTag2ClassesAfter[0], Id.unwrap(classId));

    bytes32[] memory systemTag3ClassesAfter = SystemTags.getClasses(taggedSystemTagId3);
    assertEq(systemTag3ClassesAfter.length, 1);
    assertEq(systemTag3ClassesAfter[0], Id.unwrap(classId2));

    ClassSystemTagMapData memory class1Tag1MapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId);
    assertEq(class1Tag1MapDataAfter.hasTag, false);
    assertEq(class1Tag1MapDataAfter.classIndex, 0);
    assertEq(class1Tag1MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class1Tag2MapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId2);
    assertEq(class1Tag2MapDataAfter.hasTag, true);
    assertEq(class1Tag2MapDataAfter.classIndex, 0);
    assertEq(class1Tag2MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class1Tag3MapDataAfter = ClassSystemTagMap.get(classId, taggedSystemTagId3);
    assertEq(class1Tag3MapDataAfter.hasTag, false);
    assertEq(class1Tag3MapDataAfter.classIndex, 0);
    assertEq(class1Tag3MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag1MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId);
    assertEq(class2Tag1MapDataAfter.hasTag, false);
    assertEq(class2Tag1MapDataAfter.classIndex, 0);
    assertEq(class2Tag1MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag2MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId2);
    assertEq(class2Tag2MapDataAfter.hasTag, false);
    assertEq(class2Tag2MapDataAfter.classIndex, 0);
    assertEq(class2Tag2MapDataAfter.tagIndex, 0);

    ClassSystemTagMapData memory class2Tag3MapDataAfter = ClassSystemTagMap.get(classId2, taggedSystemTagId3);
    assertEq(class2Tag3MapDataAfter.hasTag, true);
    assertEq(class2Tag3MapDataAfter.classIndex, 0);
    assertEq(class2Tag3MapDataAfter.tagIndex, 0);
  }

}
