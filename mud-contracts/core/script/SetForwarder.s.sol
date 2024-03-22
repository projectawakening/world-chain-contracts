// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";

contract SetForwarder is Script {
  function run(address worldAddress) external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address trustedForwarderAddress = vm.envOr("FORWARDER_CONTRACT_ADDRESS", address(0x0));

    vm.startBroadcast(deployerPrivateKey);

    IWorld(worldAddress).setTrustedForwarder(trustedForwarderAddress);

    console.log("TrustedForwarder: ");
    console.logAddress(trustedForwarderAddress);
    console.log(IWorld(worldAddress).isTrustedForwarder(trustedForwarderAddress));

    vm.stopBroadcast();
  }
}
