// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { ERC721Module } from "@latticexyz/world-modules/src/modules/erc721-puppet/ERC721Module.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import { registerERC721 } from "@latticexyz/world-modules/src/modules/erc721-puppet/registerERC721.sol";
import { ERC721MetadataData } from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Metadata.sol";
import { SMART_CHARACTER_MODULE_NAME, SMART_CHARACTER_MODULE_NAMESPACE } from "../src/systems/constants.sol";

contract PostDeploy is Script {
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
      ERC721MetadataData({ name: "SmartCharacter", symbol: "SC", baseURI: baseURI })
    );

    console.log("Deploying ERC721 token with address: ", address(erc721Token));
    vm.stopBroadcast();
  }
}
