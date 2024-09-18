// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "../types.sol";

/**
 * @title ISmartTurret
 * @notice Interface for Smart Turret module
 */
interface ISmartTurret {
  function createAndAnchorSmartTurret(
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) external;

  function configureSmartTurret(uint256 smartObjectId, ResourceId systemId) external;

  function inProximity(
    uint256 smartObjectId,
    uint256 turretOwnerCharacterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) external returns (TargetPriority[] memory updatedPriorityQueue);

  function aggression(
    uint256 smartObjectId,
    uint256 turretOwnerCharacterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory aggressor,
    SmartTurretTarget memory victim
  ) external returns (TargetPriority[] memory updatedPriorityQueue);
}
