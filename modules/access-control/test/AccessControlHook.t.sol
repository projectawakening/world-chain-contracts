// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { createCoreModule } from "./createCoreModule.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";
import { AccessControlModule } from "../src/AccessControlModule.sol";
import { SmartObjectFrameworkModule } from "@eve/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { IAccessControl, IAccessControlMUD } from "../src/IAccessControlMUD.sol";
import { Utils as AccessControlUtils } from "../src/utils.sol";
import { Utils as SmartObjectUtils } from "@eve/smart-object-framework/src/utils.sol";

import { EntityToRole } from "../src/codegen/tables/EntityToRole.sol";
import { EntityToRoleAND } from "../src/codegen/tables/EntityToRoleAND.sol";
import { EntityToRoleOR } from "../src/codegen/tables/EntityToRoleOR.sol";
import { HookTable, HookTableData } from "@eve/smart-object-framework/src/codegen/index.sol";

import { AccessControlLib } from "../src/AccessControlLib.sol";
import { SmartObjectLib } from "@eve/smart-object-framework/src/SmartObjectLib.sol";
import { DummyLib } from "./DummyLib.sol";
import { DummySystem, DummyModule } from "./DummyModule.sol";
import "./constants.sol";
import { HookType } from "@eve/smart-object-framework/src/types.sol";


