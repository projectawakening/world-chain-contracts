// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { createCoreModule } from "../CreateCoreModule.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { HookType } from "@eveworld/smart-object-framework/src/types.sol";

import { IAccessControlErrors } from "../../src/modules/access-control/IAccessControlErrors.sol";
import { IAccessRulesConfigErrors } from "../../src/modules/access-control/IAccessRulesConfigErrors.sol";
import { AccessControlModule } from "../../src/modules/access-control/AccessControlModule.sol";
import { AccessControlLib } from "../../src/modules/access-control/AccessControlLib.sol";
import { AccessRulesConfigLib } from "../../src/modules/access-control/AccessRulesConfigLib.sol";
import { AccessControl } from "../../src/modules/access-control/systems/AccessControl.sol";
import { AccessRulesConfig } from "../../src/modules/access-control/systems/AccessRulesConfig.sol";
import { RootRoleData, EnforcementLevel } from "../../src/modules/access-control/types.sol";
import { Utils } from "../../src/modules/access-control/Utils.sol";

import {MODULE_MOCK_NAME,
  FORWARD_MOCK_SYSTEM_ID,
  HOOKABLE_MOCK_SYSTEM_ID,
  ACCESS_RULE_MOCK_SYSTEM_ID} from "./mocks/mockconstants.sol";

import { ModuleMock } from "./mocks/ModuleMock.sol";
import { IForwardMock } from "./mocks/IForwardMock.sol";
import { ForwardMock } from "./mocks/ForwardMock.sol";
import { IHookableMock } from "./mocks/IHookableMock.sol";
import { HookableMock } from "./mocks/HookableMock.sol";
import { IAccessRuleMock } from "./mocks/IAccessRuleMock.sol";
import { IAccessRuleMockErrors } from "./mocks/IAccessRuleMockErrors.sol";
import { AccessRuleMock } from "./mocks/AccessRuleMock.sol";

