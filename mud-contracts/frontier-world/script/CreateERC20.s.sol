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

contract CreateERC20 is Script {
  function run() external {
    StoreSwitch.setStoreAddress(0x004BfD5E619AFE26AbD52DfA50f1c047cF7d6151);
    IBaseWorld world = IBaseWorld(0x004BfD5E619AFE26AbD52DfA50f1c047cF7d6151);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);
    // TODO: Need to make a ERC20 Factory that feeds into the static data module
    IERC20Mintable erc20Token;
    StoreSwitch.setStoreAddress(address(world));
    erc20Token = registerERC20(
      world,
      "blockbusters",
      ERC20MetadataData({ decimals: 18, name: "Blockbusters Token", symbol: "$BBT"})
    );

    console.log("Deploying ERC20 token with address: ", address(erc20Token));
    vm.stopBroadcast();
  }
}
