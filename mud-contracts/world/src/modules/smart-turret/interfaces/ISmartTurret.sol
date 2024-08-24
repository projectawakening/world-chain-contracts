// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";
import { Target } from "../types.sol";

interface ISmartTurret {
  function createAndAnchorSmartTurret(
    uint256 smartTurretId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) external;

  function configureSmartTurret(uint256 smartTurretId, ResourceId systemId) external;

  function inProximity(
    uint256 characterId,
    uint256 queue,
    uint256 remainingAmmo,
    uint256 hpRatio
  ) external returns (Target[] memory targetQueue);
}
