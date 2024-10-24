// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { SmartGateConfig } from "../../codegen/tables/SmartGateConfig.sol";
import { SmartGateLink, SmartGateLinkData } from "../../codegen/tables/SmartGateLink.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { DeployableUtils } from "../deployable/DeployableUtils.sol";
import { FuelUtils } from "../fuel/FuelUtils.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { WorldPosition } from "../location/types.sol";
import { LocationData, Location } from "../../codegen/tables/Location.sol";
import { SMART_GATE } from "../constants.sol";
import { EveSystem } from "../EveSystem.sol";

contract SmartGateSystem is EveSystem {
  error SmartGate_UndefinedClassId();
  error SmartGate_NotConfigured(uint256 smartObjectId);
  error SmartGate_GateAlreadyLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GateNotLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_NotWithtinRange(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_SameSourceAndDestination(uint256 sourceGateId, uint256 destinationGateId);

  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId fuelSystemId = FuelUtils.fuelSystemId();

  /**
    * @notice Create and anchor a Smart Gate
    * @param smartObjectId is smart object id of the Smart Gate
    * @param entityRecordData is the entity record data of the Smart Gate
    * @param smartObjectData is the metadata of the Smart Gate
    * @param worldPosition is the x,y,z position of the Smart Gate in space
    * @param fuelUnitVolume is the volume of fuel unit
    * @param fuelConsumptionIntervalInSeconds is one unit of fuel consumption interval is consumed in how many seconds
    // For example:
    // OneFuelUnitConsumptionIntervalInSec = 1; // Consuming 1 unit of fuel every second.
    // OneFuelUnitConsumptionIntervalInSec = 60; // Consuming 1 unit of fuel every minute.
    // OneFuelUnitConsumptionIntervalInSec = 3600; // Consuming 1 unit of fuel every hour.
    * @param fuelMaxCapacity is the maximum capacity of fuel
    * @param maxDistance is the maximum distance between two gates
    * TODO: make it accessible only by admin
   */
  function createAndAnchorSmartGate(
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 maxDistance
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
          SMART_GATE,
          entityRecordData,
          smartObjectData,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          locationData
        )
      )
    );

    SmartGateConfig.setMaxDistance(smartObjectId, maxDistance);
  }

  /**
   * @notice Link Smart Gates
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   * //TODO make it configurable only by owner of the smart gate
   */
  function linkSmartGates(uint256 sourceGateId, uint256 destinationGateId) public {
    if (isGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateAlreadyLinked(sourceGateId, destinationGateId);
    }

    if (sourceGateId == destinationGateId) {
      revert SmartGate_SameSourceAndDestination(sourceGateId, destinationGateId);
    }

    //TODO: Check if the state is online for both the gates ??
    if (isWithinRange(sourceGateId, destinationGateId) == false) {
      revert SmartGate_NotWithtinRange(sourceGateId, destinationGateId);
    }

    //Create a 2 way link between the gates
    SmartGateLink.set(sourceGateId, destinationGateId, true);
    SmartGateLink.set(destinationGateId, sourceGateId, true);
  }

  /**
   * @notice Unlink Smart Gates
   * @param sourceGateId is the id of the source gate
   * @param destinationGateId is the id of the destination gate
   * //TODO make it configurable only by owner of the smart gate
   */
  function unlinkSmartGates(uint256 sourceGateId, uint256 destinationGateId) public {
    //Check if the gates are linked
    if (!isGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateNotLinked(sourceGateId, destinationGateId);
    }
    SmartGateLink.set(sourceGateId, destinationGateId, false);
    SmartGateLink.set(destinationGateId, sourceGateId, false);
  }

  /**
   * @notice Configure Smart Gate
   * @param smartObjectId is smartObjectId of the Smart Gate
   * @param systemId is the system id of the Smart Gate logic
   */
  function configureSmartGate(uint256 smartObjectId, ResourceId systemId) public {
    SmartGateConfig.setSystemId(smartObjectId, systemId);
  }

  /**
   * @notice view function for smart gates which is linked
   * @param characterId is of the smartObjectId of the character
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   */
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public returns (bool) {
    State sourceGateState = DeployableState.getCurrentState(sourceGateId);

    State destinationGateState = DeployableState.getCurrentState(destinationGateId);

    if (sourceGateState != State.ONLINE) {
      revert DeployableSystem.Deployable_IncorrectState(sourceGateId, sourceGateState);
    }

    if (destinationGateState != State.ONLINE) {
      revert DeployableSystem.Deployable_IncorrectState(destinationGateId, destinationGateState);
    }

    //Check if the gates are linked
    if (!isGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateNotLinked(sourceGateId, destinationGateId);
    }

    ResourceId systemId = SmartGateConfig.getSystemId(sourceGateId);

    if (ResourceIds.getExists(systemId)) {
      bytes memory returnData = world().call(
        systemId,
        abi.encodeCall(this.canJump, (characterId, sourceGateId, destinationGateId))
      );
      return abi.decode(returnData, (bool));
    }
    return true;
  }

  function isGateLinked(uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    SmartGateLinkData memory smartGateLinkData = SmartGateLink.get(sourceGateId);
    bool isLinked = smartGateLinkData.isLinked && smartGateLinkData.destinationGateId == destinationGateId;

    return isLinked;
  }

  function isWithinRange(uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    //Get the location of the source gate and destination gate
    LocationData memory sourceGateLocation = Location.get(sourceGateId);
    LocationData memory destGateLocation = Location.get(destinationGateId);
    uint256 maxDistance = SmartGateConfig.getMaxDistance(sourceGateId);

    // Implement the logic to calculate the distance between two gates
    // Calculate squared differences
    uint256 dx = sourceGateLocation.x > destGateLocation.x
      ? sourceGateLocation.x - destGateLocation.x
      : destGateLocation.x - sourceGateLocation.x;
    uint256 dy = sourceGateLocation.y > destGateLocation.y
      ? sourceGateLocation.y - destGateLocation.y
      : destGateLocation.y - sourceGateLocation.y;
    uint256 dz = sourceGateLocation.z > destGateLocation.z
      ? sourceGateLocation.z - destGateLocation.z
      : destGateLocation.z - sourceGateLocation.z;

    // Sum of squares (distance squared in meters)
    uint256 distanceSquaredMeters = (dx * dx) + (dy * dy) + (dz * dz);
    return distanceSquaredMeters <= (maxDistance * maxDistance);
  }
}
