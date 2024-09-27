pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/eve-erc721-puppet/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { IERC721Mintable } from "../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IERC721 } from "../src/modules/eve-erc721-puppet/IERC721.sol";

contract ERC721PuppetAccessConfig is Script {
  using AccessUtils for bytes14;
  using Utils for bytes14;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    IBaseWorld world = IBaseWorld(worldAddress);

    // target functions to set access control enforcement for
    // ERC721System
    // ERC721System.transferFrom
    bytes32 transferFrom = keccak256(abi.encodePacked(WORLD_NAMESPACE.erc721SystemId(), IERC721.transferFrom.selector));
    // ERC721System.mint
    bytes32 mint = keccak256(abi.encodePacked(WORLD_NAMESPACE.erc721SystemId(), IERC721Mintable.mint.selector));
    // ERC721System.safeMint 1
    bytes32 safeMint1 = keccak256(abi.encodePacked(WORLD_NAMESPACE.erc721SystemId(), bytes4(keccak256("safeMint(address,uint256)"))));
    // ERC721System.safeMint 2
    bytes32 safeMint2 = keccak256(abi.encodePacked(WORLD_NAMESPACE.erc721SystemId(), bytes4(keccak256("safeMint(address,uint256,bytes)"))));
    // ERC721System.burn
    bytes32 burn = keccak256(abi.encodePacked(WORLD_NAMESPACE.erc721SystemId(), IERC721Mintable.burn.selector));
    // ERC721System.setCid
    bytes32 setCid = keccak256(abi.encodePacked(WORLD_NAMESPACE.erc721SystemId(), IERC721Mintable.setCid.selector));

    // set enforcement to true for all
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (transferFrom, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (mint, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (safeMint1, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (safeMint2, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (burn, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setCid, true)));

    vm.stopBroadcast();
    
  }
}