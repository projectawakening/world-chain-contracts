// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { ERC2771Forwarder } from "../src/metatx/ERC2771ForwarderWithHashNonce.sol";

contract DeployScript is Script {
  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    //This contract can be modified to use ERC2771ForwarderWithHashNonce
    ERC2771Forwarder forwarder = new ERC2771Forwarder("Forwarder");

    console.log("ForwarderAddress:", address(forwarder));

    vm.stopBroadcast();
  }
}
