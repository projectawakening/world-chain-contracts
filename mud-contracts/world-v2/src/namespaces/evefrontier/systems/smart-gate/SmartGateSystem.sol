// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Tenant, SmartGateConfig, SmartGateLink, SmartGateLinkData, DeployableState, Location, LocationData, Initialize } from "../../codegen/index.sol";

// Local namespace systems
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { smartGateSystem } from "../../codegen/systems/SmartGateSystemLib.sol";

// Types and parameters
import { State, CreateAndAnchorParams } from "../deployable/types.sol";
import { SMART_GATE } from "../constants.sol";
import { ObjectIdLib } from "../../libraries/ObjectIdLib.sol";

contract SmartGateSystem is SmartObjectFramework {
  error SmartGate_UndefinedClassId();
  error SmartGate_NotConfigured(uint256 smartObjectId);
  error SmartGate_GateAlreadyLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GateNotLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_NotWithtinRange(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_SameSourceAndDestination(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GatesNotOnline(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GateNotOnline(uint256 smartObjectId);

  /**
   * @notice Create and anchor a Smart Gate
   * @param params CreateAndAnchorDeployableParams
   * @param maxDistance is the maximum distance between two gates
   * @param networkNodeId is the id of the network node this gate is connected to
   */
  function createAndAnchorGate(
    CreateAndAnchorParams memory params,
    uint256 maxDistance,
    uint256 networkNodeId
  ) public context access(params.smartObjectId) {
    params.assemblyType = SMART_GATE;

    deployableSystem.createAndAnchor(params, networkNodeId);

    SmartGateConfig.setMaxDistance(params.smartObjectId, maxDistance);
  }

  /**
   * @notice Link Smart Gates
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   */
  function linkGates(
    uint256 sourceGateId,
    uint256 destinationGateId
  ) public context access(sourceGateId) scope(sourceGateId) {
    State sourceGateState = DeployableState.getCurrentState(sourceGateId);

    if (sourceGateState == State.NULL || sourceGateState == State.DESTROYED) {
      revert DeployableSystem.Deployable_IncorrectState(sourceGateId, sourceGateState);
    }

    State destinationGateState = DeployableState.getCurrentState(destinationGateId);

    if (destinationGateState == State.NULL || destinationGateState == State.DESTROYED) {
      revert DeployableSystem.Deployable_IncorrectState(destinationGateId, destinationGateState);
    }

    if (isAnyGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateAlreadyLinked(sourceGateId, destinationGateId);
    }

    if (sourceGateId == destinationGateId) {
      revert SmartGate_SameSourceAndDestination(sourceGateId, destinationGateId);
    }

    if (isWithinRange(sourceGateId, destinationGateId) == false) {
      revert SmartGate_NotWithtinRange(sourceGateId, destinationGateId);
    }

    // Delete the existing records for the source and destination gate before creating a new link to avoid replacing the record
    // The invalid records are not deleted during unlink because the external services are subscribed to the unlink events. If the record is deleted then the external services will not be able to notify the game
    _deleteExistingLink(sourceGateId);
    _deleteExistingLink(destinationGateId);

    // Create a 2 way link between the gates
    SmartGateLink.set(sourceGateId, destinationGateId, true);
    SmartGateLink.set(destinationGateId, sourceGateId, true);
  }

  /**
   * @notice Unlink Smart Gates
   * @param sourceGateId is the id of the source gate
   * @param destinationGateId is the id of the destination gate
   */
  function unlinkGates(
    uint256 sourceGateId,
    uint256 destinationGateId
  ) public context access(sourceGateId) scope(sourceGateId) {
    // Check if the gates are linked
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
  function configureGate(
    uint256 smartObjectId,
    ResourceId systemId
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (DeployableState.getCurrentState(smartObjectId) == State.NULL) {
      revert DeployableSystem.Deployable_IncorrectState(smartObjectId, State.NULL);
    }
    SmartGateConfig.setSystemId(smartObjectId, systemId);
  }

  /**
   * @notice view function for smart gates which is linked
   * @param characterId is of the smartObjectId of the character
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   */
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public returns (bool) {
    //Check if the gates are online
    if (
      DeployableState.getCurrentState(sourceGateId) != State.ONLINE &&
      DeployableState.getCurrentState(destinationGateId) != State.ONLINE
    ) {
      revert SmartGate_GatesNotOnline(sourceGateId, destinationGateId);
    } else if (DeployableState.getCurrentState(sourceGateId) != State.ONLINE) {
      revert SmartGate_GateNotOnline(sourceGateId);
    } else if (DeployableState.getCurrentState(destinationGateId) != State.ONLINE) {
      revert SmartGate_GateNotOnline(destinationGateId);
    }

    //Check if the gates are linked
    if (!isGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateNotLinked(sourceGateId, destinationGateId);
    }

    ResourceId systemId = SmartGateConfig.getSystemId(sourceGateId);

    if (ResourceIds.getExists(systemId)) {
      bytes memory returnData = getWorld().call(
        systemId,
        abi.encodeCall(this.canJump, (characterId, sourceGateId, destinationGateId))
      );
      return abi.decode(returnData, (bool));
    }
    return true;
  }

  /**
   * @notice view function to check if the gates are online
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   * @return true if the gates are online
   */
  function areGatesOnline(uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    State sourceGateState = DeployableState.getCurrentState(sourceGateId);
    State destinationGateState = DeployableState.getCurrentState(destinationGateId);

    return sourceGateState == State.ONLINE && destinationGateState == State.ONLINE;
  }

  /**
   * @notice view function to check if the source gate is linked to the destination gate
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   * @return true if the source gate is linked to the destination gate
   */
  function isGateLinked(uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return
      SmartGateLink.getIsLinked(sourceGateId) && SmartGateLink.getDestinationGateId(sourceGateId) == destinationGateId;
  }

  /**
   * @notice view function to check if any gate is linked previously
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   * @return true if any gate is linked previously
   */
  function isAnyGateLinked(uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return (SmartGateLink.getIsLinked(sourceGateId) || SmartGateLink.getIsLinked(destinationGateId));
  }

  /**
   * @notice view function to check if the source gate is within the range of the destination gate
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   * @return true if the source gate is within the range of the destination gate
   */
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

  function getWorld() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }

  /**
   * @notice delete the existing record if there exists a link for either source or destination gates
   * @param sourceGateId is the smartObjectId of the source gate
   */
  function _deleteExistingLink(uint256 sourceGateId) internal {
    uint256 destinationGateId;
    //delete the source gate record
    SmartGateLinkData memory linkData = SmartGateLink.get(sourceGateId);
    if (linkData.isLinked) {
      destinationGateId = linkData.destinationGateId;

      SmartGateLink.deleteRecord(sourceGateId);
      SmartGateLink.deleteRecord(destinationGateId);
    }
  }
}
