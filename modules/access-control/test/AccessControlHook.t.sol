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
import { DummySystem, DummyModule } from "./DummyModule.sol";
import "./constants.sol";


contract AccessControlTest is Test {
  using AccessControlLib for AccessControlLib.World;
  using SmartObjectLib for SmartObjectLib.World;
  using WorldResourceIdInstance for ResourceId;
  using AccessControlUtils for bytes14;
  using SmartObjectUtils for bytes14;

  AccessControlLib.World accessControl;
  SmartObjectLib.World smartObject;

  IBaseWorld world;
  AccessControlModule accessControleModule;
  DummyModule dummyModule;
  bytes14 smartObjectNamespace = bytes14("smartObject_v0");
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
    AccessControlModule module = new AccessControlModule();
    SmartObjectFrameworkModule smartObjectModule = new SmartObjectFrameworkModule();

    world.installModule(module, abi.encode(namespace));
    world.installModule(smartObjectModule, abi.encode(smartObjectNamespace));
    StoreSwitch.setStoreAddress(address(world));
    accessControl = AccessControlLib.World(world, namespace);
    smartObject = SmartObjectLib.World(world, smartObjectNamespace);
  }

  function registerDummySystem(bytes14 namespace) public {
    world.installModule;
  }

  function testSetup() public {
    address accessControlSystem = Systems.getSystem(namespace.accessControlSystemId());
    ResourceId accessControlSystemId = SystemRegistry.get(accessControlSystem);
    assertEq(accessControlSystemId.getNamespace(), namespace);
  }

  function testRegisterOnlyRoleHook() public {
    smartObject.registerHook(namespace.accessControlSystemId(), IAccessControlMUD.onlyRoleHook.selector);

    onlyRoleHookId = uint256(keccak256(abi.encodePacked(namespace.accessControlSystemId(), IAccessControlMUD.onlyRoleHook.selector)));
    HookTableData memory data = HookTable.get(smartObjectNamespace.hookTableTableId(), onlyRoleHookId);

    assertEq(data.isHook, true);
    assertEq(ResourceId.unwrap(data.systemId), ResourceId.unwrap(namespace.accessControlSystemId()));
    assertEq(data.functionSelector, IAccessControlMUD.onlyRoleHook.selector);
  }

  function testRegisterOnlyRoleANDHook() public {
    smartObject.registerHook(namespace.accessControlSystemId(), IAccessControlMUD.onlyRoleANDHook.selector);

    onlyRoleANDHookId = uint256(keccak256(abi.encodePacked(namespace.accessControlSystemId(), IAccessControlMUD.onlyRoleANDHook.selector)));
    HookTableData memory data = HookTable.get(smartObjectNamespace.hookTableTableId(), onlyRoleANDHookId);

    assertEq(data.isHook, true);
    assertEq(ResourceId.unwrap(data.systemId), ResourceId.unwrap(namespace.accessControlSystemId()));
    assertEq(data.functionSelector, IAccessControlMUD.onlyRoleANDHook.selector);
  }

  function testRegisterOnlyRoleORHook() public {
    smartObject.registerHook(namespace.accessControlSystemId(), IAccessControlMUD.onlyRoleORHook.selector);

    onlyRoleORHookId = uint256(keccak256(abi.encodePacked(namespace.accessControlSystemId(), IAccessControlMUD.onlyRoleORHook.selector)));
    HookTableData memory data = HookTable.get(smartObjectNamespace.hookTableTableId(), onlyRoleORHookId);

    assertEq(data.isHook, true);
    assertEq(ResourceId.unwrap(data.systemId), ResourceId.unwrap(namespace.accessControlSystemId()));
    assertEq(data.functionSelector, IAccessControlMUD.onlyRoleORHook.selector);
  }
}