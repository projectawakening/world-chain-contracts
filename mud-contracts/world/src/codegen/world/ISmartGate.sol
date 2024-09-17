// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { EntityRecordData, WorldPosition } from "./../../modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "./../../modules/smart-deployable/types.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

/**
 * @title ISmartGate
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface ISmartGate {
  error SmartGate_UndefinedClassId();
  error SmartGate_NotConfigured(uint256 smartGateId);
  error SmartGate_GateAlreadyLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GateNotLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_NotWithtinRange(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_SameSourceAndDestination(uint256 sourceGateId, uint256 destinationGateId);

  function eveworld__createAndAnchorSmartGate(
    uint256 smartGateId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 maxDistance
  ) external;

  function eveworld__linkSmartGates(uint256 sourceGateId, uint256 destinationGateId) external;

  function eveworld__unlinkSmartGates(uint256 sourceGateId, uint256 destinationGateId) external;

  function eveworld__configureSmartGate(uint256 smartGateId, ResourceId systemId) external;

  function eveworld__canJump(
    uint256 characterId,
    uint256 sourceGateId,
    uint256 destinationGateId
  ) external returns (bool);

  function eveworld__isGateLinked(uint256 sourceGateId, uint256 destinationGateId) external view returns (bool);

  function eveworld__isWithinRange(uint256 sourceGateId, uint256 destinationGateId) external view returns (bool);
}
