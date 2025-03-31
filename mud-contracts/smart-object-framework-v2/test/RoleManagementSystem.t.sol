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

import { IRoleManagementSystem } from "../src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";
import { roleManagementSystem } from "../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

import "../src/namespaces/evefrontier/codegen/index.sol";

contract RoleManagementSystemTest is MudTest {
  IBaseWorld world;

  bytes32 adminRole = bytes32("ADMIN_ROLE");
  bytes32 testRole = bytes32("TEST_ROLE");

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
  }

  function test_createRole() public {
    vm.startPrank(deployer);
    // revert, if role or admin is bytes32(0)
    vm.expectRevert(abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_InvalidRole.selector));
    roleManagementSystem.createRole(bytes32(0), adminRole);

    vm.expectRevert(abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_InvalidRole.selector));
    roleManagementSystem.createRole(testRole, bytes32(0));

    // create a role which is admin for itself
    roleManagementSystem.createRole(adminRole, adminRole);

    // check created role values
    RoleData memory adminRoleData = Role.get(adminRole);
    assertEq(adminRoleData.exists, true);
    assertEq(adminRoleData.admin, adminRole);

    // check that the entry point caller has been assigned as a member of this role
    bool hasRole = HasRole.getIsMember(adminRole, deployer);
    assertEq(hasRole, true);

    // revert if role already exists
    // revert RoleManagement_RoleAlreadyCreated(role);
    vm.expectRevert(
      abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_RoleAlreadyCreated.selector, adminRole)
    );
    roleManagementSystem.createRole(adminRole, adminRole);

    // create a role which has another role as admin
    roleManagementSystem.createRole(testRole, adminRole);

    vm.stopPrank();
  }

  function test_transferRoleAdmin() public {
    // create two roles which have themselves as admin
    vm.prank(deployer);
    roleManagementSystem.createRole(testRole, testRole);
    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // revert if the intial caller is not a member of admin
    vm.expectRevert(
      abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector, testRole, address(this))
    );
    roleManagementSystem.transferRoleAdmin(testRole, testRole);

    vm.startPrank(deployer);
    bytes32 doesNotExist = bytes32("DOES_NOT_EXIST");

    // revert, if admin does not exist
    vm.expectRevert(
      abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_RoleDoesNotExist.selector, doesNotExist)
    );
    roleManagementSystem.transferRoleAdmin(testRole, doesNotExist);

    // revert, if admin is already assigned to this role
    vm.expectRevert(
      abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_AdminAlreadyAssigned.selector, testRole, testRole)
    );
    roleManagementSystem.transferRoleAdmin(testRole, testRole);

    //success, change admin role of testRole to adminRole
    roleManagementSystem.transferRoleAdmin(testRole, adminRole);

    // check that the new admin was set for role in table
    RoleData memory testRoleData = Role.get(testRole);
    assertEq(testRoleData.admin, adminRole);
    vm.stopPrank();

    // revert, if caller is not an admin role member
    vm.expectRevert(
      abi.encodeWithSelector(
        IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector,
        adminRole,
        address(this)
      )
    );
    roleManagementSystem.transferRoleAdmin(testRole, adminRole);
  }

  function test_grantRole() public {
    // create a role
    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // revert if the intial caller is not a member of admin
    vm.expectRevert(
      abi.encodeWithSelector(
        IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector,
        adminRole,
        address(this)
      )
    );
    roleManagementSystem.grantRole(adminRole, alice);

    vm.startPrank(deployer);
    // if an account already has a role, remain the same
    bool beforeHasRole = HasRole.getIsMember(adminRole, deployer);
    uint256 beforeIndex = HasRole.getIndex(adminRole, deployer);
    assertEq(beforeHasRole, true);

    roleManagementSystem.grantRole(adminRole, deployer);

    bool afterHasRole = HasRole.getIsMember(adminRole, deployer);
    uint256 afterIndex = HasRole.getIndex(adminRole, deployer);
    assertEq(afterHasRole, true);
    assertEq(beforeIndex, afterIndex);

    // if account does not have a role, grant it
    bool beforeNewHasRole = HasRole.getIsMember(adminRole, alice);
    address[] memory beforeNewMembers = Role.getMembers(adminRole);
    assertEq(beforeNewHasRole, false);

    roleManagementSystem.grantRole(adminRole, alice);

    bool afterNewHasRole = HasRole.getIsMember(adminRole, alice);
    address[] memory afterNewMembers = Role.getMembers(adminRole);
    assertEq(afterNewHasRole, true);
    assertEq(afterNewMembers.length, beforeNewMembers.length + 1);
    assertEq(afterNewMembers[afterNewMembers.length - 1], alice);

    vm.stopPrank();

    // revert, if caller is not an admin role member
    vm.expectRevert(
      abi.encodeWithSelector(
        IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector,
        adminRole,
        address(this)
      )
    );
    roleManagementSystem.grantRole(adminRole, alice);
  }

  function test_revokeRole() public {
    // create a role
    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // revert if the intial caller is not a member of admin
    vm.expectRevert(
      abi.encodeWithSelector(
        IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector,
        adminRole,
        address(this)
      )
    );
    roleManagementSystem.revokeRole(adminRole, alice);

    vm.startPrank(deployer);
    // revert if trying to revoke self
    vm.expectRevert(abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_MustRenounceSelf.selector));
    roleManagementSystem.revokeRole(adminRole, deployer);

    // if an account does not have a role, remain the same
    bool beforeHasRole = HasRole.getIsMember(adminRole, alice);
    assertEq(beforeHasRole, false);

    roleManagementSystem.revokeRole(adminRole, alice);

    bool afterHasRole = HasRole.getIsMember(adminRole, alice);
    assertEq(afterHasRole, false);

    // grant alice the role
    roleManagementSystem.grantRole(adminRole, alice);

    // if account has a role, revoke it
    bool beforeNewHasRole = HasRole.getIsMember(adminRole, alice);
    uint256 beforeIndex = HasRole.getIndex(adminRole, alice);
    address[] memory beforeMembers = Role.getMembers(adminRole);
    assertEq(beforeNewHasRole, true);

    roleManagementSystem.revokeRole(adminRole, alice);

    bool afterNewHasRole = HasRole.getIsMember(adminRole, alice);
    address[] memory afterMembers = Role.getMembers(adminRole);
    assertEq(afterNewHasRole, false);
    assertEq(afterMembers.length, beforeMembers.length - 1);
    if (beforeIndex < beforeMembers.length - 1) {
      assertEq(afterMembers[beforeIndex], beforeMembers[beforeMembers.length - 1]);
    }
    vm.stopPrank();

    // revert, if caller is not an admin role member
    vm.expectRevert(
      abi.encodeWithSelector(
        IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector,
        adminRole,
        address(this)
      )
    );
    roleManagementSystem.revokeRole(adminRole, alice);
  }

  function test_renounceRole() public {
    // create a role
    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);

    // grant alice the role
    vm.prank(deployer);
    roleManagementSystem.grantRole(adminRole, alice);

    // revert if trying to renounce with wrong confirmation account
    vm.expectRevert(abi.encodeWithSelector(IRoleManagementSystem.RoleManagement_BadConfirmation.selector));
    roleManagementSystem.renounceRole(adminRole, deployer);

    vm.startPrank(deployer);
    // if account has a role, revoke it
    bool beforeHasRole = HasRole.getIsMember(adminRole, deployer);
    uint256 beforeIndex = HasRole.getIndex(adminRole, deployer);
    address[] memory beforeMembers = Role.getMembers(adminRole);
    assertEq(beforeHasRole, true);

    roleManagementSystem.renounceRole(adminRole, deployer);

    bool afterHasRole = HasRole.getIsMember(adminRole, deployer);
    address[] memory afterMembers = Role.getMembers(adminRole);
    assertEq(afterHasRole, false);
    assertEq(afterMembers.length, beforeMembers.length - 1);
    assertEq(afterMembers[beforeIndex], beforeMembers[beforeMembers.length - 1]);

    // if an account does not have a role, remain the same
    bool beforeDoesNotHaveRole = HasRole.getIsMember(adminRole, deployer);
    assertEq(beforeDoesNotHaveRole, false);

    roleManagementSystem.renounceRole(adminRole, deployer);

    bool afterDoesNotHaveRole = HasRole.getIsMember(adminRole, deployer);
    assertEq(afterDoesNotHaveRole, false);
    vm.stopPrank();
  }

  function test_revokeAll() public {
    // create a role and grant an additional account to the role
    vm.prank(deployer);
    roleManagementSystem.createRole(adminRole, adminRole);
    vm.prank(deployer);
    roleManagementSystem.grantRole(adminRole, alice);

    // revert if the intial caller is not a member of admin
    vm.expectRevert(
      abi.encodeWithSelector(
        IRoleManagementSystem.RoleManagement_UnauthorizedAccount.selector,
        adminRole,
        address(this)
      )
    );
    roleManagementSystem.revokeAll(adminRole);

    vm.startPrank(deployer);
    address[] memory beforeMembers = Role.getMembers(adminRole);
    uint256 beforeDeployerIndex = HasRole.getIndex(adminRole, deployer);
    bool beforeDeployerHasRole = HasRole.getIsMember(adminRole, deployer);
    uint256 beforeAliceIndex = HasRole.getIndex(adminRole, alice);
    bool beforeAliceHasRole = HasRole.getIsMember(adminRole, alice);
    assertEq(beforeDeployerHasRole, true);
    assertEq(beforeDeployerIndex, 0);
    assertEq(beforeAliceHasRole, true);
    assertEq(beforeAliceIndex, 1);
    assertEq(beforeMembers.length, 2);

    // successfully revoke all roles
    roleManagementSystem.revokeAll(adminRole);

    address[] memory afterMembers = Role.getMembers(adminRole);
    bool afterDeployerHasRole = HasRole.getIsMember(adminRole, alice);
    bool afterAliceHasRole = HasRole.getIsMember(adminRole, alice);
    assertEq(afterDeployerHasRole, false);
    assertEq(afterAliceHasRole, false);
    assertEq(afterMembers.length, 0);

    vm.stopPrank();
  }
}
