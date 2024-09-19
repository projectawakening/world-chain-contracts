// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { Utils as SmartObjectFrameworkUtils } from "@eveworld/smart-object-framework/src/utils.sol";
import { EntityTable } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE, OBJECT } from "@eveworld/common-constants/src/constants.sol";

import { SmartGateConfigTable } from "../../../codegen/tables/SmartGateConfigTable.sol";
import { GlobalDeployableState } from "../../../codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { LocationTableData, LocationTable } from "../../../codegen/tables/LocationTable.sol";
import { ClassConfig } from "../../../codegen/tables/ClassConfig.sol";
import { SmartGateLinkTable, SmartGateLinkTableData } from "../../../codegen/tables/SmartGateLinkTable.sol";
import { State, SmartAssemblyType } from "../../../codegen/common.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";

import { SmartDeployableErrors } from "../../smart-deployable/SmartDeployableErrors.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as LocationUtils } from "../../location/Utils.sol";
import { AccessModified } from "../../access/systems/AccessModified.sol";

import { Utils } from "../Utils.sol";

/**
 * @title SmartGate
 * @notice Smart Gate module
 */
contract SmartGate is EveSystem, AccessModified {
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartObjectFrameworkUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using LocationUtils for bytes14;
  using Utils for bytes14;

  error SmartGate_UndefinedClassId();
  error SmartGate_NotConfigured(uint256 smartObjectId);
  error SmartGate_GateAlreadyLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_GateNotLinked(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_NotWithtinRange(uint256 sourceGateId, uint256 destinationGateId);
  error SmartGate_SameSourceAndDestination(uint256 sourceGateId, uint256 destinationGateId);

  /**
   * modifier to enforce state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused(_namespace().globalStateTableId()) == false) {
      revert SmartDeployableErrors.SmartDeployable_StateTransitionPaused();
    }
    _;
  }

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
  ) public onlyAdmin {
    //Implement the logic to store the data in different modules: EntityRecord, Deployable, Location and ERC721
    _entityRecordLib().createEntityRecord(
      smartObjectId,
      entityRecordData.itemId,
      entityRecordData.typeId,
      entityRecordData.volume
    );

    _smartDeployableLib().registerDeployable(
      smartObjectId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );
    _smartDeployableLib().setSmartAssemblyType(smartObjectId, SmartAssemblyType.SMART_GATE);

    LocationTableData memory locationData = LocationTableData({
      solarSystemId: worldPosition.solarSystemId,
      x: worldPosition.position.x,
      y: worldPosition.position.y,
      z: worldPosition.position.z
    });
    _smartDeployableLib().anchor(smartObjectId, locationData);

    SmartGateConfigTable.setMaxDistance(_namespace().smartGateConfigTableId(), smartObjectId, maxDistance);
  }

  /**
   * @notice Link Smart Gates
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
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
    SmartGateLinkTable.set(_namespace().smartGateLinkTableId(), sourceGateId, destinationGateId, true);
    SmartGateLinkTable.set(_namespace().smartGateLinkTableId(), destinationGateId, sourceGateId, true);
  }

  /**
   * @notice Unlink Smart Gates
   * @param sourceGateId is the id of the source gate
   * @param destinationGateId is the id of the destination gate
   */
  function unlinkSmartGates(uint256 sourceGateId, uint256 destinationGateId) public {
    //Check if the gates are linked
    if (!isGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateNotLinked(sourceGateId, destinationGateId);
    }
    SmartGateLinkTable.set(_namespace().smartGateLinkTableId(), sourceGateId, destinationGateId, false);
  }

  /**
   * @notice Configure Smart Gate
   * @param smartObjectId is smartObjectId of the Smart Gate
   * @param systemId is the system id of the Smart Gate logic
   */
  function configureSmartGate(
    uint256 smartObjectId,
    ResourceId systemId
  ) public onlyAdminOrObjectOwner(smartObjectId) hookable(smartObjectId, _systemId()) {
    SmartGateConfigTable.setSystemId(_namespace().smartGateConfigTableId(), smartObjectId, systemId);
  }

  /**
   * @notice view function for smart gates which is linked
   * @param characterId is of the smartObjectId of the character
   * @param sourceGateId is the smartObjectId of the source gate
   * @param destinationGateId is the smartObjectId of the destination gate
   */
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public returns (bool) {
    State sourceGateState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), sourceGateId);

    State destinationGateState = DeployableState.getCurrentState(
      _namespace().deployableStateTableId(),
      destinationGateId
    );

    if (sourceGateState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(sourceGateId, sourceGateState);
    }

    if (destinationGateState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(destinationGateId, destinationGateState);
    }

    //Check if the gates are linked
    if (!isGateLinked(sourceGateId, destinationGateId)) {
      revert SmartGate_GateNotLinked(sourceGateId, destinationGateId);
    }

    ResourceId systemId = SmartGateConfigTable.getSystemId(_namespace().smartGateConfigTableId(), sourceGateId);

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
    SmartGateLinkTableData memory smartGateLinkTableData = SmartGateLinkTable.get(
      _namespace().smartGateLinkTableId(),
      sourceGateId
    );
    bool isLinked = smartGateLinkTableData.isLinked && smartGateLinkTableData.destinationGateId == destinationGateId;

    return isLinked;
  }

  function isWithinRange(uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    //Get the location of the source gate and destination gate
    LocationTableData memory sourceGateLocation = LocationTable.get(_namespace().locationTableId(), sourceGateId);
    LocationTableData memory destGateLocation = LocationTable.get(_namespace().locationTableId(), destinationGateId);
    uint256 maxDistance = SmartGateConfigTable.getMaxDistance(_namespace().smartGateConfigTableId(), sourceGateId);

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

  function _entityRecordLib() internal view returns (EntityRecordLib.World memory) {
    return EntityRecordLib.World({ iface: IBaseWorld(_world()), namespace: ENTITY_RECORD_DEPLOYMENT_NAMESPACE });
  }

  function _smartDeployableLib() internal view returns (SmartDeployableLib.World memory) {
    return SmartDeployableLib.World({ iface: IBaseWorld(_world()), namespace: SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE });
  }

  function _smartObjectLib() internal view returns (SmartObjectLib.World memory) {
    return SmartObjectLib.World({ iface: IBaseWorld(_world()), namespace: SMART_OBJECT_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartGateSystemId();
  }
}
