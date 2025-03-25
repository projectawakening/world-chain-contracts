// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { IEntitySystem } from "../src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { entitySystem } from "../src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { ITagSystem } from "../src/namespaces/evefrontier/interfaces/ITagSystem.sol";
import { tagSystem } from "../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { IRoleManagementSystem } from "../src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";
import { roleManagementSystem } from "../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { accessConfigSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { ISOFAccessSystem } from "../src/namespaces/sofaccess/interfaces/ISOFAccessSystem.sol";
import { sOFAccessSystem } from "../src/namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { CallAccess } from "../src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

import "../src/namespaces/evefrontier/codegen/index.sol";

import { TagId, TagIdLib } from "../src/libs/TagId.sol";

import { TAG_TYPE_PROPERTY, TAG_TYPE_ENTITY_RELATION, TAG_TYPE_RESOURCE_RELATION, TAG_IDENTIFIER_CLASS, TAG_IDENTIFIER_OBJECT, TAG_IDENTIFIER_ENTITY_COUNT, TagParams, EntityRelationValue, ResourceRelationValue } from "../src/namespaces/evefrontier/systems/tag-system/types.sol";

import { ClassScopedMock } from "./mocks/ClassScopedMock.sol";
import { UnscopedMock } from "./mocks/UnscopedMock.sol";
import { SmartObjectFramework } from "../src/inherit/SmartObjectFramework.sol";

