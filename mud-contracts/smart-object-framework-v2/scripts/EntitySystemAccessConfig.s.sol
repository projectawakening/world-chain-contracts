// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { accessConfigSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { entitySystem } from "../src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { sOFAccessSystem } from "../src/namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { IEntitySystem } from "../src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { ISOFAccessSystem } from "../src/namespaces/sofaccess/interfaces/ISOFAccessSystem.sol";

contract EntitySystemAccessConfig is Script {

  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    
    // EntitySystem.sol access configurations
    // set allowClassScopedSystemOrDirectClassAccessRole for setClassAccessRole
    accessConfigSystem.configureAccess(entitySystem.toResourceId(), IEntitySystem.setClassAccessRole.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowClassScopedSystemOrDirectClassAccessRole.selector);
    // set allowDirectClassAccessRoleOnly for deleteClass
    accessConfigSystem.configureAccess(entitySystem.toResourceId(), IEntitySystem.deleteClass.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowDirectClassAccessRoleOnly.selector);
    // set allowCallAccessOrClassScopedSystemOrDirectClassAccessRole for instantiate
    accessConfigSystem.configureAccess(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowCallAccessOrClassScopedSystemOrDirectClassAccessRole.selector);
    // set allowClassScopedSystemOrDirectAccessRole for setObjectAccessRole
    accessConfigSystem.configureAccess(entitySystem.toResourceId(), IEntitySystem.setObjectAccessRole.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowClassScopedSystemOrDirectAccessRole.selector);
    // set allowCallAccessOrClassScopedSystemOrDirectClassAccessRole for deleteObject
    accessConfigSystem.configureAccess(entitySystem.toResourceId(), IEntitySystem.deleteObject.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowCallAccessOrClassScopedSystemOrDirectClassAccessRole.selector);
    // set allowCallAccessOnly for scopedRegisterClass
    accessConfigSystem.configureAccess(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowCallAccessOnly.selector);

    // EntitySystem.sol toggle access enforcement on
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.setClassAccessRole.selector, true);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.deleteClass.selector, true);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, true);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.setObjectAccessRole.selector, true);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.deleteObject.selector, true);
    accessConfigSystem.setAccessEnforcement(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, true);
    
    vm.stopBroadcast();
  }
}