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
import { SmartGateConfig } from "../../codegen/tables/SmartGateConfig.sol";
import { SmartGateLink, SmartGateLinkData } from "../../codegen/tables/SmartGateLink.sol";
import { DeployableState } from "../../codegen/index.sol";
import { LocationData, Location } from "../../codegen/tables/Location.sol";

// Local namespace systems
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { DeployableSystemLib, deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";

// Types and parameters
import { State, CreateAndAnchorParams } from "../deployable/types.sol";
import { SMART_GATE } from "../constants.sol";

contract SmartGateSystem is SmartObjectFramework {
  error SmartGate_UndefinedClassId();
  error SmartGate_NotConfigured(uint256 smartObjectId);
  error SmartGate_GateAlreadyLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GateNotLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_NotWithtinRange(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_SameSourceAndDestination(uint256 sourceGateId, uint256 destinationGateId);

  /**
   * @notice Create and anchor a Smart Gate
   * @param params CreateAndAnchorDeployableParams
   * @param maxDistance is the maximum distance between two gates
   */
  function createAndAnchorGate(
    CreateAndAnchorParams memory params,
    uint256 maxDistance
  ) public context access(params.smartObjectId) scope(getSmartGateClassId()) {
    params.assemblyType = SMART_GATE;

    entitySystem.instantiate(getSmartGateClassId(), params.smartObjectId, params.owner);

    deployableSystem.createAndAnchor(params);

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
   */
  function unlinkGates(
    uint256 sourceGateId,
    uint256 destinationGateId
  ) public context access(sourceGateId) scope(sourceGateId) {
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
  function configureGate(
    uint256 smartObjectId,
    ResourceId systemId
  ) public context access(smartObjectId) scope(smartObjectId) {
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
      bytes memory returnData = getWorld().call(
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

  function getSmartGateClassId() public view returns (uint256) {
    return uint256(bytes32("SMART_GATE"));
  }

  function getWorld() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }
}
