// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";

import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { IERC20Mintable } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import { ERC20Module } from "@latticexyz/world-modules/src/modules/erc20-puppet/ERC20Module.sol";
import { registerERC20 } from "@latticexyz/world-modules/src/modules/erc20-puppet/registerERC20.sol";
import { ERC20MetadataData } from "@latticexyz/world-modules/src/modules/erc20-puppet/tables/ERC20Metadata.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { ISmartCharacterSystem } from "../src/codegen/world/ISmartCharacterSystem.sol";
import { ERC721MetadataData } from "../src/codegen/tables/ERC721Metadata.sol";
import { SmartCharacterSystem } from "../src/systems/smart-character/SmartCharacterSystem.sol";
import { registerERC721 } from "../src/systems/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../src/systems/eve-erc721-puppet/IERC721Mintable.sol";
import { StaticDataSystem } from "../src/systems/static-data/StaticDataSystem.sol";
import { SmartDeployableSystem } from "../src/systems/smart-deployable/SmartDeployableSystem.sol";

import { SmartCharacterUtils } from "../src/systems/smart-character/SmartCharacterUtils.sol";
import { SmartDeployableUtils } from "../src/systems/smart-deployable/SmartDeployableUtils.sol";
import { StaticDataUtils } from "../src/systems/static-data/StaticDataUtils.sol";

import { DEPLOYMENT_NAMESPACE } from "../src/systems/constants.sol";

contract PostDeploy is Script {
  using SmartCharacterUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using StaticDataUtils for bytes14;

  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);

    // Private Key loaded from environment
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    StoreSwitch.setStoreAddress(address(world));

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    _installPuppet(world, deployer);

    // register new ERC20 EVE Token
    _createEVEToken(world);

    // register new ERC721 puppets for SmartCharacter and SmartDeployable modules
    _createCharacterToken(world);

    _createDeployableToken(world);

    vm.stopBroadcast();
  }

  function _installPuppet(IBaseWorld world, address deployer) internal {
    StoreSwitch.setStoreAddress(address(world));
    // creating all module contracts
    PuppetModule puppetModule = new PuppetModule();
    // puppetModule is conventionally installed as such
    world.installModule(puppetModule, new bytes(0));
  }

  function _createEVEToken(IBaseWorld world) internal {
    string memory namespace = vm.envString("EVE_TOKEN_NAMESPACE");
    string memory name = vm.envString("ERC20_TOKEN_NAME");
    string memory symbol = vm.envString("ERC20_TOKEN_SYMBOL");

    uint8 decimals = uint8(18);
    uint256 amount = vm.envUint("ERC20_INITIAL_SUPPLY");
    address to = vm.envAddress("EVE_TOKEN_ADMIN");

    // ERC20 TOKEN DEPLOYMENT
    IERC20Mintable erc20Token;
    erc20Token = registerERC20(
      world,
      stringToBytes14(namespace),
      ERC20MetadataData({ decimals: decimals, name: name, symbol: symbol })
    );

    console.log("Deploying ERC20 token with address: ", address(erc20Token));

    address erc20Address = address(erc20Token);

    IERC20Mintable erc20 = IERC20Mintable(erc20Address);
    erc20.mint(to, amount * 1 ether);

    console.log("minting to: ", address(to));
    console.log("amount: ", amount * 1 ether);
  }

  function _createCharacterToken(IBaseWorld world) internal {
    string memory baseURI = vm.envString("BASE_URI");

    // SmartCharacter
    IERC721Mintable erc721SmartCharacter = registerERC721(
      world,
      "erc721charactr",
      ERC721MetadataData({ name: "SmartCharacter", symbol: "SC", baseURI: baseURI })
    );

    console.log("Deploying Smart Character token with address: ", address(erc721SmartCharacter));

    ResourceId staticDataSystemId = StaticDataUtils.staticDataSystemId();
    world.call(staticDataSystemId, abi.encodeCall(StaticDataSystem.setBaseURI, (baseURI)));

    // regiseter token address for smart character
    ResourceId smartCharacterSystemId = SmartCharacterUtils.smartCharacterSystemId();
    world.call(
      smartCharacterSystemId,
      abi.encodeCall(SmartCharacterSystem.registerCharacterToken, (address(erc721SmartCharacter)))
    );
  }

  function _createDeployableToken(IBaseWorld world) internal {
    string memory baseURI = vm.envString("BASE_URI");

    // SmartDeployable
    IERC721Mintable erc721SmartDeployableToken = registerERC721(
      world,
      "erc721deploybl",
      ERC721MetadataData({ name: "SmartDeployable", symbol: "SD", baseURI: baseURI })
    );

    console.log("Deploying Smart Deployable token with address: ", address(erc721SmartDeployableToken));
    ResourceId staticDataSystemId = StaticDataUtils.staticDataSystemId();
    world.call(staticDataSystemId, abi.encodeCall(StaticDataSystem.setBaseURI, (baseURI)));

    // register token address for smart deployable
    ResourceId smartDeployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(
      smartDeployableSystemId,
      abi.encodeCall(SmartDeployableSystem.registerDeployableToken, (address(erc721SmartDeployableToken)))
    );
  }

  function stringToBytes14(string memory str) public pure returns (bytes14) {
    bytes memory tempBytes = bytes(str);

    // Ensure the bytes array is not longer than 14 bytes.
    // If it is, this will truncate the array to the first 14 bytes.
    // If it's shorter, it will be padded with zeros.
    require(tempBytes.length <= 14, "String too long");

    bytes14 converted;
    for (uint i = 0; i < tempBytes.length; i++) {
      converted |= bytes14(tempBytes[i] & 0xFF) >> (i * 8);
    }

    return converted;
  }
}
