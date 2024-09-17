// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";

/**
 * @title ISmartGateSystem
 * @notice Interface for Smart Gate module
 */
interface ISmartGateSystem {
  function createAndAnchorSmartGate(
    uint256 smartGateId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 maxDistance
  ) external;

  function configureSmartGate(uint256 smartGateId, ResourceId systemId) external;

  function linkSmartGates(uint256 sourceGateId, uint256 destinationGateId) external;

  function unlinkSmartGates(uint256 sourceGateId, uint256 destinationGateId) external;

  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) external view returns (bool);

  function isGateLinked(uint256 sourceGateId, uint256 destinationGateId) external view returns (bool);
}
