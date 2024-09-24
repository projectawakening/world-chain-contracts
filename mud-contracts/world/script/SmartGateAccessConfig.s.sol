pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/smart-gate/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { ISmartGateSystem } from "../src/modules/smart-gate/interfaces/ISmartGateSystem.sol";

contract SmartGateAccessConfig is Script {
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
    // SmartGateSystem
    // SmartGate.configureSmartGate
    bytes32 configure = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartGateSystemId(), ISmartGateSystem.configureSmartGate.selector));
    // SmartGate.linkSmartGates
    bytes32 link = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartGateSystemId(), ISmartGateSystem.linkSmartGates.selector));
    // SmartGate.unlinkSmartGates
    bytes32 unlink = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartGateSystemId(), ISmartGateSystem.unlinkSmartGates.selector));

    // set enforcement to true for all
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (configure, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (link, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (unlink, true)));

    vm.stopBroadcast();

  }
}