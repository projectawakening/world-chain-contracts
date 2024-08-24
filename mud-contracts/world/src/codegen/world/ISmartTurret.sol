// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { EntityRecordData, WorldPosition } from "./../../modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "./../../modules/smart-deployable/types.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { Target } from "./../../modules/smart-turret/types.sol";

/**
 * @title ISmartTurret
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface ISmartTurret {
  error SmartTurret_UndefinedClassId();

  function eveworld__createAndAnchorSmartTurret(
    uint256 smartTurretId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) external;

  function eveworld__configureSmartTurret(uint256 smartTurretId, ResourceId systemId) external;

  function eveworld__inProximity(
    uint256 characterId,
    Target[] memory targetQueue,
    uint256 remainingAmmo,
    uint256 hpRatio
  ) external returns (Target[] memory returnTargetQueue);
}
