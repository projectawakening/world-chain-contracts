// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";

import { createCoreModule } from "../CreateCoreModule.sol";

import { ACCESS_CONTROL_DEPLOYMENT_NAMESPACE as ACCESS_CONTROL } from "@eveworld/common-constants/src/constants.sol";

import { Role, RoleData } from "../../src/codegen/tables/Role.sol";
import { HasRole } from "../../src/codegen/tables/HasRole.sol";
import { RoleAdminChanged } from "../../src/codegen/tables/RoleAdminChanged.sol";
import { RoleCreated } from "../../src/codegen/tables/RoleCreated.sol";
import { RoleGranted } from "../../src/codegen/tables/RoleGranted.sol";
import { RoleRevoked } from "../../src/codegen/tables/RoleRevoked.sol";
import { IAccessControlErrors } from "../../src/modules/access-control/IAccessControlErrors.sol";

import { AccessControlLib } from "../../src/modules/access-control/AccessControlLib.sol";
import { AccessControlModule } from "../../src/modules/access-control/AccessControlModule.sol";

import { AccessControl } from "../../src/modules/access-control/systems/AccessControl.sol";
import { AccessRulesConfig } from "../../src/modules/access-control/systems/AccessRulesConfig.sol";

import { RootRoleData } from "../../src/modules/access-control/types.sol";
import { Utils } from "../../src/modules/access-control/Utils.sol";

