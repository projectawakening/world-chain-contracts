// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Tenant } from "../src/namespaces/evefrontier/codegen/index.sol";

import { FuelSystem, fuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { ObjectIdLib } from "../src/namespaces/evefrontier/libraries/ObjectIdLib.sol";
import { EntityRecordParams } from "../src/namespaces/evefrontier/systems/entity-record/types.sol";

contract ConfigureFuel is Script {
  error ArrayLengthMismatch(uint256 fuelTypeIdsLength, uint256 fuelEfficienciesLength, uint256 fuelVolumesLength);
  error EmptyArray();

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Read comma-separated list of fuel smart object ids from environment variable
    uint256[] memory fuelTypeIds = vm.envUint("FUEL_TYPE_ID", ",");
    uint256[] memory fuelEfficiencies = vm.envUint("FUEL_EFFICIENCY", ",");
    uint256[] memory fuelVolumes = vm.envUint("FUEL_VOLUME", ",");

    // Validate array lengths
    if (fuelTypeIds.length == 0 || fuelEfficiencies.length == 0 || fuelVolumes.length == 0) {
      revert EmptyArray();
    }

    if (fuelTypeIds.length != fuelEfficiencies.length || fuelTypeIds.length != fuelVolumes.length) {
      revert ArrayLengthMismatch(fuelTypeIds.length, fuelEfficiencies.length, fuelVolumes.length);
    }

    bytes32 tenantId = Tenant.get();

    for (uint256 i = 0; i < fuelTypeIds.length; i++) {
      uint256 fuelSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, fuelTypeIds[i]);

      EntityRecordParams memory fuelEntityRecordParams = EntityRecordParams({
        tenantId: tenantId,
        typeId: fuelTypeIds[i],
        itemId: 0,
        volume: fuelVolumes[i] * (10 ** 16) // Convert to fixed-point representation by 2 decimal places as the volume is 0.28
      });

      vm.startBroadcast(deployerPrivateKey);

      fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, fuelEfficiencies[i]);

      vm.stopBroadcast();
    }
  }
}
