// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { CallAccess } from "../src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

import { IAccessConfigSystem } from "../src/namespaces/evefrontier/interfaces/IAccessConfigSystem.sol";
import { IEntitySystem } from "../src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { ITagSystem } from "../src/namespaces/evefrontier/interfaces/ITagSystem.sol";
import { IRoleManagementSystem } from "../src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";

import { accessConfigSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { entitySystem } from "../src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { tagSystem } from "../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { roleManagementSystem } from "../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

contract SetSOFCallAccess is Script {
  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    vm.startBroadcast(deployerPrivateKey);

    // TagSystem.sol
    CallAccess.set(tagSystem.toResourceId(), ITagSystem.setTag.selector, entitySystem.getAddress(), true);
    CallAccess.set(tagSystem.toResourceId(), ITagSystem.removeTag.selector, entitySystem.getAddress(), true);

    // RoleManagementSystem.sol
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      entitySystem.getAddress(),
      true
    );
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      entitySystem.getAddress(),
      true
    );
    vm.stopBroadcast();
  }
}
