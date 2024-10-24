// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { Location, LocationData } from "../../codegen/index.sol";
import { InventorySystem } from "../inventory/InventorySystem.sol";
import { EphemeralInventorySystem } from "../inventory/EphemeralInventorySystem.sol";
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { DeployableUtils } from "../deployable/DeployableUtils.sol";
import { FuelUtils } from "../fuel/FuelUtils.sol";
import { InventoryUtils } from "../inventory/InventoryUtils.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { WorldPosition } from "../location/types.sol";
import { SMART_STORAGE_UNIT } from "../constants.sol";
import { EveSystem } from "../EveSystem.sol";

contract SmartStorageUnitSystem is EveSystem {
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
  ResourceId fuelSystemId = FuelUtils.fuelSystemId();

  function createAndAnchorSmartStorageUnit(
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    LocationData memory locationData = LocationData({
      solarSystemId: worldPosition.solarSystemId,
      x: worldPosition.position.x,
      y: worldPosition.position.y,
      z: worldPosition.position.z
    });
    world().call(
      deployableSystemId,
      abi.encodeCall(
        DeployableSystem.createAndAnchorDeployable,
        (
          smartObjectId,
          SMART_STORAGE_UNIT,
          entityRecordData,
          smartObjectData,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          locationData
        )
      )
    );

    world().call(
      inventorySystemId,
      abi.encodeCall(InventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );

    world().call(
      ephemeralInventorySystemId,
      abi.encodeCall(EphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, ephemeralStorageCapacity))
    );
  }
}
