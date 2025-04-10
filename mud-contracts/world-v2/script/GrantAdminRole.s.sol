// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

contract GrantAdminRole is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    bytes32 adminRole = bytes32("admin");
    
    // Read comma-separated list of admin addresses from environment variable
    address[] memory adminAddresses = vm.envAddress("ADMIN_ACCOUNTS", ",");
    
    vm.startBroadcast(deployerPrivateKey);
    
    // Grant admin role to each address
    for (uint256 i = 0; i < adminAddresses.length; i++) {
      roleManagementSystem.grantRole(adminRole, adminAddresses[i]);
      console.log("Granted admin role to:", adminAddresses[i]);
    }
    
    vm.stopBroadcast();
  }
}
