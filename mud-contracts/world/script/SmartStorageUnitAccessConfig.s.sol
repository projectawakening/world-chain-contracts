pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/smart-storage-unit/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { ISmartStorageUnitSystem } from "../src/modules/smart-storage-unit/interfaces/ISmartStorageUnitSystem.sol";

contract SmartStorageUnitAccessConfig is Script {
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
    // SmartStorageUnitSystem
    // SmartStorageUnit.createAndAnchorSmartStorageUnit
    bytes32 createAndAnchor = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartStorageUnitSystemId(), ISmartStorageUnitSystem.createAndAnchorSmartStorageUnit.selector));
    // SmartStorageUnit.createAndDepositItemsToInventory
    bytes32 invCreateAndDeposit = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartStorageUnitSystemId(), ISmartStorageUnitSystem.createAndDepositItemsToInventory.selector));
    // SmartStorageUnit.createAndDepositItemsToEphemeralInventory
    bytes32 ephInvCreateAndDeposit = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartStorageUnitSystemId(), ISmartStorageUnitSystem.createAndDepositItemsToEphemeralInventory.selector));
    // SmartStorageUnit.setDeployableMetadata
    bytes32 setDeployableMetadata = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartStorageUnitSystemId(), ISmartStorageUnitSystem.setDeployableMetadata.selector));
    // SmartStorageUnit.setSSUClassId
    bytes32 setClass = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartStorageUnitSystemId(), ISmartStorageUnitSystem.setSSUClassId.selector));

    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (createAndAnchor, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (invCreateAndDeposit, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvCreateAndDeposit, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setDeployableMetadata, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setClass, true)));

    vm.stopBroadcast();

  }
}