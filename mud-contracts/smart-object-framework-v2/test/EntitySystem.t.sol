// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIdInstance } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

import { DEPLOYMENT_NAMESPACE } from "../src/namespaces/evefrontier/constants.sol";

import { IEntitySystem } from "../src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { entitySystem } from "../src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { tagSystem } from "../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { roleManagementSystem } from "../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

import { SystemMock } from "./mocks/SystemMock.sol";

import "../src/namespaces/evefrontier/codegen/index.sol";

import { TagId, TagIdLib } from "../src/libs/TagId.sol";

import { TAG_TYPE_PROPERTY, TAG_TYPE_ENTITY_RELATION, TAG_TYPE_RESOURCE_RELATION, TAG_IDENTIFIER_CLASS, TAG_IDENTIFIER_OBJECT, TAG_IDENTIFIER_ENTITY_COUNT, EntityRelationValue, ResourceRelationValue } from "../src/namespaces/evefrontier/systems/tag-system/types.sol";

contract EntitySystemTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  SystemMock taggedSystemMock;
  SystemMock taggedSystemMock2;
  SystemMock unTaggedSystemMock;

  bytes14 constant NAMESPACE = DEPLOYMENT_NAMESPACE;
  ResourceId constant NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, NAMESPACE)));

  ResourceId TAGGED_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystem")))));
  ResourceId constant TAGGED_SYSTEM_ID_2 =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("TaggedSystem2")))));

  uint256 classId = uint256(bytes32("TEST_CLASS"));
  bytes32 classAccessRole = keccak256(abi.encodePacked("ACCESS_ROLE", classId));
  uint256 classId2 = uint256(bytes32("TEST_CLASS_2"));
  uint256 objectId = uint256(bytes32("TEST_OBJECT"));
  bytes32 objectAccessRole = keccak256(abi.encodePacked("ACCESS_ROLE", objectId));
  uint256 objectId2 = uint256(bytes32("TEST_OBJECT_2"));
  TagId taggedSystemTagId = TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(TAGGED_SYSTEM_ID)));
  TagId taggedSystemTagId2 =
    TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(TAGGED_SYSTEM_ID_2)));

  TagId CLASS_PROPERTY_TAG = TagIdLib.encode(TAG_TYPE_PROPERTY, TAG_IDENTIFIER_CLASS);
  TagId OBJECT_PROPERTY_TAG = TagIdLib.encode(TAG_TYPE_PROPERTY, TAG_IDENTIFIER_OBJECT);
  TagId ENTITY_COUNT_PROPERTY_TAG = TagIdLib.encode(TAG_TYPE_PROPERTY, TAG_IDENTIFIER_ENTITY_COUNT);

  string constant mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  address deployer = vm.addr(deployerPK);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  address alice = vm.addr(alicePK);
  function setUp() public override {
    // DEPLOY AND REGISTER A MUD WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IBaseWorld(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // deploy and register Mock Systems and functions
    vm.startPrank(deployer);
    taggedSystemMock = new SystemMock();
    world.registerSystem(TAGGED_SYSTEM_ID, System(taggedSystemMock), true);
    world.registerFunctionSelector(TAGGED_SYSTEM_ID, "classLevelScope(bytes32)");
    world.registerFunctionSelector(TAGGED_SYSTEM_ID, "objectLevelScope(bytes32)");

    taggedSystemMock2 = new SystemMock();
    world.registerSystem(TAGGED_SYSTEM_ID_2, System(taggedSystemMock2), true);
    world.registerFunctionSelector(TAGGED_SYSTEM_ID_2, "classLevelScope2(bytes32)");
    world.registerFunctionSelector(TAGGED_SYSTEM_ID_2, "objectLevelScope2(bytes32)");

    vm.stopPrank();
  }

  function testSetup() public {
    // mock systems are registered on the World
    assertEq(ResourceIds.getExists(TAGGED_SYSTEM_ID), true);
    assertEq(ResourceIds.getExists(TAGGED_SYSTEM_ID_2), true);

    // mock functions are registered on the World
    string memory mockTaggedNamespaceString = WorldResourceIdLib.toTrimmedString(
      WorldResourceIdInstance.getNamespace(TAGGED_SYSTEM_ID)
    );
    assertEq(
      ResourceId.unwrap(
        FunctionSelectors.getSystemId(
          bytes4(keccak256(bytes(string.concat(mockTaggedNamespaceString, "__", "classLevelScope(bytes32)"))))
        )
      ),
      ResourceId.unwrap(TAGGED_SYSTEM_ID)
    );
    assertEq(
      ResourceId.unwrap(
        FunctionSelectors.getSystemId(
          bytes4(keccak256(bytes(string.concat(mockTaggedNamespaceString, "__", "objectLevelScope(bytes32)"))))
        )
      ),
      ResourceId.unwrap(TAGGED_SYSTEM_ID)
    );

    string memory mockTagged2NamespaceString = WorldResourceIdLib.toTrimmedString(
      WorldResourceIdInstance.getNamespace(TAGGED_SYSTEM_ID_2)
    );
    assertEq(
      ResourceId.unwrap(
        FunctionSelectors.getSystemId(
          bytes4(keccak256(bytes(string.concat(mockTagged2NamespaceString, "__", "classLevelScope2(bytes32)"))))
        )
      ),
      ResourceId.unwrap(TAGGED_SYSTEM_ID_2)
    );
    assertEq(
      ResourceId.unwrap(
        FunctionSelectors.getSystemId(
          bytes4(keccak256(bytes(string.concat(mockTagged2NamespaceString, "__", "objectLevelScope2(bytes32)"))))
        )
      ),
      ResourceId.unwrap(TAGGED_SYSTEM_ID_2)
    );
  }

  function test_registerClass() public {
    ResourceId[] memory scopedSystemIds = new ResourceId[](2);
    scopedSystemIds[0] = TAGGED_SYSTEM_ID;
    scopedSystemIds[1] = TAGGED_SYSTEM_ID_2;
    // reverts if classId is uint256(0)
    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_InvalidEntityId.selector, uint256(0)));
    entitySystem.registerClass(uint256(0), scopedSystemIds);

    // succesful direct call
    entitySystem.registerClass(classId, scopedSystemIds);

    // after
    assertEq(Entity.getExists(classId), true);

    bytes32[] memory classPropertyTagsAfter = Entity.getPropertyTags(classId);
    assertEq(classPropertyTagsAfter.length, 2);
    assertEq(classPropertyTagsAfter[0], TagId.unwrap(CLASS_PROPERTY_TAG));
    assertEq(classPropertyTagsAfter[1], TagId.unwrap(ENTITY_COUNT_PROPERTY_TAG));
    EntityTagMapData memory classPropertyTagMapAfter = EntityTagMap.get(classId, CLASS_PROPERTY_TAG);
    assertEq(classPropertyTagMapAfter.hasTag, true);
    assertEq(classPropertyTagMapAfter.tagIndex, 0);
    assertEq(bytes32(classPropertyTagMapAfter.value), bytes32(0));
    EntityTagMapData memory classEntityCountTagMapAfter = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(classEntityCountTagMapAfter.hasTag, true);
    assertEq(classEntityCountTagMapAfter.tagIndex, 1);
    assertEq(abi.decode(classEntityCountTagMapAfter.value, (uint256)), uint256(0));

    TagId entityRelationTagAfter = Entity.getEntityRelationTag(classId);
    assertEq(TagId.unwrap(entityRelationTagAfter), bytes32(0));
    EntityTagMapData memory classEntityRelationTagMapAfter = EntityTagMap.get(
      classId,
      TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(classId)))
    );
    assertEq(classEntityRelationTagMapAfter.hasTag, false);

    bytes32[] memory classResourceTagsAfter = Entity.getResourceRelationTags(classId);
    assertEq(classResourceTagsAfter.length, 2);
    assertEq(classResourceTagsAfter[0], TagId.unwrap(taggedSystemTagId));
    assertEq(classResourceTagsAfter[1], TagId.unwrap(taggedSystemTagId2));

    EntityTagMapData memory system1TagMapAfter = EntityTagMap.get(classId, taggedSystemTagId);
    assertEq(system1TagMapAfter.hasTag, true);
    assertEq(system1TagMapAfter.tagIndex, 0);
    ResourceRelationValue memory system1ResourceValue = abi.decode(system1TagMapAfter.value, (ResourceRelationValue));
    assertEq(system1ResourceValue.resourceType, ResourceIdInstance.getType(TAGGED_SYSTEM_ID));
    assertEq(system1ResourceValue.resourceIdentifier, ResourceIdInstance.getResourceName(TAGGED_SYSTEM_ID));

    EntityTagMapData memory system2TagMapAfter = EntityTagMap.get(classId, taggedSystemTagId2);
    assertEq(system2TagMapAfter.hasTag, true);
    assertEq(system2TagMapAfter.tagIndex, 1);
    ResourceRelationValue memory system2ResourceValue = abi.decode(system2TagMapAfter.value, (ResourceRelationValue));
    assertEq(system2ResourceValue.resourceType, ResourceIdInstance.getType(TAGGED_SYSTEM_ID_2));
    assertEq(system2ResourceValue.resourceIdentifier, ResourceIdInstance.getResourceName(TAGGED_SYSTEM_ID_2));

    assertEq(Role.getExists(classAccessRole), true);
    assertEq(HasRole.getIsMember(classAccessRole, deployer), true);
    assertEq(Entity.getAccessRole(classId), classAccessRole);

    // reverts if classId is already registered
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityAlreadyExists.selector, classId));
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.stopPrank();
  }

  function test_scopedRegisterClass() public {
    // TODO: once we have some intialization logic, we can test this
  }

  function test_instantiate() public {
    vm.startPrank(deployer);

    // reverts if classId has NOT been registered
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityDoesNotExist.selector, classId));
    entitySystem.instantiate(classId, objectId, alice);

    // register classId
    entitySystem.registerClass(classId, new ResourceId[](0));

    // reverts if objectId is uint256(0)
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_InvalidEntityId.selector, uint256(0)));
    entitySystem.instantiate(classId, uint256(0), alice);

    // before checks
    assertEq(Entity.getExists(objectId), false);
    bytes32[] memory objectPropertyTagsBefore = Entity.getPropertyTags(objectId);
    assertEq(objectPropertyTagsBefore.length, 0);
    TagId objectEntityRelationTagBefore = Entity.getEntityRelationTag(objectId);
    assertEq(TagId.unwrap(objectEntityRelationTagBefore), bytes32(0));
    EntityTagMapData memory classEntityCountTagMapBefore = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(classEntityCountTagMapBefore.hasTag, true);
    assertEq(abi.decode(classEntityCountTagMapBefore.value, (uint256)), uint256(0));

    // successful call
    entitySystem.instantiate(classId, objectId, alice);

    // reverts if object entity is used as class entity
    vm.expectRevert(
      abi.encodeWithSelector(IEntitySystem.Entity_PropertyTagNotFound.selector, objectId, CLASS_PROPERTY_TAG)
    );
    entitySystem.instantiate(objectId, objectId2, alice);

    // after checks
    // creates an entry in the Entity table
    assertEq(Entity.getExists(objectId), true);

    // correctly creates/updates entries for the Classes, Objects, and ClassObjectMap Tables
    bytes32[] memory objectPropertyTagsAfter = Entity.getPropertyTags(objectId);
    assertEq(objectPropertyTagsAfter.length, 1);
    assertEq(objectPropertyTagsAfter[0], TagId.unwrap(OBJECT_PROPERTY_TAG));

    EntityTagMapData memory objectPropertyTagMapAfter = EntityTagMap.get(objectId, OBJECT_PROPERTY_TAG);
    assertEq(objectPropertyTagMapAfter.hasTag, true);
    assertEq(objectPropertyTagMapAfter.tagIndex, 0);
    assertEq(bytes32(objectPropertyTagMapAfter.value), bytes32(0));

    TagId entityRelationTagAfter = Entity.getEntityRelationTag(objectId);
    assertEq(
      TagId.unwrap(entityRelationTagAfter),
      TagId.unwrap(TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId))))
    );

    EntityTagMapData memory objectEntityRelationTagMapAfter = EntityTagMap.get(
      objectId,
      TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId)))
    );
    assertEq(objectEntityRelationTagMapAfter.hasTag, true);
    assertEq(objectEntityRelationTagMapAfter.tagIndex, 0);
    EntityRelationValue memory objectEntityRelationValue = abi.decode(
      objectEntityRelationTagMapAfter.value,
      (EntityRelationValue)
    );
    assertEq(objectEntityRelationValue.relationType, "INHERITANCE");
    assertEq(objectEntityRelationValue.relatedEntityId, classId);

    EntityTagMapData memory classEntityCountTagMapAfter = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(classEntityCountTagMapAfter.hasTag, true);
    assertEq(abi.decode(classEntityCountTagMapAfter.value, (uint256)), uint256(1));

    assertEq(Role.getExists(objectAccessRole), true);
    assertEq(HasRole.getIsMember(objectAccessRole, alice), true);
    assertEq(Entity.getAccessRole(objectId), objectAccessRole);

    // reverts if objectId is already instantiated
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityAlreadyExists.selector, objectId));
    entitySystem.instantiate(classId, objectId, alice);
    vm.stopPrank();
  }

  function test_deleteObject() public {
    vm.startPrank(deployer);

    // setup - register classId
    entitySystem.registerClass(classId, new ResourceId[](0));

    // reverts if objectId doesn't exist (hasn't been instantiated)
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityDoesNotExist.selector, objectId));
    entitySystem.deleteObject(objectId);

    // create some objects
    entitySystem.instantiate(classId, objectId, alice);
    entitySystem.instantiate(classId, objectId2, alice);

    // check data state
    // before
    assertEq(Entity.getExists(objectId), true);
    assertEq(Entity.getExists(objectId2), true);

    EntityTagMapData memory classEntityCountTagMapBefore = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(abi.decode(classEntityCountTagMapBefore.value, (uint256)), uint256(2));

    EntityTagMapData memory object1EntityRelationTagMapAfter = EntityTagMap.get(
      objectId,
      TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId)))
    );
    EntityRelationValue memory object1EntityRelationValue = abi.decode(
      object1EntityRelationTagMapAfter.value,
      (EntityRelationValue)
    );
    assertEq(object1EntityRelationValue.relatedEntityId, classId);

    EntityTagMapData memory object2EntityRelationTagMapAfter = EntityTagMap.get(
      objectId2,
      TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId2)))
    );
    EntityRelationValue memory object2EntityRelationValue = abi.decode(
      object2EntityRelationTagMapAfter.value,
      (EntityRelationValue)
    );
    assertEq(object2EntityRelationValue.relatedEntityId, classId);
    vm.stopPrank();

    // successful call
    vm.prank(alice);
    entitySystem.deleteObject(objectId);

    // after
    assertEq(Entity.getExists(objectId), false);
    assertEq(Entity.getExists(objectId2), true);

    EntityTagMapData memory classEntityCountTagMapAfter = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(abi.decode(classEntityCountTagMapAfter.value, (uint256)), uint256(1));

    assertEq(
      EntityTagMap.getHasTag(objectId, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId)))),
      false
    );
    assertEq(
      EntityTagMap.getHasTag(objectId2, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId2)))),
      true
    );

    // removes role data
    assertEq(Role.getExists(objectAccessRole), false);
    assertEq(HasRole.getIsMember(objectAccessRole, alice), false);
  }

  function test_deleteObjects() public {
    vm.startPrank(deployer);

    // correctly calls and executes deleteObject for multiple objectIds
    entitySystem.registerClass(classId, new ResourceId[](0));
    entitySystem.instantiate(classId, objectId, alice);
    entitySystem.instantiate(classId, objectId2, alice);

    assertEq(Entity.getExists(objectId), true);
    assertEq(
      EntityTagMap.getHasTag(objectId, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId)))),
      true
    );
    assertEq(Entity.getExists(objectId2), true);
    assertEq(
      EntityTagMap.getHasTag(objectId2, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId2)))),
      true
    );
    EntityTagMapData memory classEntityCountTagMapBefore = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(abi.decode(classEntityCountTagMapBefore.value, (uint256)), uint256(2));
    vm.stopPrank();
    uint256[] memory objectsToDelete = new uint256[](2);
    objectsToDelete[0] = objectId;
    objectsToDelete[1] = objectId2;

    vm.prank(alice);
    entitySystem.deleteObjects(objectsToDelete);

    assertEq(Entity.getExists(objectId), false);
    assertEq(
      EntityTagMap.getHasTag(objectId2, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId2)))),
      false
    );
    assertEq(Entity.getExists(objectId2), false);
    assertEq(
      EntityTagMap.getHasTag(objectId2, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(objectId2)))),
      false
    );

    EntityTagMapData memory classEntityCountTagMapAfter = EntityTagMap.get(classId, ENTITY_COUNT_PROPERTY_TAG);
    assertEq(abi.decode(classEntityCountTagMapAfter.value, (uint256)), uint256(0));
  }

  function test_deleteClass() public {
    vm.startPrank(deployer);

    // reverts if classId doesn't exist (wasn't registered)
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityDoesNotExist.selector, classId));
    entitySystem.deleteClass(classId);

    // setup
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = TAGGED_SYSTEM_ID;
    entitySystem.registerClass(classId, scopedSystemIds);
    entitySystem.instantiate(classId, objectId, alice);

    // reverts if a non-class entity was passed to deleteClass
    vm.expectRevert(
      abi.encodeWithSelector(IEntitySystem.Entity_PropertyTagNotFound.selector, objectId, CLASS_PROPERTY_TAG)
    );
    entitySystem.deleteClass(objectId);

    // reverts if Class has Object(s) instantiated still
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityRelationsFound.selector, classId, 1));
    entitySystem.deleteClass(classId);
    vm.stopPrank();

    // delete the object
    vm.prank(alice);
    entitySystem.deleteObject(objectId);

    // check data state updates
    // before
    assertEq(Entity.getExists(classId), true);
    bytes32[] memory classPropertyTagsBefore = Entity.getPropertyTags(classId);
    assertEq(classPropertyTagsBefore.length, 2);
    assertEq(classPropertyTagsBefore[0], TagId.unwrap(CLASS_PROPERTY_TAG));
    assertEq(classPropertyTagsBefore[1], TagId.unwrap(ENTITY_COUNT_PROPERTY_TAG));
    bytes32[] memory classSystemTagsBefore = Entity.getResourceRelationTags(classId);
    assertEq(classSystemTagsBefore.length, 1);
    assertEq(classSystemTagsBefore[0], TagId.unwrap(taggedSystemTagId));

    // map data
    assertEq(EntityTagMap.getHasTag(classId, CLASS_PROPERTY_TAG), true);
    assertEq(EntityTagMap.getHasTag(classId, ENTITY_COUNT_PROPERTY_TAG), true);
    assertEq(EntityTagMap.getHasTag(classId, taggedSystemTagId), true);

    // successful call
    vm.prank(deployer);
    entitySystem.deleteClass(classId);

    // after
    assertEq(Entity.getExists(classId), false);
    // removes all Tags
    bytes32[] memory classPropertyTagsAfter = Entity.getPropertyTags(classId);
    assertEq(classPropertyTagsAfter.length, 0);
    bytes32[] memory classSystemTagsAfter = Entity.getResourceRelationTags(classId);
    assertEq(classSystemTagsAfter.length, 0);

    // removes map data
    assertEq(EntityTagMap.getHasTag(classId, CLASS_PROPERTY_TAG), false);
    assertEq(EntityTagMap.getHasTag(classId, ENTITY_COUNT_PROPERTY_TAG), false);
    assertEq(EntityTagMap.getHasTag(classId, taggedSystemTagId), false);

    // removes role data
    assertEq(Role.getExists(classAccessRole), false);
    assertEq(HasRole.getIsMember(classAccessRole, deployer), false);
  }

  function test_deleteClasses() public {
    vm.startPrank(deployer);

    // corectly calls and executes deleteClass for multiple classIds
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = TAGGED_SYSTEM_ID;
    entitySystem.registerClass(classId, scopedSystemIds);
    entitySystem.registerClass(classId2, scopedSystemIds);

    // check data state updates
    // before
    bytes32[] memory class1PropertyTagsBefore = Entity.getPropertyTags(classId);
    assertEq(class1PropertyTagsBefore.length, 2);
    assertEq(class1PropertyTagsBefore[0], TagId.unwrap(CLASS_PROPERTY_TAG));
    assertEq(class1PropertyTagsBefore[1], TagId.unwrap(ENTITY_COUNT_PROPERTY_TAG));
    bytes32[] memory class1SystemTagsBefore = Entity.getResourceRelationTags(classId);
    assertEq(class1SystemTagsBefore.length, 1);
    assertEq(class1SystemTagsBefore[0], TagId.unwrap(taggedSystemTagId));
    bytes32[] memory class2PropertyTagsBefore = Entity.getPropertyTags(classId2);
    assertEq(class2PropertyTagsBefore.length, 2);
    assertEq(class2PropertyTagsBefore[0], TagId.unwrap(CLASS_PROPERTY_TAG));
    assertEq(class2PropertyTagsBefore[1], TagId.unwrap(ENTITY_COUNT_PROPERTY_TAG));
    bytes32[] memory class2SystemTagsBefore = Entity.getResourceRelationTags(classId2);
    assertEq(class2SystemTagsBefore.length, 1);
    assertEq(class2SystemTagsBefore[0], TagId.unwrap(taggedSystemTagId));
    assertEq(Entity.getExists(classId), true);
    assertEq(Entity.getExists(classId2), true);
    assertEq(EntityTagMap.getHasTag(classId, CLASS_PROPERTY_TAG), true);
    assertEq(EntityTagMap.getHasTag(classId, ENTITY_COUNT_PROPERTY_TAG), true);
    assertEq(EntityTagMap.getHasTag(classId, taggedSystemTagId), true);
    assertEq(EntityTagMap.getHasTag(classId2, CLASS_PROPERTY_TAG), true);
    assertEq(EntityTagMap.getHasTag(classId2, ENTITY_COUNT_PROPERTY_TAG), true);
    assertEq(EntityTagMap.getHasTag(classId2, taggedSystemTagId), true);

    // successful call
    uint256[] memory classIds = new uint256[](2);
    classIds[0] = classId;
    classIds[1] = classId2;
    entitySystem.deleteClasses(classIds);

    // after
    bytes32[] memory class1PropertyTagsAfter = Entity.getPropertyTags(classId);
    assertEq(class1PropertyTagsAfter.length, 0);
    bytes32[] memory class2PropertyTagsAfter = Entity.getPropertyTags(classId2);
    assertEq(class2PropertyTagsAfter.length, 0);
    bytes32[] memory class1SystemTagsAfter = Entity.getResourceRelationTags(classId);
    assertEq(class1SystemTagsAfter.length, 0);
    bytes32[] memory class2SystemTagsAfter = Entity.getResourceRelationTags(classId2);
    assertEq(class2SystemTagsAfter.length, 0);
    assertEq(EntityTagMap.getHasTag(classId, CLASS_PROPERTY_TAG), false);
    assertEq(EntityTagMap.getHasTag(classId, ENTITY_COUNT_PROPERTY_TAG), false);
    assertEq(EntityTagMap.getHasTag(classId, taggedSystemTagId), false);
    assertEq(EntityTagMap.getHasTag(classId2, CLASS_PROPERTY_TAG), false);
    assertEq(EntityTagMap.getHasTag(classId2, ENTITY_COUNT_PROPERTY_TAG), false);
    assertEq(EntityTagMap.getHasTag(classId2, taggedSystemTagId), false);
    assertEq(Entity.getExists(classId), false);
    assertEq(Entity.getExists(classId2), false);
    vm.stopPrank();
  }

  function test_setClassAccessRole() public {
    vm.startPrank(deployer);
    bytes32 newClassAccessRole = bytes32("NEW_CLASS_ACCESS_ROLE");

    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = TAGGED_SYSTEM_ID;

    // register Class
    entitySystem.registerClass(classId, scopedSystemIds);

    // set invalid params
    uint256 invalidClassId = uint256(bytes32("INVALID_CLASS_ID"));
    bytes32 invalidRole = bytes32("INVALID_ROLE");

    // reverts, if classId in not registered
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityDoesNotExist.selector, invalidClassId));
    entitySystem.setClassAccessRole(invalidClassId, newClassAccessRole);

    // reverts, if newAccessRole does not exist
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_RoleDoesNotExist.selector, invalidRole));
    entitySystem.setClassAccessRole(classId, invalidRole);

    // check for old access role
    bytes32 accessRoleBefore = Entity.getAccessRole(classId);
    assertEq(accessRoleBefore, classAccessRole);

    // create new class access role
    roleManagementSystem.createRole(classId, newClassAccessRole, classAccessRole);

    // success
    entitySystem.setClassAccessRole(classId, newClassAccessRole);

    //check for new access role
    bytes32 accessRoleAfter = Entity.getAccessRole(classId);
    assertEq(accessRoleAfter, newClassAccessRole);
    vm.stopPrank();
  }

  function test_setObjectAccessRole() public {
    vm.startPrank(deployer);
    bytes32 newObjectAccessRole = bytes32("NEW_OBJECT_ACCESS_ROLE");

    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = TAGGED_SYSTEM_ID;

    // register Class
    entitySystem.registerClass(classId, scopedSystemIds);
    // instantiate Object
    entitySystem.instantiate(classId, objectId, alice);

    // set invalid params
    uint256 invalidObjectId = uint256(bytes32("INVALID_OBJECT_ID"));
    bytes32 invalidRole = bytes32("INVALID_ROLE");

    // reverts, if objectId in not instantiated
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_EntityDoesNotExist.selector, invalidObjectId));
    entitySystem.setObjectAccessRole(invalidObjectId, newObjectAccessRole);

    // reverts, if newAccessRole does not exist
    vm.expectRevert(abi.encodeWithSelector(IEntitySystem.Entity_RoleDoesNotExist.selector, invalidRole));
    entitySystem.setObjectAccessRole(objectId, invalidRole);

    // check for old access role
    bytes32 accessRoleBefore = Entity.getAccessRole(objectId);
    assertEq(accessRoleBefore, objectAccessRole);
    assertEq(HasRole.getIsMember(objectAccessRole, alice), true);
    vm.stopPrank();

    vm.prank(alice);
    roleManagementSystem.createRole(objectId, newObjectAccessRole, objectAccessRole);

    vm.prank(alice);
    // success
    entitySystem.setObjectAccessRole(objectId, newObjectAccessRole);

    // check for new access role
    bytes32 accessRoleAfter = Entity.getAccessRole(objectId);
    assertEq(accessRoleAfter, newObjectAccessRole);
  }
}
