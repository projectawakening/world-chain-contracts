// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";

import { ERC721Module } from "@eve/eve-erc721-puppet/src/ERC721Module.sol";
import { IERC721Mintable } from "@eve/eve-erc721-puppet/src/IERC721Mintable.sol";
import { registerERC721 } from "@eve/eve-erc721-puppet/src/registerERC721.sol";
import { StaticDataGlobalTableData } from "@eve/static-data/src/codegen/tables/StaticDataGlobalTable.sol";
import { StaticDataModule } from "@eve/static-data/src/StaticDataModule.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, STATIC_DATA_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { SMART_CHARACTER_MODULE_NAME, SMART_CHARACTER_MODULE_NAMESPACE } from "../src/constants.sol";
import { SmartCharacterLib } from "../src/SmartCharacterLib.sol";

contract PostDeploy is Script {
  using SmartCharacterLib for SmartCharacterLib.World;

  function run(address worldAddress) external {
    // TODO: Figure out how to resolved module dependencies, because this just won't work as is
    // StoreSwitch.setStoreAddress(worldAddress);
    // IBaseWorld world = IBaseWorld(worldAddress);

    // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    // string memory baseURI = vm.envString("BASE_URI");

    // vm.startBroadcast(deployerPrivateKey);

    // IERC721Mintable erc721Token;
    // world.installModule(new PuppetModule(), new bytes(0));
    // world.installModule(new StaticDataModule(), abi.encode(STATIC_DATA_DEPLOYMENT_NAMESPACE));
    // erc721Token = registerERC721(
    //   world,
    //   "frontier2",
    //   StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: baseURI })
    // );
    // SmartCharacterLib.World({iface: world, namespace: "frontier"}).registerERC721Token(address(erc721Token));


    // console.log("Deploying ERC721 token with address: ", address(erc721Token));
    // vm.stopBroadcast();
  }
}
