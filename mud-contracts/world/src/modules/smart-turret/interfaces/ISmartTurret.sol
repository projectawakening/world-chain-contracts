// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";
import { Target, HPRatio } from "../types.sol";

/**
 * @title ISmartTurret
 * @notice Interface for Smart Turret module
 */
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
    uint256 smartTurretId,
    uint256 characterId,
    Target[] memory validTargetQueue,
    uint256 chargesLeft,
    HPRatio memory hpRatio
  ) external returns (Target[] memory returnTargetQueue);

  function aggression(
    uint256 smartTurretId,
    uint256 aggressorCharacterId,
    uint256 aggressorHpRatio,
    uint256 victimItemId,
    uint256 victimHpRatio,
    Target[] memory validTargetQueue,
    uint256 chargesLeft
  ) external returns (Target[] memory returnTargetQueue);
}
