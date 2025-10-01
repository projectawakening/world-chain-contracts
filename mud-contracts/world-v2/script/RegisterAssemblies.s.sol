// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, ResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { eveSystem } from "../src/namespaces/evefrontier/codegen/systems/EveSystemLib.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { IEntitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { EntityRecordSystem, entityRecordSystem } from "../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
/**
 * @notice Register ad-hoc smart assembly classes on an existing World deployment.
 * @dev
 * - Expects environment variables:
 *   - PRIVATE_KEY: EOA private key of the World deployer/owner to broadcast from.
 *   - NEW_ASSEMBLY_TYPE_IDS: Comma-separated list of uint256 type IDs to register.
 *   - NEW_ASSEMBLY_VOLUMES: Comma-separated list of uint256 volumes corresponding to each type ID.
 *     The lengths of NEW_ASSEMBLY_TYPE_IDS and NEW_ASSEMBLY_VOLUMES must match.
 * - For each provided type ID, this script calls `eveSystem.registerSmartAssemblies(typeId, volume)`.
 * - If any provided type ID is already assigned/registered in the World logic, the call will revert and the script will fail.
 * - The script grants `eveSystem` call-access to register classes and create records if it doesn't already exist
 *
 * Usage example:
 *   forge script script/RegisterAssemblies.s.sol:RegisterAssemblies \
 *     --sig "run(address)" $WORLD_ADDRESS \
 *     --broadcast
 */
contract RegisterAssemblies is Script {
  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    uint256[] memory assemblyIds = vm.envUint("NEW_ASSEMBLY_TYPE_IDS", ",");
    uint256[] memory assemblyVolumes = vm.envUint("NEW_ASSEMBLY_VOLUMES", ",");

    require(assemblyIds.length == assemblyVolumes.length, "ids/volumes length mismatch");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    // Grant EveSystem call access if it doesn't already have it
    if (!CallAccess.get(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, eveSystem.getAddress())) {
      CallAccess.set(
        entitySystem.toResourceId(),
        IEntitySystem.scopedRegisterClass.selector,
        eveSystem.getAddress(),
        true
      );
    }
    if (!CallAccess.get(entityRecordSystem.toResourceId(), EntityRecordSystem.createRecord.selector, eveSystem.getAddress())) {
      CallAccess.set(
        entityRecordSystem.toResourceId(),
        EntityRecordSystem.createRecord.selector,
        eveSystem.getAddress(),
        true
      );
    }

    runRegisterAssemblies(assemblyIds, assemblyVolumes);

    vm.stopBroadcast();
  }
}

function runRegisterAssemblies(uint256[] memory assemblyIds, uint256[] memory assemblyVolumes) {
    for (uint i = 0; i < assemblyIds.length; i++) {
      eveSystem.registerSmartAssemblies(assemblyIds[i], assemblyVolumes[i]);
    }
}