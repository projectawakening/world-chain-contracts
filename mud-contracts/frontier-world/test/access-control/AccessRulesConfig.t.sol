// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

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

import { ACCESS_CONTROL_DEPLOYMENT_NAMESPACE as ACCESS_CONTROL } from "@eve/common-constants/src/constants.sol";

import { AccessConfig, AccessConfigData } from "../../src/codegen/tables/AccessConfig.sol";
import { IAccessControlErrors } from "../../src/modules/access-control/IAccessControlErrors.sol";
import { IAccessRulesConfigErrors } from "../../src/modules/access-control/IAccessRulesConfigErrors.sol";

import { AccessControlLib } from "../../src/modules/access-control/AccessControlLib.sol";
import { AccessRulesConfigLib } from "../../src/modules/access-control/AccessRulesConfigLib.sol";
import { AccessControlModule } from "../../src/modules/access-control/AccessControlModule.sol";

import { AccessControl } from "../../src/modules/access-control/systems/AccessControl.sol";
import { AccessRulesConfig } from "../../src/modules/access-control/systems/AccessRulesConfig.sol";
import { AccessRules } from "../../src/modules/access-control/systems/AccessRules.sol";

import { RootRoleData, RolesByContext, EnforcementLevel } from "../../src/modules/access-control/types.sol";
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
  using AccessRulesConfigLib for AccessRulesConfigLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  AccessControlLib.World AccessControlInterface;
  AccessRulesConfigLib.World AccessRulesConfigInterface;

  function setUp() public {
    
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));
    address ac = address(new AccessControl());
    address arc = address(new AccessRulesConfig());
    address ar = address(new AccessRules());
    // install AccessControlModule
    _installModule(new AccessControlModule(), ACCESS_CONTROL, ac, arc, ar);

    // initilize the AccessControlInterface object
    AccessControlInterface = AccessControlLib.World(world, ACCESS_CONTROL);
    // initilize the AccessRulesConfigInterface object
    AccessRulesConfigInterface = AccessRulesConfigLib.World(world, ACCESS_CONTROL);

  }

  // tests
  function testSetup() public {
    address AccessControlSystemAddress = Systems.getSystem(ACCESS_CONTROL.accessControlSystemId());
    ResourceId accessControlSystemId = SystemRegistry.get(AccessControlSystemAddress);
    assertEq(accessControlSystemId.getNamespace(), ACCESS_CONTROL);

    address AccessRulesConfigSystemAddress = Systems.getSystem(ACCESS_CONTROL.accessRulesConfigSystemId());
    ResourceId accessRulesConfigSystemId = SystemRegistry.get(AccessRulesConfigSystemAddress);
    assertEq(accessRulesConfigSystemId.getNamespace(), ACCESS_CONTROL);
  }

  // function testSetAccessControlRoles() public {
  //   uint256 entityId = 123456789;
  //   uint256 configId1 = 1;
  //   string memory transientRoleString = "TRANSIENT_ROLE";
  //   string memory mudRoleString = "MUD_ROLE";
  //   string memory originRoleString = "ORIGIN_ROLE";
    
  //   vm.startPrank(alice);
  //   RootRoleData memory rootDataAlice = AccessControlInterface.createRootRole(alice);

  //   bytes32 transientRoleId = AccessControlInterface.createRole(transientRoleString, rootDataAlice.rootAcct, rootDataAlice.roleId);
  //   bytes32 mudRoleId = AccessControlInterface.createRole(mudRoleString, rootDataAlice.rootAcct, rootDataAlice.roleId);
  //   bytes32 originRoleId = AccessControlInterface.createRole(originRoleString, rootDataAlice.rootAcct, rootDataAlice.roleId);
  //   bytes32[] memory transientRoleArray = new bytes32[](1);
  //   transientRoleArray[0] = transientRoleId;
  //   bytes32[] memory mudRoleArray = new bytes32[](1);
  //   mudRoleArray[0] = mudRoleId;
  //   bytes32[] memory originRoleArray = new bytes32[](1);
  //   originRoleArray[0] = originRoleId;

  //   RolesByContext memory rolesConfig1 = RolesByContext(transientRoleArray, mudRoleArray, originRoleArray);
  //   {
  //   AccessConfigData memory accessConfigDataBefore = AccessConfig.get(
  //     ACCESS_CONTROL.accessConfigTableId(),
  //     entityId,
  //     configId1
  //   );
  //   bytes32[] memory emptyArray = new bytes32[](0);

  //   assertEq(accessConfigDataBefore.enforcementLevel, uint8(0));
  //   assertEq(abi.encodePacked(accessConfigDataBefore.initialMsgSender), abi.encodePacked(emptyArray));
  //   assertEq(abi.encodePacked(accessConfigDataBefore.mudMsgSender), abi.encodePacked(emptyArray));
  //   assertEq(abi.encodePacked(accessConfigDataBefore.txOrigin), abi.encodePacked(emptyArray));
  //   }
  //   AccessRulesConfigInterface.setAccessControlRoles(entityId, configId1, rolesConfig1);
  //   {
  //   AccessConfigData memory accessConfigDataAfter = AccessConfig.get(
  //     ACCESS_CONTROL.accessConfigTableId(),
  //     entityId,
  //     configId1
  //   );

  //   assertEq(accessConfigDataAfter.enforcementLevel, uint8(0));
  //   assertEq(abi.encodePacked(accessConfigDataAfter.initialMsgSender), abi.encodePacked(transientRoleArray));
  //   // assertEq(abi.encodPacked(accessConfigDataAfter.mudMsgSender), abi.encodePacked(mudRoleArray));
  //   // assertEq(abi.encodePacked(accessConfigDataAfter.txOrigin), abi.encodePacked(originRoleArray));
  //   }
  // }

  function testSetEnforcementLevel() public {
    uint256 entityId = 123456789;
    uint256 configId1 = 1;

    AccessConfigData memory accessConfigDataBefore = AccessConfig.get(
      ACCESS_CONTROL.accessConfigTableId(),
      entityId,
      configId1
    );

    assertEq(accessConfigDataBefore.enforcementLevel, uint8(0));
    
    AccessRulesConfigInterface.setEnforcementLevel(entityId, configId1, EnforcementLevel.TRANSIENT_AND_MUD_AND_ORIGIN);
    
    AccessConfigData memory accessConfigDataAfter = AccessConfig.get(
      ACCESS_CONTROL.accessConfigTableId(),
      entityId,
      configId1
    );

    assertEq(accessConfigDataAfter.enforcementLevel, uint8(7));
  } 

  // helper function to guard against multiple module registrations on the same namespace
  function _installModule(IModule module, bytes14 namespace, address accessControlSystem, address accessRulesConfig, address accessRules) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this)) {
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    }
    world.installModule(module, abi.encode(namespace, accessControlSystem, accessRulesConfig, accessRules));
  }
}