contract AccessRuleMockTest is Test {
  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);

  address deployer = vm.addr(deployerPK);
  address alice = vm.addr(alicePK);
  address bob = vm.addr(bobPK);

  using Utils for bytes14;
  using SmartObjectLib for SmartObjectLib.World;
  using AccessControlLib for AccessControlLib.World;
  using AccessRulesConfigLib for AccessRulesConfigLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;

  // decare SOF related
  SmartObjectFrameworkModule SOFMod;
  EntityCore EntityCoreSystem;
  HookCore HookCoreSystem;
  ModuleCore ModuleCoreSystem;
  SmartObjectLib.World SOFInterface;



  // declare AccessControl related
  AccessControlModule AccessControlMod;
  AccessControlLib.World AccessControlInterface;
  AccessRulesConfigLib.World AccessRulesConfigInterface;
 
  // declare mock related
  ModuleMock ModMock;
  HookableMock HookableMockSystem;
  ForwardMock ForwardMockSystem;
  AccessRuleMock AccessRuleMockSystem;

  // CLASS entityType
  uint8 constant CLASS = 2;
  uint256 entityId;

  function setUp() public {
    vm.startPrank(deployer);
    // world setup
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));
    
    // SOF deployemnts
    SOFMod = new SmartObjectFrameworkModule();
    EntityCoreSystem = new EntityCore();
    HookCoreSystem = new HookCore();
    ModuleCoreSystem = new ModuleCore();
    
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(WORLD_NAMESPACE)) == deployer) {
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(WORLD_NAMESPACE), address(SOFMod));
    }
    world.installModule(
      SOFMod,
      abi.encode(WORLD_NAMESPACE, address(EntityCoreSystem), address(HookCoreSystem), address(ModuleCoreSystem))
    );

    // initilize the SOFInterface object
    SOFInterface = SmartObjectLib.World(world, WORLD_NAMESPACE);

    // access-control deployment
    AccessControlMod = new AccessControlModule();
    
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(WORLD_NAMESPACE)) == deployer) {
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(WORLD_NAMESPACE), address(AccessControlMod));
    }
    world.installModule(
      AccessControlMod,
      abi.encode(WORLD_NAMESPACE, address(new AccessControl()), address(new AccessRulesConfig()))
    );
    // initilize the AccessControlInterface object
    AccessControlInterface = AccessControlLib.World(world, WORLD_NAMESPACE);
    // initilize the AccessRulesConfigInterface object
    AccessRulesConfigInterface = AccessRulesConfigLib.World(world, WORLD_NAMESPACE);
    
    // mock related deployments
    ModMock = new ModuleMock();
    // create a target System for hooks
    HookableMockSystem = new HookableMock();
    // create a forwarder System to test internal value of WorldContext._msgSender()
    ForwardMockSystem = new ForwardMock();
    // create access hook mock System
    AccessRuleMockSystem = new AccessRuleMock();

    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(WORLD_NAMESPACE)) == deployer) {
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(WORLD_NAMESPACE), address(ModMock));
    }
    world.installModule(
      ModMock,
      abi.encode(WORLD_NAMESPACE, address(ForwardMockSystem), address(HookableMockSystem), address(AccessRuleMockSystem))
    );

    // SOF configuration 
    // create the CLASS entityType
    SOFInterface.registerEntityType(CLASS, "CLASS");
    // register our entity as a CLASS entityType
    entityId = 1234567890;
    SOFInterface.registerEntity(entityId, CLASS);
    uint256 mockModuleId = uint256(keccak256(abi.encodePacked(address(ModMock))));
    
    // register Forward and Hookable to the MockMod on the SOF
    SOFInterface.registerEVEModule(mockModuleId, MODULE_MOCK_NAME, FORWARD_MOCK_SYSTEM_ID);
    SOFInterface.registerEVEModule(mockModuleId, MODULE_MOCK_NAME, HOOKABLE_MOCK_SYSTEM_ID);
    // associate MockMod with entityId
    SOFInterface.associateModule(entityId, mockModuleId);

    // register the hook logic (AccessRuleMock.accessRule)
    SOFInterface.registerHook(ACCESS_RULE_MOCK_SYSTEM_ID, IAccessRuleMock.accessRule.selector);

    uint256 hookId = uint256(keccak256(abi.encodePacked(
      ResourceId.unwrap(ACCESS_RULE_MOCK_SYSTEM_ID),
      IAccessRuleMock.accessRule.selector
    )));

    // associate hook logic with entityId
    SOFInterface.associateHook(entityId, hookId);

    // add the hook logic to be executed before target System/function (HookableMock.target)
    SOFInterface.addHook(
      hookId,
      HookType.BEFORE,
      HOOKABLE_MOCK_SYSTEM_ID,
      IHookableMock.target.selector
    );
    vm.stopPrank();
  }

  // tests
  function testSetup() public {
    address AccessControlSystemAddress = Systems.getSystem(WORLD_NAMESPACE.accessControlSystemId());
    ResourceId accessControlSystemId = SystemRegistry.get(AccessControlSystemAddress);
    assertEq(accessControlSystemId.getNamespace(), WORLD_NAMESPACE);

    address AccessRulesConfigSystemAddress = Systems.getSystem(WORLD_NAMESPACE.accessRulesConfigSystemId());
    ResourceId accessRulesConfigSystemId = SystemRegistry.get(AccessRulesConfigSystemAddress);
    assertEq(accessRulesConfigSystemId.getNamespace(), WORLD_NAMESPACE);

    address AccessRulesSystemAddress = Systems.getSystem(ACCESS_RULE_MOCK_SYSTEM_ID);
    ResourceId accessRulesSystemId = SystemRegistry.get(AccessRulesSystemAddress);
    assertEq(accessRulesSystemId.getNamespace(), WORLD_NAMESPACE);

    address hookableMockSystemAddress = Systems.getSystem(HOOKABLE_MOCK_SYSTEM_ID);
    ResourceId hookableMockSystemId = SystemRegistry.get(hookableMockSystemAddress);
    assertEq(hookableMockSystemId.getNamespace(), WORLD_NAMESPACE);

    address forwardMockSystemAddress = Systems.getSystem(FORWARD_MOCK_SYSTEM_ID);
    ResourceId forwardMockSystemId = SystemRegistry.get(forwardMockSystemAddress);
    assertEq(forwardMockSystemId.getNamespace(), WORLD_NAMESPACE);

    ResourceId accessConfigTableId = WORLD_NAMESPACE.accessConfigTableId();
    assertEq(ResourceIds.getExists(WORLD_NAMESPACE.accessConfigTableId()), true);
    assertEq(WorldResourceIdInstance.getNamespace(accessConfigTableId), WORLD_NAMESPACE);

    ResourceId hasRoleTableId = WORLD_NAMESPACE.hasRoleTableId();
    assertEq(ResourceIds.getExists(WORLD_NAMESPACE.hasRoleTableId()), true);
    assertEq(WorldResourceIdInstance.getNamespace(hasRoleTableId), WORLD_NAMESPACE);

  }

  function testAccessRuleEnforcementLevel3PassingCases() public {
    uint256 configId1 = 1;
    string memory transientRoleString1 = "TRANSIENT_ROLE_1";
    string memory transientRoleString2 = "TRANSIENT_ROLE_2";
    string memory originRoleString = "ORIGIN_ROLE";
    
    vm.startPrank(alice, bob);
    // create a root role from which we can create other roles (as admin)
    RootRoleData memory rootDataAlice = AccessControlInterface.createRootRole(alice);
    // create a role for each access contex
    bytes32 transientRoleId1 = AccessControlInterface.createRole(transientRoleString1, rootDataAlice.rootAcct, rootDataAlice.roleId);
    bytes32 transientRoleId2 = AccessControlInterface.createRole(transientRoleString2, rootDataAlice.rootAcct, rootDataAlice.roleId);
    bytes32 originRoleId = AccessControlInterface.createRole(originRoleString, rootDataAlice.rootAcct, rootDataAlice.roleId);

    bytes32[] memory transientRoleArray = new bytes32[](2);
    transientRoleArray[0] = transientRoleId1;
    transientRoleArray[1] = transientRoleId2;
    bytes32[] memory originRoleArray = new bytes32[](1);
    originRoleArray[0] = originRoleId;

    AccessRulesConfigInterface.setAccessControlRoles(entityId, configId1, EnforcementLevel.TRANSIENT, transientRoleArray);
    AccessRulesConfigInterface.setAccessControlRoles(entityId, configId1, EnforcementLevel.ORIGIN, originRoleArray);
    AccessRulesConfigInterface.setEnforcementLevel(entityId, configId1, EnforcementLevel.TRANSIENT_AND_ORIGIN);

    AccessControlInterface.grantRole(transientRoleId2, alice);
    AccessControlInterface.grantRole(originRoleId, bob);

    // Case1: verify TRANSIENT_AND_ORIGIN, ALL roles satisfied
    bytes memory dataCase1 = world.call(
      FORWARD_MOCK_SYSTEM_ID,
      abi.encodeCall(IForwardMock.callTarget,  (entityId))
    );

    assertEq(AccessControlInterface.hasRole(transientRoleId2, alice), true);
    assertEq(AccessControlInterface.hasRole(originRoleId, bob), true);
    assertEq(abi.decode(dataCase1, (bool)), true);

   // Case2: verify TRANSIENT_AND_ORIGIN, TRANSIENT ONLY roles satisfied
    AccessControlInterface.revokeRole(originRoleId, bob);

    bytes memory dataCase2 = world.call(
      FORWARD_MOCK_SYSTEM_ID,
      abi.encodeCall(IForwardMock.callTarget, (entityId))
    );

    assertEq(AccessControlInterface.hasRole(transientRoleId2, alice), true);
    assertEq(AccessControlInterface.hasRole(originRoleId, bob), false);
    assertEq(abi.decode(dataCase2, (bool)), true);

    // Case3: verify TRANSIENT_AND_ORIGIN, ORIGIN ONLY roles satisfied
    AccessControlInterface.revokeRole(transientRoleId2, alice);
    AccessControlInterface.grantRole(originRoleId, bob);
    
    bytes memory dataCase3 = world.call(
      FORWARD_MOCK_SYSTEM_ID,
      abi.encodeCall(IForwardMock.callTarget,  (entityId))
    );

    assertEq(AccessControlInterface.hasRole(transientRoleId2, alice), false);
    assertEq(AccessControlInterface.hasRole(originRoleId, bob), true);
    assertEq(abi.decode(dataCase3, (bool)), true);
  }

  function testAccessRuleEnforcementLevel2Pass() public {
    uint256 configId1 = 1;
    string memory originRoleString = "ORIGIN_ROLE";
    
    vm.startPrank(alice, bob);
    // create a root role from which we can create other roles (as admin)
    RootRoleData memory rootDataAlice = AccessControlInterface.createRootRole(alice);
    
    bytes32 originRoleId = AccessControlInterface.createRole(originRoleString, rootDataAlice.rootAcct, rootDataAlice.roleId);
    bytes32[] memory originRoleArray = new bytes32[](1);
    originRoleArray[0] = originRoleId;

    AccessRulesConfigInterface.setAccessControlRoles(entityId, configId1, EnforcementLevel.ORIGIN, originRoleArray);
    AccessRulesConfigInterface.setEnforcementLevel(entityId, configId1, EnforcementLevel.ORIGIN);

    AccessControlInterface.grantRole(originRoleId, bob);

    // Case: verify ORIGIN_ONLY role satisfied
    bytes memory dataCase1 = world.call(
      FORWARD_MOCK_SYSTEM_ID,
      abi.encodeCall(IForwardMock.callTarget,  (entityId))
    );

    assertEq(AccessControlInterface.hasRole(originRoleId, bob), true);
    assertEq(abi.decode(dataCase1, (bool)), true);
  }

  function testAccessRuleEnforcementLevel1Pass() public {
    uint256 configId1 = 1;
    string memory transientRoleString = "TRANSIENT_ROLE";
    
    vm.startPrank(alice, bob);
    // create a root role from which we can create other roles (as admin)
    RootRoleData memory rootDataAlice = AccessControlInterface.createRootRole(alice);
    // create a role for each access contex
    bytes32 transientRoleId = AccessControlInterface.createRole(transientRoleString, rootDataAlice.rootAcct, rootDataAlice.roleId);

    bytes32[] memory transientRoleArray = new bytes32[](1);
    transientRoleArray[0] = transientRoleId;

    AccessRulesConfigInterface.setAccessControlRoles(entityId, configId1, EnforcementLevel.TRANSIENT, transientRoleArray);
    AccessRulesConfigInterface.setEnforcementLevel(entityId, configId1, EnforcementLevel.TRANSIENT);

    AccessControlInterface.grantRole(transientRoleId, alice);

    // Case1: verify TRANSIENT_ONLY role satisfied
    bytes memory dataCase1 = world.call(
      FORWARD_MOCK_SYSTEM_ID,
      abi.encodeCall(IForwardMock.callTarget,  (entityId))
    );

    assertEq(AccessControlInterface.hasRole(transientRoleId, alice), true);
    assertEq(abi.decode(dataCase1, (bool)), true);
  }
}
