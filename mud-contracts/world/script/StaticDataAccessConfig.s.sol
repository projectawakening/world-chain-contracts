pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/static-data/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { IStaticDataSystem } from "../src/modules/static-data/interfaces/IStaticDataSystem.sol";

contract StaticDataAccessConfig is Script {
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
    // StaticDataSystem
    // StaticData.setBaseURI
    bytes32 baseURI = keccak256(abi.encodePacked(WORLD_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setBaseURI.selector));
    // StaticData.setName
    bytes32 name = keccak256(abi.encodePacked(WORLD_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setName.selector));
    // StaticData.setSymbol
    bytes32 symbol = keccak256(abi.encodePacked(WORLD_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setSymbol.selector));
    // StaticData.setMetadata
    bytes32 metadata = keccak256(abi.encodePacked(WORLD_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setMetadata.selector));
    // StaticData.setCid
    bytes32 cid = keccak256(abi.encodePacked(WORLD_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setCid.selector));
    
    // set enforcement to true for all
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (baseURI, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (name, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (symbol, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (metadata, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (cid, true)));

    vm.stopBroadcast();

  }
}