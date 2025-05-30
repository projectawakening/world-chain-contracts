// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IEntitySystem } from "../src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { ITagSystem } from "../src/namespaces/evefrontier/interfaces/ITagSystem.sol";
import { IRoleManagementSystem } from "../src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";

import { callAccessSystem } from "../src/namespaces/evefrontier/codegen/systems/CallAccessSystemLib.sol";
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

    runSetSOFCallAccess(deployer);

    vm.stopBroadcast();
  }
}

function runSetSOFCallAccess(address delegator) {
  // TagSystem.sol
  callAccessSystem.callFrom(delegator).addCallAccess(tagSystem.toResourceId(), ITagSystem.setTag.selector, entitySystem.getAddress());
  callAccessSystem.callFrom(delegator).addCallAccess(tagSystem.toResourceId(), ITagSystem.removeTag.selector, entitySystem.getAddress());

  // RoleManagementSystem.sol
  callAccessSystem.callFrom(delegator).addCallAccess(
    roleManagementSystem.toResourceId(),
    IRoleManagementSystem.scopedCreateRole.selector,
    entitySystem.getAddress()
  );
  callAccessSystem.callFrom(delegator).addCallAccess(
    roleManagementSystem.toResourceId(),
    IRoleManagementSystem.scopedRevokeAll.selector,
    entitySystem.getAddress()
  );
}