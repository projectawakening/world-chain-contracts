pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/smart-character/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { ISmartCharacterSystem } from "../src/modules/smart-character/interfaces/ISmartCharacterSystem.sol";

contract SmartCharacterAccessConfig is Script {
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
    // SmartCharacterSystem
    // SmartCharacter.createCharacter
    bytes32 create = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartCharacterSystemId(), ISmartCharacterSystem.createCharacter.selector));
    // SmartCharacter.registerERC721Token
    bytes32 register = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartCharacterSystemId(), ISmartCharacterSystem.registerERC721Token.selector));
    // SmartCharacter.setCharClassId
    bytes32 setClass = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartCharacterSystemId(), ISmartCharacterSystem.setCharClassId.selector));
    // SmartCharacter.updateCorpId
    bytes32 updateCorp = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartCharacterSystemId(), ISmartCharacterSystem.updateCorpId.selector));
  
    // set enforcement to true for all
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (create, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (register, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setClass, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (updateCorp, true)));

    vm.stopBroadcast();

  }
}