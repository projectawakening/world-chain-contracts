// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { accessConfigSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { tagSystem } from "../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { sOFAccessSystem } from "../src/namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { ITagSystem } from "../src/namespaces/evefrontier/interfaces/ITagSystem.sol";
import { ISOFAccessSystem } from "../src/namespaces/sofaccess/interfaces/ISOFAccessSystem.sol";

contract TagSystemAccessConfig is Script {

  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    
    // Tag System access configurations
    // set allowCallAccessOrDirectAccessRole for setTag
    accessConfigSystem.configureAccess(tagSystem.toResourceId(), ITagSystem.setTag.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowCallAccessOrDirectAccessRole.selector);
    // set allowCallAccessOrDirectAccessRole for removeTag
    accessConfigSystem.configureAccess(tagSystem.toResourceId(), ITagSystem.removeTag.selector, sOFAccessSystem.toResourceId(), ISOFAccessSystem.allowCallAccessOrDirectAccessRole.selector);

    // TagSystem.sol toggle access enforcement on
    accessConfigSystem.setAccessEnforcement(tagSystem.toResourceId(), ITagSystem.setTag.selector, true);
    accessConfigSystem.setAccessEnforcement(tagSystem.toResourceId(), ITagSystem.removeTag.selector, true);

    vm.stopBroadcast();
  }
}