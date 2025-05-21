// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, ResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { BATCH_CALL_SYSTEM_ID } from "@latticexyz/world/src/modules/init/constants.sol";

import { TagId, TagIdLib } from "../src/libs/TagId.sol";
import { tagSystem } from "../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { EntityTagMap } from "../src/namespaces/evefrontier/codegen/index.sol";

import { TAG_TYPE_RESOURCE_RELATION, TagParams, ResourceRelationValue } from "../src/namespaces/evefrontier/systems/tag-system/types.sol";

/**
 * @notice This script adds the batch call tag to all initial smart assembly classes (specifically for the Nova tenant). 
 * This is a patch for the 0.1.2 deployment of the world that we can use the batch call system in our framework. It is applied by defualt to the 0.1.3 deployment.
 */
contract AddBatchCallToAllClasses is Script {
  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    runAddBatchCallToAllClasses();

    vm.stopBroadcast();
  }
}

function runAddBatchCallToAllClasses() {
  TagId batchCallTagId = TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(BATCH_CALL_SYSTEM_ID)));
  TagParams memory batchCallResourceTag = TagParams(
    batchCallTagId,
    abi.encode(
      ResourceRelationValue("COMPOSITION", RESOURCE_SYSTEM, ResourceIdInstance.getResourceName(BATCH_CALL_SYSTEM_ID))
    )
  );

  bytes32 tenantId = 0xc90e7e9184dce6e0d7fff2e19e72ffa35430aca54bd634ada091bef2d2bb0635;

  // SmartCharacterClass
  uint256 smartCharacterClassId = uint256(keccak256(abi.encodePacked(tenantId, uint256(42000000100))));
  // SmartStorageUnitClass
  uint256 smartStorageUnitClassId = uint256(keccak256(abi.encodePacked(tenantId, uint256(77917))));
  // SmartTurretClass
  uint256 smartTurretClassId = uint256(keccak256(abi.encodePacked(tenantId, uint256(84556))));
  // SmartGateClass
  uint256 smartGateClassId = uint256(keccak256(abi.encodePacked(tenantId, uint256(84955))));

  // Add batch call tag to all classes
  tagSystem.setTag(smartCharacterClassId, batchCallResourceTag);
  tagSystem.setTag(smartStorageUnitClassId, batchCallResourceTag);
  tagSystem.setTag(smartTurretClassId, batchCallResourceTag);
  tagSystem.setTag(smartGateClassId, batchCallResourceTag);

  console.log("SmartCharacterClass has batch call tag: ", EntityTagMap.getHasTag(smartCharacterClassId, batchCallTagId));
  console.log("SmartStorageUnitClass has batch call tag: ", EntityTagMap.getHasTag(smartStorageUnitClassId, batchCallTagId));
  console.log("SmartTurretClass has batch call tag: ", EntityTagMap.getHasTag(smartTurretClassId, batchCallTagId));
  console.log("SmartGateClass has batch call tag: ", EntityTagMap.getHasTag(smartGateClassId, batchCallTagId));
}