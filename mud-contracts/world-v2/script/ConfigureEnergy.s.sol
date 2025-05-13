// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { AssemblyEnergyConfig } from "../src/namespaces/evefrontier/codegen/index.sol";

contract ConfigureEnergy is Script {
  error ArrayLengthMismatch(uint256 assemblyIdsLength, uint256 energyConstantsLength);
  error EmptyArray();

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    
    // Read comma-separated list of fuel smart object ids from environment variable
    uint256[] memory assemblyIds = vm.envUint("ASSEMBLY_TYPE_ID", ",");
    uint256[] memory energyConstants = vm.envUint("ENERGY_CONSTANT", ",");

    // Validate array lengths
    if (assemblyIds.length == 0 || energyConstants.length == 0) {
      revert EmptyArray();
    }
    
    if (assemblyIds.length != energyConstants.length) {
      revert ArrayLengthMismatch(assemblyIds.length, energyConstants.length);
    }
      
    vm.startBroadcast(deployerPrivateKey);

    for (uint256 i = 0; i < assemblyIds.length; i++) {
      AssemblyEnergyConfig.setEnergyConstant(assemblyIds[i], energyConstants[i]);
    }

    vm.stopBroadcast();
  }
}
