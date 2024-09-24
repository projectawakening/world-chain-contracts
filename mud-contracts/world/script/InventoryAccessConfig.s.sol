pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/inventory/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { IInventorySystem } from "../src/modules/inventory/interfaces/IInventorySystem.sol";
import { IEphemeralInventorySystem } from "../src/modules/inventory/interfaces/IEphemeralInventorySystem.sol";

contract InventoryAccessConfig is Script {
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
    // InventorySystem
    // Inventory.setInventoryCapacity
    bytes32 invCapacity = keccak256(abi.encodePacked(WORLD_NAMESPACE.inventorySystemId(), IInventorySystem.setInventoryCapacity.selector));
    // Inventory.depositToInventory
    bytes32 invDeposit = keccak256(abi.encodePacked(WORLD_NAMESPACE.inventorySystemId(), IInventorySystem.depositToInventory.selector));
    // Inventory.withdrawalFromInventory
    bytes32 invWithdraw = keccak256(abi.encodePacked(WORLD_NAMESPACE.inventorySystemId(), IInventorySystem.withdrawFromInventory.selector));
    
    // EphemeralInventorySystem
    // EphemeralInventory.setEphemeralInventoryCapacity
    bytes32 ephInvCapacity = keccak256(abi.encodePacked(WORLD_NAMESPACE.inventorySystemId(), IEphemeralInventorySystem.setEphemeralInventoryCapacity.selector));
    // EphemeralInventory.depositToEphemeralInventory
    bytes32 ephInvDeposit = keccak256(abi.encodePacked(WORLD_NAMESPACE.ephemeralInventorySystemId(), IEphemeralInventorySystem.depositToEphemeralInventory.selector));
    // EphemeralInventory.withdrawalFromEphemeralInventory
    bytes32 ephInvWithdraw = keccak256(abi.encodePacked(WORLD_NAMESPACE.ephemeralInventorySystemId(), IEphemeralInventorySystem.withdrawFromEphemeralInventory.selector));
    
    // set enforcement to true for all
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (invCapacity, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (invDeposit, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (invWithdraw, true)));

    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvCapacity, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvDeposit, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvWithdraw, true)));

    vm.stopBroadcast();

  }
}