contract SOFAccessSystemTest is MudTest {
  IBaseWorld world;
  ClassScopedMock classScopedSystem;
  UnscopedMock unscopedSystem;

  ResourceId ENTITY_SYSTEM_ID = entitySystem.toResourceId();
  ResourceId TAG_SYSTEM_ID = tagSystem.toResourceId();
  ResourceId ROLE_MANAGEMENT_SYSTEM_ID = roleManagementSystem.toResourceId();
  ResourceId SOF_ACCESS_SYSTEM_ID = sOFAccessSystem.toResourceId();

  ResourceId CLASS_SCOPED_SYSTEM_ID =
    ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_SYSTEM, bytes14("evefrontier"), bytes16("ClassScopedMock"))));
  ResourceId UNSCOPED_SYSTEM_ID =
    ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_SYSTEM, bytes14("evefrontier"), bytes16("UnscopedMock"))));

  TagId CLASS_SCOPED_SYSTEM_TAG =
    TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(CLASS_SCOPED_SYSTEM_ID)));
  TagId UNSCOPED_SYSTEM_TAG =
    TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(UNSCOPED_SYSTEM_ID)));

  uint256 classId = uint256(bytes32("TEST_CLASS"));
  bytes32 classAccessRole = keccak256(abi.encodePacked("ACCESS_ROLE", classId));
  uint256 objectId = uint256(bytes32("TEST_OBJECT"));
  bytes32 objectAccessRole = keccak256(abi.encodePacked("ACCESS_ROLE", objectId));

  bytes32 adminRole = bytes32("ADMIN_ROLE");
  bytes32 testRole = bytes32("TEST_ROLE");

  string constant mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  address deployer = vm.addr(deployerPK);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  address alice = vm.addr(alicePK);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);
  address bob = vm.addr(bobPK);

  function setUp() public override {
    // DEPLOY AND REGISTER A MUD WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IBaseWorld(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    vm.startPrank(deployer);

    // DEPLOY AND REGISTER THE CLASS SCOPED SYSTEM AND THE UNSCOPED SYSTEM
    classScopedSystem = new ClassScopedMock();
    world.registerSystem(CLASS_SCOPED_SYSTEM_ID, System(classScopedSystem), true);

    unscopedSystem = new UnscopedMock();
    world.registerSystem(UNSCOPED_SYSTEM_ID, System(unscopedSystem), true);

    // CONFIGURE ROLES, ACCESS, AND ENFORCEMENT FOR THE ENTITY, TAG and ROLE MANAGEMENT SYSTEMS
    _configureSOFCallAccess();
    _configureEntitySystemAccess();
    _configureTagSystemAccess();
    _configureRoleManagementSystemAccess();

    vm.stopPrank();
  }

  function testSetup() public {
    // mock systems are registered on the World
    assertEq(ResourceIds.getExists(CLASS_SCOPED_SYSTEM_ID), true);
    assertEq(ResourceIds.getExists(UNSCOPED_SYSTEM_ID), true);

    // check all target systems/functions are configured with the SOF Access System and enforced
    assertEq(AccessConfig.getConfigured(keccak256(abi.encodePacked(TAG_SYSTEM_ID, ITagSystem.setTag.selector))), true);
    assertEq(AccessConfig.getEnforcement(keccak256(abi.encodePacked(TAG_SYSTEM_ID, ITagSystem.setTag.selector))), true);

    assertEq(
      AccessConfig.getConfigured(keccak256(abi.encodePacked(TAG_SYSTEM_ID, ITagSystem.removeTag.selector))),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(keccak256(abi.encodePacked(TAG_SYSTEM_ID, ITagSystem.removeTag.selector))),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.scopedRegisterClass.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.setClassAccessRole.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.setClassAccessRole.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.deleteClass.selector))),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.deleteClass.selector))),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.setObjectAccessRole.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.setObjectAccessRole.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.instantiate.selector))),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(keccak256(abi.encodePacked(ENTITY_SYSTEM_ID, IEntitySystem.instantiate.selector))),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ResourceId.unwrap(ENTITY_SYSTEM_ID), IEntitySystem.deleteObject.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ResourceId.unwrap(ENTITY_SYSTEM_ID), IEntitySystem.deleteObject.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedCreateRole.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedCreateRole.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedTransferRoleAdmin.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedTransferRoleAdmin.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedGrantRole.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedGrantRole.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedRevokeRole.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedRevokeRole.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedRenounceRole.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedRenounceRole.selector))
      ),
      true
    );

    assertEq(
      AccessConfig.getConfigured(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedRevokeAll.selector))
      ),
      true
    );
    assertEq(
      AccessConfig.getEnforcement(
        keccak256(abi.encodePacked(ROLE_MANAGEMENT_SYSTEM_ID, IRoleManagementSystem.scopedRevokeAll.selector))
      ),
      true
    );
  }

  // TagSystem.sol
  function test_TagSystem_setTag() public {
    // setSystemTag -> allowEntitySystemOrDirectAccessRole (class/object)

    // implicit success, via the EntitySystem call (through registerClass->setTags->setTag)
    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // revert, if calling system is not scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(unscopedSystem))
    );
    world.call(
      UNSCOPED_SYSTEM_ID,
      abi.encodeCall(
        UnscopedMock.callSetTag,
        (
          classId,
          TagParams(
            CLASS_SCOPED_SYSTEM_TAG,
            abi.encode(ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, CLASS_SCOPED_SYSTEM_ID.getResourceName()))
          )
        )
      )
    );

    // revert, even if the System is in scope but is not explicitly a CallAccess defined caller
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(classScopedSystem))
    );
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(
        ClassScopedMock.callSetTag,
        (
          classId,
          TagParams(
            UNSCOPED_SYSTEM_TAG,
            abi.encode(ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, UNSCOPED_SYSTEM_ID.getResourceName()))
          )
        )
      )
    );

    // revert, if direct caller is not a class access role member
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(this)));
    tagSystem.setTag(
      classId,
      TagParams(
        UNSCOPED_SYSTEM_TAG,
        abi.encode(ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, UNSCOPED_SYSTEM_ID.getResourceName()))
      )
    );

    // success, direct caller is a class access role member
    vm.prank(deployer);
    tagSystem.setTag(
      classId,
      TagParams(
        UNSCOPED_SYSTEM_TAG,
        abi.encode(ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, UNSCOPED_SYSTEM_ID.getResourceName()))
      )
    );
  }

  function test_TagSystem_removeTag() public {
    // removeSystemTag - allowEntitySystemOrDirectAccessRole (class/object)
    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // revert, if calling system is not scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callRemoveTag, (classId, CLASS_SCOPED_SYSTEM_TAG)));

    // success, via the EntitySystem call (all tags removed through deleteClass->removeSystemTags->removeSystemTag)

    // temporarily disable access control for deleteClass
    vm.prank(deployer);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.deleteClass.selector, false);
    vm.prank(deployer);
    entitySystem.deleteClass(classId);

    // re-enable access control for deleteClass
    vm.prank(deployer);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.deleteClass.selector, true);

    // re-register Class (with classScopedSystem tag)
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // set object level tag (unscopedSystem)
    world.call(CLASS_SCOPED_SYSTEM_ID, abi.encodeCall(ClassScopedMock.callInstantiate, (classId, objectId, alice)));

    vm.prank(alice);
    tagSystem.setTag(
      objectId,
      TagParams(
        UNSCOPED_SYSTEM_TAG,
        abi.encode(ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, UNSCOPED_SYSTEM_ID.getResourceName()))
      )
    );

    // revert, even if the System is in scope but is not explicitly an EntitySystem caller
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(classScopedSystem))
    );
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callRemoveTag, (classId, CLASS_SCOPED_SYSTEM_TAG))
    );

    // revert, if direct caller is not a class access role member (class)
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(this)));
    tagSystem.removeTag(classId, CLASS_SCOPED_SYSTEM_TAG);

    // success, direct caller is a class access role member (class)
    vm.prank(deployer);
    tagSystem.removeTag(classId, CLASS_SCOPED_SYSTEM_TAG);

    // revert, if direct caller is not a object access role member (object)
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    tagSystem.removeTag(objectId, UNSCOPED_SYSTEM_TAG);

    // success, direct caller is a object access role member (object)
    vm.prank(alice);
    tagSystem.removeTag(objectId, UNSCOPED_SYSTEM_TAG);
  }

  // EntitySystem.sol
  function test_EntitySystem_registerClass() public {}

  function test_EntitySystem_setClassAccessRole() public {
    // setClassAccessRole - allowClassScopedSystemOrDirectAccessRole (class)

    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callSetClassAccessRole, (classId, classAccessRole)));

    // success, via the class scoped system call
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callSetClassAccessRole, (classId, classAccessRole))
    );

    // revert, if direct caller is not a class access role member
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(this)));
    entitySystem.setClassAccessRole(classId, classAccessRole);

    // success, direct caller is a class access role member
    vm.prank(deployer);
    entitySystem.setClassAccessRole(classId, classAccessRole);
  }

  function test_EntitySystem_setObjectAccessRole() public {
    // setObjectAccessRole - allowClassScopedSystemOrDirectAccessRole (object)

    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // instantitate object
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    // revert, if calling system is not scoped for this object
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callSetObjectAccessRole, (objectId, classAccessRole)));

    // success, via the class scoped system call
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callSetObjectAccessRole, (objectId, classAccessRole))
    );

    // revert, if direct caller is not a object access role member (in this case the object role is the class role added in the last call)
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    entitySystem.setObjectAccessRole(objectId, classAccessRole);

    // success, direct caller is a object access role member
    vm.prank(deployer);
    entitySystem.setObjectAccessRole(objectId, objectAccessRole);
  }

  function test_EntitySystem_instantiate() public {
    // instantiate - allowClassScopedSystemOrDirectClassAccessRole (object)

    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callInstantiate, (classId, objectId, alice)));

    // success, via the class scoped system call
    world.call(CLASS_SCOPED_SYSTEM_ID, abi.encodeCall(ClassScopedMock.callInstantiate, (classId, objectId, alice)));

    // add UNSCOPED_SYSTEM_ID to the CallAccess table for the instantiate function
    vm.prank(deployer);
    CallAccess.set(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, address(unscopedSystem), true);

    // delete object (so we can successfully instantiate again)
    vm.prank(deployer);
    entitySystem.deleteObject(objectId);

    // success, via UNSCOPED, the newly CallAccess defined caller
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callInstantiate, (classId, objectId, alice)));

    // delete object (so we can successfully instantiate again)
    vm.prank(deployer);
    entitySystem.deleteObject(objectId);

    // revert, if direct caller is not a class access role member
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(this)));
    entitySystem.instantiate(classId, objectId, alice);

    // success, direct caller is a class access role member
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);
  }

  function test_EntitySystem_deleteObject() public {
    // deleteObject - allowClassScopedSystemOrDirectAccessRole (object)

    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    // instantiate object
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callDeleteObject, (objectId)));

    // success, via the class scoped system call
    world.call(CLASS_SCOPED_SYSTEM_ID, abi.encodeCall(ClassScopedMock.callDeleteObject, (objectId)));

    // re-instantiate object (so we can successfully delete it again)
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    // add UNSCOPED_SYSTEM_ID to the CallAccess table for the deleteObject function
    vm.prank(deployer);
    CallAccess.set(entitySystem.toResourceId(), IEntitySystem.deleteObject.selector, address(unscopedSystem), true);

    // success, via UNSCOPED, the newly CallAccess defined caller
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callDeleteObject, (objectId)));

    // re-instantiate object (so we can successfully delete it again)
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    // revert, if direct caller is not a class access role member
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    entitySystem.deleteObject(objectId);

    // success, direct caller is a class access role member
    vm.prank(deployer);
    entitySystem.deleteObject(objectId);
  }

  function test_EntitySystem_deleteClass() public {
    // deleteClass - noAllowances

    // register Class (with the class scoped system tag)
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);

    // revert if calling from a scoped system
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(classScopedSystem))
    );
    world.call(CLASS_SCOPED_SYSTEM_ID, abi.encodeCall(ClassScopedMock.callDeleteClass, (classId)));

    // revert if calling from an unscoped system
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callDeleteClass, (classId)));

    // add UNSCOPED_SYSTEM_ID to the CallAccess table for deleteClass
    vm.prank(deployer);
    CallAccess.set(entitySystem.toResourceId(), IEntitySystem.deleteClass.selector, address(unscopedSystem), true);

    // still revert even with CallAccess
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callDeleteClass, (classId)));

    // revert on direct call
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, address(this)));
    entitySystem.deleteClass(classId);

    // revert even if direct caller is a class access role member
    vm.prank(deployer);
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, classId, deployer));
    entitySystem.deleteClass(classId);
  }

  function test_RoleManagermentSystem_scopedCreateRole() public {
    // scopedCreateRole - allowEntitySystemOrClassScopedSystem
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    // setup class and object to test against, success case for scopedCreateRole via EntitySystem
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    // revert, if direct calling
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    roleManagementSystem.scopedCreateRole(objectId, adminRole, adminRole, deployer);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(
      UNSCOPED_SYSTEM_ID,
      abi.encodeCall(UnscopedMock.callScopedCreateRole, (objectId, adminRole, adminRole, deployer))
    );

    // add UNSCOPED_SYSTEM_ID to the CallAccess table for the scopedCreateRole function
    vm.prank(deployer);
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      address(unscopedSystem),
      true
    );

    // success, via UNSCOPED, the newly CallAccess defined caller
    world.call(
      UNSCOPED_SYSTEM_ID,
      abi.encodeCall(UnscopedMock.callScopedCreateRole, (objectId, testRole, testRole, deployer))
    );

    // success, via the class scoped system call
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callScopedCreateRole, (objectId, adminRole, adminRole, deployer))
    );
  }

  function test_RoleManagermentSystem_scopedTransferRoleAdmin() public {
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    // setup class and object to test against
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    // create two roles which have themselves as admin
    vm.prank(deployer);
    roleManagementSystem.createRole(testRole, testRole);
    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // revert, if direct calling
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    roleManagementSystem.scopedTransferRoleAdmin(objectId, testRole, adminRole);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(
      UNSCOPED_SYSTEM_ID,
      abi.encodeCall(UnscopedMock.callScopedTransferRoleAdmin, (objectId, testRole, adminRole))
    );

    // success, via the class scoped system call
    vm.prank(deployer);
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callScopedTransferRoleAdmin, (objectId, testRole, adminRole))
    );
  }

  function test_RoleManagermentSystem_scopedGrantRole() public {
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    // setup class and object to test against, success case for scopedGrantRole via EntitySystem
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // revert, if direct calling
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    roleManagementSystem.scopedGrantRole(objectId, adminRole, alice);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callScopedGrantRole, (objectId, adminRole, alice)));

    // add UNSCOPED_SYSTEM_ID to the CallAccess table for the scopedGrantRole function
    vm.prank(deployer);
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedGrantRole.selector,
      address(unscopedSystem),
      true
    );

    // success, via UNSCOPED, the newly CallAccess defined caller
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callScopedGrantRole, (objectId, adminRole, bob)));

    // success, via the class scoped system call
    vm.prank(deployer);
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callScopedGrantRole, (objectId, adminRole, alice))
    );
  }

  function test_RoleManagermentSystem_scopedRevokeRole() public {
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    // setup class and object to test against
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);
    vm.prank(deployer);
    roleManagementSystem.grantRole(adminRole, alice);

    // revert, if direct calling
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    roleManagementSystem.scopedRevokeRole(objectId, adminRole, alice);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callScopedRevokeRole, (objectId, adminRole, alice)));

    // success, via the class scoped system call
    vm.prank(deployer);
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callScopedRevokeRole, (objectId, adminRole, alice))
    );
  }

  function test_RoleManagermentSystem_scopedRenounceRole() public {
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    // setup class and object to test against
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // revert, if direct calling
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    roleManagementSystem.scopedRenounceRole(objectId, adminRole, deployer);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(
      UNSCOPED_SYSTEM_ID,
      abi.encodeCall(UnscopedMock.callScopedRenounceRole, (objectId, adminRole, deployer))
    );

    // success, via the class scoped system call
    vm.prank(deployer);
    world.call(
      CLASS_SCOPED_SYSTEM_ID,
      abi.encodeCall(ClassScopedMock.callScopedRenounceRole, (objectId, adminRole, deployer))
    );
  }

  function test_RoleManagermentSystem_scopedRevokeAll() public {
    // allowEntitySystemOrClassScopedSystem
    ResourceId[] memory scopedSystemIds = new ResourceId[](1);
    scopedSystemIds[0] = CLASS_SCOPED_SYSTEM_ID;

    // setup class and object to test against
    vm.prank(deployer);
    entitySystem.registerClass(classId, scopedSystemIds);
    vm.prank(deployer);
    entitySystem.instantiate(classId, objectId, alice);

    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);
    vm.prank(deployer);
    roleManagementSystem.grantRole(adminRole, alice);

    // revert, if direct calling
    vm.expectRevert(abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(this)));
    roleManagementSystem.scopedRevokeAll(objectId, adminRole);

    // revert, if calling system is not class scoped
    vm.expectRevert(
      abi.encodeWithSelector(ISOFAccessSystem.SOFAccess_AccessDenied.selector, objectId, address(unscopedSystem))
    );
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callScopedRevokeAll, (objectId, adminRole)));

    // add UNSCOPED_SYSTEM_ID to the CallAccess table for the scopedRevokeAll function
    vm.prank(deployer);
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      address(unscopedSystem),
      true
    );

    // success, via UNSCOPED, the newly CallAccess defined caller
    world.call(UNSCOPED_SYSTEM_ID, abi.encodeCall(UnscopedMock.callScopedRevokeAll, (objectId, adminRole)));

    // success, via the class scoped system call
    vm.prank(deployer);
    world.call(CLASS_SCOPED_SYSTEM_ID, abi.encodeCall(ClassScopedMock.callScopedRevokeAll, (objectId, adminRole)));

    // EntitySystemm calling case success proven in EntitySystem.deleteClass and EntitySystem.deleteObject tests above
  }

  function _configureSOFCallAccess() internal {
    // TagSystem.sol
    CallAccess.set(tagSystem.toResourceId(), ITagSystem.setTag.selector, entitySystem.getAddress(), true);
    CallAccess.set(tagSystem.toResourceId(), ITagSystem.removeTag.selector, entitySystem.getAddress(), true);

    // RoleManagementSystem.sol
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      entitySystem.getAddress(),
      true
    );

    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      entitySystem.getAddress(),
      true
    );
  }

  function _configureEntitySystemAccess() internal {
    // EntitySystem.sol access configurations
    // set allowClassScopedSystemOrDirectClassAccessRole for setClassAccessRole
    accessConfigSystem.configureAccess(
      entitySystem.toResourceId(),
      IEntitySystem.setClassAccessRole.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowClassScopedSystemOrDirectClassAccessRole.selector
    );
    // set noAllowances for deleteClass
    accessConfigSystem.configureAccess(
      entitySystem.toResourceId(),
      IEntitySystem.deleteClass.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.noAllowances.selector
    );
    // set allowCallAccessOrClassScopedSystemOrDirectClassAccessRole for instantiate
    accessConfigSystem.configureAccess(
      entitySystem.toResourceId(),
      IEntitySystem.instantiate.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrClassScopedSystemOrDirectClassAccessRole.selector
    );
    // set allowClassScopedSystemOrDirectAccessRole for setObjectAccessRole
    accessConfigSystem.configureAccess(
      entitySystem.toResourceId(),
      IEntitySystem.setObjectAccessRole.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowClassScopedSystemOrDirectAccessRole.selector
    );
    // set allowCallAccessOrClassScopedSystemOrDirectClassAccessRole for deleteObject
    accessConfigSystem.configureAccess(
      entitySystem.toResourceId(),
      IEntitySystem.deleteObject.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrClassScopedSystemOrDirectClassAccessRole.selector
    );
    // set allowCallAccessOnly for scopedRegisterClass
    accessConfigSystem.configureAccess(
      entitySystem.toResourceId(),
      IEntitySystem.scopedRegisterClass.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOnly.selector
    );

    // EntitySystem.sol toggle access enforcement on
    accessConfigSystem.setAccessEnforcement(
      entitySystem.toResourceId(),
      IEntitySystem.setClassAccessRole.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.deleteClass.selector, true);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, true);
    accessConfigSystem.setAccessEnforcement(
      entitySystem.toResourceId(),
      IEntitySystem.setObjectAccessRole.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.deleteObject.selector, true);
    accessConfigSystem.setAccessEnforcement(
      entitySystem.toResourceId(),
      IEntitySystem.scopedRegisterClass.selector,
      true
    );
  }

  function _configureTagSystemAccess() internal {
    // Tag System access configurations
    // set allowCallAccessOrDirectAccessRole for setTag
    accessConfigSystem.configureAccess(
      tagSystem.toResourceId(),
      ITagSystem.setTag.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrDirectAccessRole.selector
    );
    // set allowCallAccessOrDirectAccessRole for removeTag
    accessConfigSystem.configureAccess(
      tagSystem.toResourceId(),
      ITagSystem.removeTag.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrDirectAccessRole.selector
    );

    // TagSystem.sol toggle access enforcement on
    accessConfigSystem.setAccessEnforcement(tagSystem.toResourceId(), ITagSystem.setTag.selector, true);
    accessConfigSystem.setAccessEnforcement(tagSystem.toResourceId(), ITagSystem.removeTag.selector, true);
  }

  function _configureRoleManagementSystemAccess() internal {
    // RoleManagementSystem.sol access config and enforcement
    accessConfigSystem.configureAccess(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrClassScopedSystem.selector
    );
    accessConfigSystem.configureAccess(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedTransferRoleAdmin.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowClassScopedSystemOnly.selector
    );
    accessConfigSystem.configureAccess(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedGrantRole.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrClassScopedSystem.selector
    );
    accessConfigSystem.configureAccess(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeRole.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowClassScopedSystemOnly.selector
    );
    accessConfigSystem.configureAccess(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRenounceRole.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowClassScopedSystemOnly.selector
    );
    accessConfigSystem.configureAccess(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      sOFAccessSystem.toResourceId(),
      ISOFAccessSystem.allowCallAccessOrClassScopedSystem.selector
    );

    accessConfigSystem.setAccessEnforcement(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedTransferRoleAdmin.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedGrantRole.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeRole.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRenounceRole.selector,
      true
    );
    accessConfigSystem.setAccessEnforcement(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      true
    );
  }
}