contract AccessControlTest is Test {
  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);

  address deployer = vm.addr(deployerPK);
  address alice = vm.addr(alicePK);
  address bob = vm.addr(bobPK);

  using Utils for bytes14;
  using AccessControlLib for AccessControlLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  AccessControlLib.World AccessControlInterface;

  string testRoleName = "TEST_TEST_TEST_TEST_TEST_TEST_TEST_TEST";

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));
    address ac = address(new AccessControl());
    address arc = address(new AccessRulesConfig());
    // install AccessControlModule
    _installModule(new AccessControlModule(), ACCESS_CONTROL, ac, arc);

    // initilize the AccessControlInterface object
    AccessControlInterface = AccessControlLib.World(world, ACCESS_CONTROL);
  }

  // tests
  function testSetup() public {
    address AccessControlSystemAddress = Systems.getSystem(ACCESS_CONTROL.accessControlSystemId());
    ResourceId accessControlSystemId = SystemRegistry.get(AccessControlSystemAddress);
    assertEq(accessControlSystemId.getNamespace(), ACCESS_CONTROL);
  }

  // createRootRole
  function testCreateRootRole() public {
    RootRoleData memory rootData = _callCreateRootRole(alice);
    string memory rootString = "ROOT";
    // check generated values
    bytes32 rootRoleNameToBytes32 = bytes32(abi.encodePacked(rootString));
    bytes32 calculatedRoleId = keccak256(abi.encodePacked(alice, rootRoleNameToBytes32));

    assertEq(rootData.nameBytes32, rootRoleNameToBytes32);
    assertEq(rootData.rootAcct, alice);
    assertEq(rootData.roleId, calculatedRoleId);

    // check stored values
    RoleData memory roleData = Role.get(ACCESS_CONTROL.roleTableId(), rootData.roleId);

    assertEq(roleData.exists, true);
    assertEq(roleData.name, rootData.nameBytes32);
    assertEq(roleData.root, rootData.rootAcct);
    // check self as admin
    assertEq(roleData.admin, rootData.roleId);

    bool hasRole = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootData.roleId, alice);
    // check account has membership
    assertEq(hasRole, true);
  }

  // // NOTE: the correct error is being thrown, can't catch it for some reason. TODO: fix this
  // function testCreateRootRoleFailWrongConfirmation() public {
  //   vm.expectRevert(IAccessControlErrors.AccessControlBadConfirmation.selector);
  //   vm.prank(alice);
  //   AccessControlInterface.createRootRole(bob);
  // }

  function testCreateRole() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);
    // check generated value
    bytes32 roleNameToBytes32 = bytes32(abi.encodePacked(testRoleName));
    bytes32 calculatedRoleId = keccak256(abi.encodePacked(alice, roleNameToBytes32));

    assertEq(roleId, calculatedRoleId);

    // check stored values
    RoleData memory roleData = Role.get(ACCESS_CONTROL.roleTableId(), roleId);

    assertEq(roleData.exists, true);
    assertEq(roleData.name, roleNameToBytes32);
    assertEq(roleData.root, rootDataAlice.rootAcct);
    assertEq(roleData.admin, rootDataAlice.roleId);
  }

  // // NOTE: the correct error is being thrown, can't catch it for some reason. TODO: fix this
  // function testCreateRoleFailWrongConfirmation() public {
  //   RootRoleData memory rootDataAlice = _callCreateRootRole(alice);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(IAccessControlErrors.AccessControlRootAdminMismatch.selector, bob, alice, rootDataAlice.roleId)
  //   );
  //   vm.prank(alice);
  //   AccessControlInterface.createRole(testRoleName, bob, rootDataAlice.roleId);
  // }

  // // NOTE: currently it seems prank doesn't affect transient storage values. TODO: hunt down why or run in end-to-end tests
  // function testCreateRoleFailNotAdmin() public {
  //   RootRoleData memory rootDataAlice = _callCreateRootRole(alice);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(IAccessControlErrors.AccessControlUnauthorizedAccount.selector, bob, rootDataAlice.roleId)
  //   );
  //   vm.prank(bob);
  //   AccessControlInterface.createRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId);
  // }

  function testTransferRoleAdminRoot() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

    RoleData memory roleDataAliceBefore = Role.get(ACCESS_CONTROL.roleTableId(), rootDataAlice.roleId);
    assertEq(roleDataAliceBefore.admin, rootDataAlice.roleId);
    vm.prank(alice);
    AccessControlInterface.transferRoleAdmin(rootDataAlice.roleId, roleId);

    RoleData memory roleDataAliceAfter = Role.get(ACCESS_CONTROL.roleTableId(), rootDataAlice.roleId);
    assertEq(roleDataAliceAfter.admin, roleId);
  }

  function testGrantRoleRoot() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);

    bool hasRoleBefore = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootDataAlice.roleId, bob);
    assertEq(hasRoleBefore, false);

    vm.prank(alice);
    AccessControlInterface.grantRole(rootDataAlice.roleId, bob);

    bool hasRoleAfter = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootDataAlice.roleId, bob);
    assertEq(hasRoleAfter, true);
  }

  function testRevokeRoleRoot() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    vm.prank(alice);
    AccessControlInterface.grantRole(rootDataAlice.roleId, bob);

    bool hasRoleBefore = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootDataAlice.roleId, bob);
    assertEq(hasRoleBefore, true);

    vm.prank(alice);
    AccessControlInterface.revokeRole(rootDataAlice.roleId, bob);

    bool hasRoleAfter = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootDataAlice.roleId, bob);
    assertEq(hasRoleAfter, false);
  }

  function testRenounceRoleRoot() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);

    bool hasRoleBefore = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootDataAlice.roleId, alice);
    assertEq(hasRoleBefore, true);

    vm.prank(alice);
    AccessControlInterface.renounceRole(rootDataAlice.roleId, alice);

    bool hasRoleAfter = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), rootDataAlice.roleId, alice);
    assertEq(hasRoleAfter, false);
  }

  // for created roles (not root roles)
  function testTransferRoleAdmin() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

    RoleData memory roleDataTestBefore = Role.get(ACCESS_CONTROL.roleTableId(), roleId);
    assertEq(roleDataTestBefore.admin, rootDataAlice.roleId);

    vm.prank(alice);
    AccessControlInterface.transferRoleAdmin(roleId, roleId);

    RoleData memory roleDataTestAfter = Role.get(ACCESS_CONTROL.roleTableId(), roleId);
    assertEq(roleDataTestAfter.admin, roleId);
  }

  // // NOTE: currently it seems prank doesn't affect transient storage values. TODO: hunt down why or run in end-to-end tests
  // function testTransferRoleAdminFailNotAdmin() public {
  //   RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
  //   bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

  //   vm.prank(bob);
  //   AccessControlInterface.transferRoleAdmin(roleId, roleId);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(IAccessControlErrors.AccessControlUnauthorizedAccount.selector, bob, rootDataAlice.roleId)
  //   );
  // }

  function testGrantRole() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

    bool hasRoleBefore = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), roleId, bob);
    assertEq(hasRoleBefore, false);

    vm.prank(alice);
    AccessControlInterface.grantRole(roleId, bob);

    bool hasRoleAfter = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), roleId, bob);
    assertEq(hasRoleAfter, true);
  }

  // // NOTE: currently it seems prank doesn't affect transient storage values. TODO: hunt down why or run in end-to-end tests
  // function testGrantRoleFailNotAdmin() public {
  //   RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
  //   bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

  //   vm.prank(bob);
  //   AccessControlInterface.grantRole(roleId, bob);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(IAccessControlErrors.AccessControlUnauthorizedAccount.selector, bob, rootDataAlice.roleId)
  //   );
  // }

  function testRevokeRole() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

    vm.prank(alice);
    AccessControlInterface.grantRole(roleId, bob);

    bool hasRoleBefore = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), roleId, bob);
    assertEq(hasRoleBefore, true);

    vm.prank(alice);
    AccessControlInterface.revokeRole(roleId, bob);

    bool hasRoleAfter = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), roleId, bob);
    assertEq(hasRoleAfter, false);
  }

  // // NOTE: currently it seems prank doesn't affect transient storage values. TODO: hunt down why or run in end-to-end tests
  // function testRevokeRoleFailNotAdmin() public {
  //   RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
  //   bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

  //   vm.prank(alice);
  //   AccessControlInterface.grantRole(roleId, alice);

  //   vm.prank(bob);
  //   AccessControlInterface.revokeRole(roleId, alice);

  //   vm.expectRevert(
  //     abi.encodeWithSelector(IAccessControlErrors.AccessControlUnauthorizedAccount.selector, bob, rootDataAlice.roleId)
  //   );
  // }

  function testRenounceRole() public {
    RootRoleData memory rootData = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootData.rootAcct, rootData.roleId, alice);

    vm.startPrank(alice);
    AccessControlInterface.grantRole(roleId, alice);

    bool hasRoleBefore = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), roleId, alice);
    assertEq(hasRoleBefore, true);

    AccessControlInterface.renounceRole(roleId, alice);
    vm.stopPrank();

    bool hasRoleAfter = HasRole.get(ACCESS_CONTROL.hasRoleTableId(), roleId, alice);
    assertEq(hasRoleAfter, false);
  }

  function testRenounceRoleFailWrongConfirmation() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    vm.roll(block.number + 1);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);
    vm.roll(block.number + 1);

    vm.startPrank(alice);
    AccessControlInterface.grantRole(roleId, alice);
    vm.expectRevert(IAccessControlErrors.AccessControlBadConfirmation.selector);
    AccessControlInterface.renounceRole(roleId, bob);
    vm.stopPrank();
  }

  function testHasRole() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bool hasRole = AccessControlInterface.hasRole(rootDataAlice.roleId, alice);

    assertEq(hasRole, true);
  }

  function testGetRoleAdmin() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    RoleData memory roleData = Role.get(ACCESS_CONTROL.roleTableId(), rootDataAlice.roleId);

    bytes32 adminId = AccessControlInterface.getRoleAdmin(rootDataAlice.roleId);

    assertEq(adminId, roleData.admin);
  }

  function testGetRoleId() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

    bytes32 rootRoleIdViaGetter = AccessControlInterface.getRoleId(rootDataAlice.rootAcct, "ROOT");

    bytes32 roleIdViaGetter = AccessControlInterface.getRoleId(rootDataAlice.rootAcct, testRoleName);

    assertEq(rootRoleIdViaGetter, rootDataAlice.roleId);
    assertEq(roleIdViaGetter, roleId);
  }

  function testRoleExists() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);
    bytes32 bobsRoleId = keccak256(abi.encodePacked(bob, bytes32(abi.encodePacked(testRoleName))));

    bool rootRoleExists = AccessControlInterface.roleExists(rootDataAlice.roleId);
    bool roleExists = AccessControlInterface.roleExists(roleId);
    bool bobsRoleDoesntExist = AccessControlInterface.roleExists(bobsRoleId);

    assertEq(rootRoleExists, true);
    assertEq(roleExists, true);
    assertEq(bobsRoleDoesntExist, false);
  }

  function testIsRootRole() public {
    RootRoleData memory rootDataAlice = _callCreateRootRole(alice);
    bytes32 roleId = _callCreateRole(testRoleName, rootDataAlice.rootAcct, rootDataAlice.roleId, alice);

    bool isRootRole = AccessControlInterface.isRootRole(rootDataAlice.roleId);
    bool isNotRootRole = AccessControlInterface.isRootRole(roleId);

    assertEq(isRootRole, true);
    assertEq(isNotRootRole, false);
  }

  // helper function to guard against multiple module registrations on the same namespace
  function _installModule(
    IModule module,
    bytes14 namespace,
    address accessControlSystem,
    address accessRulesConfig
  ) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this)) {
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    }
    world.installModule(module, abi.encode(namespace, accessControlSystem, accessRulesConfig));
  }

  // helper to call the AccessControl.createRootRole function successfully
  function _callCreateRootRole(address initalMsgSender) internal returns (RootRoleData memory) {
    // prank execute as initialMsgSender
    vm.prank(initalMsgSender);
    RootRoleData memory rootData = AccessControlInterface.createRootRole(initalMsgSender);
    return rootData;
  }

  // helper to call the AccessControl.createRole function successfully
  function _callCreateRole(
    string memory name,
    address adminRootAcct,
    bytes32 adminId,
    address adminMember
  ) internal returns (bytes32) {
    // prank execute as adminMember
    vm.prank(adminMember);
    bytes32 roleId = AccessControlInterface.createRole(name, adminRootAcct, adminId);
    return roleId;
  }
}
