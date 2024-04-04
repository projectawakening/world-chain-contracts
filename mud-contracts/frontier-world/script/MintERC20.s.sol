// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { IERC20Mintable } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import { ERC20Module } from "@latticexyz/world-modules/src/modules/erc20-puppet/ERC20Module.sol";
import { registerERC20 } from "@latticexyz/world-modules/src/modules/erc20-puppet/registerERC20.sol";

import { ERC20MetadataData } from "@latticexyz/world-modules/src/modules/erc20-puppet/tables/ERC20Metadata.sol";

// TODO: This uses hardcoded value, this is bad 
contract MintERC20 is Script {
  function run() external {
    StoreSwitch.setStoreAddress(0x004BfD5E619AFE26AbD52DfA50f1c047cF7d6151);
    IBaseWorld world = IBaseWorld(0x004BfD5E619AFE26AbD52DfA50f1c047cF7d6151);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);
    // TODO: Need to make a ERC20 Factory that feeds into the static data module
    StoreSwitch.setStoreAddress(address(world));
    IERC20Mintable erc20 = IERC20Mintable(0x4f3068230c179Cf5Bf9E780C092Ce86642eaF0d7);
    address to = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    erc20.mint(to, 1000000000000 ether);

    console.log("minting to: ", address(to));
    console.log("amount: ", 1000000000000 ether);
    vm.stopBroadcast();
  }
}
