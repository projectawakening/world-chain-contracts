// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { createCoreModule } from "./createCoreModule.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { AccessControlModule } from "../src/AccessControlModule.sol";
import { IAccessControl, IAccessControlMUD } from "../src/IAccessControlMUD.sol";
import { Utils } from "../src/utils.sol";
import { EntityToRole } from "../src/codegen/tables/EntityToRole.sol";
import { EntityToRoleAND } from "../src/codegen/tables/EntityToRoleAND.sol";
import { EntityToRoleOR } from "../src/codegen/tables/EntityToRoleOR.sol";

import { AccessControlLib } from "../src/AccessControlLib.sol";

contract AccessControlTest is Test {
  using AccessControlLib for AccessControlLib.World;
  AccessControlLib.World accessControl;
  using Utils for bytes14;

  IBaseWorld world;
  AccessControlModule accessControleModule;
  bytes14 namespace = bytes14("someNamespace");
  bytes14 namespace2 = bytes14("otherNamespace");

  address alice = address(101);
  address bob = address(102);
  address charlie = address(1337);

  bytes32 aliceRole = bytes32(uint256(uint160(alice)));
  bytes32 bobRole = bytes32(uint256(uint160(bob)));
  bytes32 charlieRole = bytes32(uint256(uint160(charlie)));
  bytes32 newRole = bytes32("420");
  uint256 entity1 = 123;


  /**
   * @dev runs before each test function
   */
  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    AccessControlModule module = new AccessControlModule();
    world.installModule(module, abi.encode(namespace));
    StoreSwitch.setStoreAddress(address(world));
    accessControl = AccessControlLib.World(world, namespace);
  }

  function testSetup() public {
    setUp();
    bool result = accessControl.supportsInterface(type(IAccessControl).interfaceId);
    assertEq(result, true);
    result = accessControl.supportsInterface(type(IAccessControlMUD).interfaceId);
    assertEq(result, true);
  }

  function testSupportsInterface() public {
    bool result = accessControl.supportsInterface(type(IAccessControl).interfaceId);
    assertEq(result, true);
    result = accessControl.supportsInterface(type(IAccessControlMUD).interfaceId);
    assertEq(result, true);
  }

  function testInstallModuleTwice() public {
    world.installModule(new AccessControlModule(), abi.encode(namespace2));
    AccessControlLib.World memory anotheraccessControl = AccessControlLib.World(world, namespace2);
    bool result = anotheraccessControl.supportsInterface(type(IAccessControl).interfaceId);
    assertEq(result, true);
    result = anotheraccessControl.supportsInterface(type(IAccessControlMUD).interfaceId);
    assertEq(result, true);
  }

  function testClaimSingletonRole() public {
    vm.prank(alice);
    accessControl.claimSingletonRole(alice);
    assertEq(accessControl.getRoleAdmin(aliceRole), aliceRole);
    assertEq(accessControl.hasRole(aliceRole, alice), true);
  }

  function testClaimSingletonRoleRevertBadConfirmation() public {
    vm.prank(alice);
    vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector);
    accessControl.claimSingletonRole(bob);
  }

  function testClaimSingletonRoleRevertRoleExists() public {
    vm.startPrank(alice);
    accessControl.claimSingletonRole(alice);
    assertEq(accessControl.getRoleAdmin(aliceRole), aliceRole);
    assertEq(accessControl.hasRole(aliceRole, alice), true);

    vm.expectRevert(abi.encodeWithSelector(IAccessControlMUD.AccessControlSingletonRoleExists.selector, alice));
    accessControl.claimSingletonRole(alice);
    vm.stopPrank();
  }

  function testGrantRole() public {
    testClaimSingletonRole();

    vm.prank(alice);
    accessControl.grantRole(aliceRole, bob);
    assertEq(accessControl.hasRole(aliceRole, bob), true);
  }

  function testGrantRoleRevertUnauthorizedAccount() public {
    testClaimSingletonRole();

    vm.prank(charlie);
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, charlie, aliceRole));
    accessControl.grantRole(aliceRole, charlie);
  }

  function testRevokeRole() public {
    testGrantRole();

    vm.prank(alice);
    accessControl.revokeRole(aliceRole, bob);
    assertEq(accessControl.hasRole(aliceRole, bob), false);
  }

  function testRevokeRoleRevertUnauthorizedAccount() public {
    testGrantRole();

    vm.prank(charlie);
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, charlie, aliceRole));
    accessControl.revokeRole(aliceRole, bob);
  }

  function testCreateRole() public {
    testClaimSingletonRole();

    vm.prank(alice);
    accessControl.createRole(newRole, aliceRole);
    assertEq(accessControl.getRoleAdmin(newRole), aliceRole);
  }

  function testCreateRoleRevertlUnauthorizedAccount() public {
    testClaimSingletonRole();

    vm.prank(charlie);
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, charlie, aliceRole));
    accessControl.createRole(newRole, aliceRole);
  }

  function testCreateRoleRevertRoleAlreadyCreated() public {
    testCreateRole();

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(IAccessControlMUD.AccessControlRoleAlreadyCreated.selector, newRole, alice));
    accessControl.createRole(newRole, aliceRole);
  }

  function testSetOnlyRoleConfig() public {
    accessControl.setOnlyRoleConfig(entity1, aliceRole);
    assertEq(EntityToRole.get(namespace.entityToRoleTableId(), entity1), aliceRole);
  }

  function testSetOnlyRoleANDConfig(bytes32[] memory roles) public returns (bytes32[] memory) {
    accessControl.setOnlyRoleANDConfig(entity1, roles);

    bytes32[] memory rolesInStorage = EntityToRoleAND.get(namespace.entityToRoleANDTableId(), entity1);
    assertEq(rolesInStorage.length, roles.length);
    for(uint i = 0; i < roles.length; i++) assertEq(roles[i], rolesInStorage[i]);

    return roles;
  }

  function testSetOnlyRoleORConfig(bytes32[] memory roles) public returns (bytes32[] memory) {
    accessControl.setOnlyRoleORConfig(entity1, roles);

    bytes32[] memory rolesInStorage = EntityToRoleOR.get(namespace.entityToRoleORTableId(), entity1);
    assertEq(rolesInStorage.length, roles.length);
    for(uint i = 0; i < roles.length; i++) assertEq(roles[i], rolesInStorage[i]);

    return roles;
  }
}