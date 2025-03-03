// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { accessConfigSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { roleManagementSystem } from "../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { sOFAccessSystem } from "../src/namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { IRoleManagementSystem } from "../src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";
import { ISOFAccessSystem } from "../src/namespaces/sofaccess/interfaces/ISOFAccessSystem.sol";

contract RoleManagementSystemAccessConfig is Script {

  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

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