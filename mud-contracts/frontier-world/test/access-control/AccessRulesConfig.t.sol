// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// import "forge-std/Test.sol";
// import { console } from "forge-std/console.sol";

// import { World } from "@latticexyz/world/src/World.sol";
// import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
// import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
// import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
// import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
// import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
// import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
// import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
// import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
// import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
// import { IModule } from "@latticexyz/world/src/IModule.sol";

// import { createCoreModule } from "../CreateCoreModule.sol";

// import { ACCESS_CONTROL_MODULE_NAMESPACE and ACCESS_CONTROL } from "../../src/modules/access-control/constants.sol";

// import { Role, RoleData } from "../../src/codegen/tables/Role.sol";
// import { HasRole, HasRoleData } from "../../src/codegen/tables/HasRole.sol";
// import { RoleAdminChanged } from "../../src/codegen/tables/RoleAdminChanged.sol";
// import { RoleCreated } from "../../src/codegen/tables/RoleCreated.sol";
// import { RoleGranted } from "../../src/codegen/tables/RoleGranted.sol";
// import { RoleRevoked } from "../../src/codegen/tables/RoleRevoked.sol";
// import { IAccessControlErrors } from "../../src/modules/access-control/IAccessControlErrors.sol";

// import { AccessControlLib } from "../../src/modules/access-control/AccessControlLib.sol";
// import { AccessControlModule } from "../../src/modules/access-control/AccessControlModule.sol";

// import { AccessControl } from "../../src/modules/access-control/systems/AccessControl.sol";

// import { RootRoleData } from "../../src/modules/access-control/types.sol";
// import { Utils } from "../../src/modules/access-control/Utils.sol";


// contract AccessControlTest is Test {
//   using Utils for bytes14;
//   using AccessControlLib for AccessControlLib.World;
//   using WorldResourceIdInstance for ResourceId;

//   IBaseWorld world;
//   AccessControlLib.World AccessControlInterface;
//   AccessControlModule accessControlModuleModule;

//   address deployer = vm.addr(0);
//   address alice = vm.addr(1);
//   address bob = vm.addr(2);

//   string memory testRoleName = "TEST_TEST_TEST_TEST_TEST_TEST_TEST_TEST";

//   function setUp() public {
//     world = IBaseWorld(address(new World()));
//     world.initialize(createCoreModule());
//     // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
//     StoreSwitch.setStoreAddress(address(world));

//     // install AccessControl module
//     _installModule(new AccessControlModule(), ACCESS_CONTROL);

//     // initilize the AccessControlInterface object
//     AccessControlInterface = AccessControlLib.World(world, ACCESS_CONTROL);
//   }

//   // tests
//   function testSetup() public {
//     address AccessControlSystemAddress = Systems.getSystem(ACCESS_CONTROL.accessControlSystemId());
//     ResourceId accessControlSystemId = SystemRegistry.get(AccessControlSystemAddress);
//     assertEq(accessControlSystemId.getNamespace(), ACCESS_CONTROL);
//   }