contract AccessControlTest is Test {
  using AccessControlLib for AccessControlLib.World;
  using SmartObjectLib for SmartObjectLib.World;
  using DummyLib for DummyLib.World;
  using WorldResourceIdInstance for ResourceId;
  using AccessControlUtils for bytes14;
  using SmartObjectUtils for bytes14;

  AccessControlLib.World accessControl;
  SmartObjectLib.World smartObject;
  DummyLib.World dummy;

  AccessControlModule accessControlModule;
  SmartObjectFrameworkModule smartObjectModule;
  DummyModule dummyModule;

  ResourceId dummySystemId;
  ResourceId accessControlSystemId;
  uint256 accessControlModuleId;
  uint256 dummyModuleId;

  IBaseWorld world;
  bytes14 smartObjectNamespace = bytes14("SmartObject_v0");
  bytes14 accessControlNamespace = bytes14("RBACTest");
  bytes14 dummyNamespace = bytes14("DummyTest");
  bytes14 namespace = bytes14("someNamespace");

  address alice = address(101);
  address bob = address(102);
  address charlie = address(1337);

  bytes32 aliceRole = bytes32(uint256(uint160(alice)));
  bytes32 bobRole = bytes32(uint256(uint160(bob)));
  bytes32 charlieRole = bytes32(uint256(uint160(charlie)));
  bytes32 newRole = bytes32("420");
  uint256 entity1 = 123;

  uint256 onlyRoleHookId;
  uint256 onlyRoleANDHookId;
  uint256 onlyRoleORHookId;


  /**
   * @dev runs before each test function
   */
  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    accessControlModule = new AccessControlModule();
    smartObjectModule = new SmartObjectFrameworkModule();
    dummyModule = new DummyModule();

    world.installModule(smartObjectModule, abi.encode(smartObjectNamespace));
    world.installModule(accessControlModule, abi.encode(accessControlNamespace));
    world.installModule(dummyModule, abi.encode(dummyNamespace));
    StoreSwitch.setStoreAddress(address(world));
    smartObject = SmartObjectLib.World(world, smartObjectNamespace);
    accessControl = AccessControlLib.World(world, accessControlNamespace);
    dummy = DummyLib.World(world, dummyNamespace);

    dummySystemId = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, dummyNamespace, DUMMY_SYSTEM_NAME))));
    accessControlSystemId = accessControlNamespace.accessControlSystemId();
    dummyModuleId = uint256(keccak256(abi.encodePacked(address(dummyModule))));
    accessControlModuleId = uint256(keccak256(abi.encodePacked(address(accessControlModule))));
  }

  function testSetup() public {
    assertEq(accessControlSystemId.getNamespace(), accessControlNamespace);
    assertEq(dummySystemId.getNamespace(), dummyNamespace);
  }

  function testRegisterOnlyRoleHook() public {
    smartObject.registerHook(accessControlNamespace.accessControlSystemId(), IAccessControlMUD.onlyRoleHook.selector);

    onlyRoleHookId = uint256(keccak256(abi.encodePacked(accessControlNamespace.accessControlSystemId(), IAccessControlMUD.onlyRoleHook.selector)));
    HookTableData memory data = HookTable.get(smartObjectNamespace.hookTableTableId(), onlyRoleHookId);

    assertEq(data.isHook, true);
    assertEq(ResourceId.unwrap(data.systemId), ResourceId.unwrap(accessControlNamespace.accessControlSystemId()));
    assertEq(data.functionSelector, IAccessControlMUD.onlyRoleHook.selector);
  }

  function testRegisterOnlyRoleANDHook() public {
    smartObject.registerHook(accessControlNamespace.accessControlSystemId(), IAccessControlMUD.onlyRoleANDHook.selector);

    onlyRoleANDHookId = uint256(keccak256(abi.encodePacked(accessControlNamespace.accessControlSystemId(), IAccessControlMUD.onlyRoleANDHook.selector)));
    HookTableData memory data = HookTable.get(smartObjectNamespace.hookTableTableId(), onlyRoleANDHookId);

    assertEq(data.isHook, true);
    assertEq(ResourceId.unwrap(data.systemId), ResourceId.unwrap(accessControlNamespace.accessControlSystemId()));
    assertEq(data.functionSelector, IAccessControlMUD.onlyRoleANDHook.selector);
  }

  function testRegisterOnlyRoleORHook() public {
    smartObject.registerHook(accessControlNamespace.accessControlSystemId(), IAccessControlMUD.onlyRoleORHook.selector);

    onlyRoleORHookId = uint256(keccak256(abi.encodePacked(accessControlNamespace.accessControlSystemId(), IAccessControlMUD.onlyRoleORHook.selector)));
    HookTableData memory data = HookTable.get(smartObjectNamespace.hookTableTableId(), onlyRoleORHookId);

    assertEq(data.isHook, true);
    assertEq(ResourceId.unwrap(data.systemId), ResourceId.unwrap(accessControlNamespace.accessControlSystemId()));
    assertEq(data.functionSelector, IAccessControlMUD.onlyRoleORHook.selector);
  }

  function testInitializeSingletonRoles() public {
    vm.prank(alice);
    accessControl.claimSingletonRole(alice);
    vm.prank(bob);
    accessControl.claimSingletonRole(bob);
    vm.prank(charlie);
    accessControl.claimSingletonRole(charlie);
    assertEq(accessControl.hasRole(aliceRole, alice), true);
    assertEq(accessControl.hasRole(bobRole, bob), true);
    assertEq(accessControl.hasRole(charlieRole, charlie), true);
  }

  function registerEntity() public {
    //register entity
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntity(entity1, OBJECT);

    // register system associated with module
    smartObject.registerEVEModule(dummyModuleId, DUMMY_MODULE_NAME, dummySystemId);

    //associate entity with module
    smartObject.associateModule(entity1, dummyModuleId);
  }

  function testAddOnlyRoleHook() public {
    // initializing access-control and hooks
    testInitializeSingletonRoles();
    registerEntity();
    testRegisterOnlyRoleHook();
    accessControl.setOnlyRoleConfig(entity1, aliceRole);
    smartObject.associateHook(entity1, onlyRoleHookId);
    smartObject.addHook(onlyRoleHookId, HookType.BEFORE, dummySystemId, DummySystem.echoFoo.selector);
    
    //
    vm.startPrank(alice);
    dummy.echoFoo(entity1); //this works because the OnlyRole hook gates `echoFoo` to `aliceRole` only
    vm.stopPrank();
  }

  function testOnlyRoleHookRevertAccessControlUnauthorizedAccount() public {
    testAddOnlyRoleHook();

    vm.prank(charlie);
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, entity1, aliceRole));
    dummy.echoFoo(entity1);
  }
}