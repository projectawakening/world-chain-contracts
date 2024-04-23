// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";

import { ERC721Module } from "../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { IERC721Mintable } from "../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { registerERC721 } from "../src/modules/eve-erc721-puppet/registerERC721.sol";
import { StaticDataGlobalTableData } from "../src/codegen/tables/StaticDataGlobalTable.sol";
import { SmartCharacterLib } from "../src/modules/smart-character/SmartCharacterLib.sol";

contract PostDeploy is Script {
  using SmartCharacterLib for SmartCharacterLib.World;

  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory baseURI = vm.envString("BASE_URI");

    vm.startBroadcast(deployerPrivateKey);

    IERC721Mintable erc721Token;
    world.installModule(new PuppetModule(), new bytes(0));
    erc721Token = registerERC721(
      world,
      "myERC721",
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: baseURI })
    );

    console.log("Deploying ERC721 token with address: ", address(erc721Token));
      // SmartCharacterLib.World({iface: IBaseWorld(world), namespace: "frontier"})
    //   .registerERC721Token(address(erc721Token));
    vm.stopBroadcast();
  }
}
