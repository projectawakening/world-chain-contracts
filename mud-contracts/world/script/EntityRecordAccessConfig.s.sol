pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/entity-record/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { IEntityRecordSystem } from "../src/modules/entity-record/interfaces/IEntityRecordSystem.sol";

contract EntityRecordAccessConfig is Script {
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
    // EntityRecordSystem
    // EntityRecord.createEntityRecord
    bytes32 create = keccak256(abi.encodePacked(WORLD_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.createEntityRecord.selector));
    // EntityRecord.createEntityRecordOffchain
    bytes32 createOffChain = keccak256(abi.encodePacked(WORLD_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.createEntityRecordOffchain.selector));
    // EntityRecord.setEntityMetadata
    bytes32 setMetadata = keccak256(abi.encodePacked(WORLD_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.setEntityMetadata.selector));
    // EntityRecord.setName
    bytes32 setName = keccak256(abi.encodePacked(WORLD_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.setName.selector));
    // EntityRecord.setDappURL
    bytes32 setDappURL = keccak256(abi.encodePacked(WORLD_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.setDappURL.selector));
    // EntityRecord.setDescription
    bytes32 setDescription = keccak256(abi.encodePacked(WORLD_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.setDescription.selector));

    // set enforcement to true for all
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (create, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (createOffChain, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setMetadata, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setName, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setDappURL, true)));
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setDescription, true)));

    vm.stopBroadcast();

  }
}