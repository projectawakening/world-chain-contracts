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

import { SmartTurretConfigTable } from "../../../codegen/tables/SmartTurretConfigTable.sol";
import { GlobalDeployableState } from "../../../codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { ClassConfig } from "../../../codegen/tables/ClassConfig.sol";
import { State, SmartAssemblyType } from "../../../codegen/common.sol";
import { CharactersTable } from "../../../codegen/tables/CharactersTable.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";

import { SmartDeployableErrors } from "../../smart-deployable/SmartDeployableErrors.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as SmartCharacterUtils } from "../../smart-character/Utils.sol";
import { AccessModified } from "../../access/systems/AccessModified.sol";

import { Utils } from "../Utils.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "../types.sol";

/**
 * @title SmartTurret
 * @notice Smart Turret module
 */
contract SmartTurret is EveSystem, AccessModified {
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartObjectFrameworkUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using Utils for bytes14;

  error SmartTurret_UndefinedClassId();
  error SmartTurret_NotConfigured(uint256 smartTurretId);

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
    * @notice Create and anchor a Smart Turret
    * @param smartTurretId is smart object id of the Smart Turret
    * @param entityRecordData is the entity record data of the Smart Turret
    * @param smartObjectData is the metadata of the Smart Turret
    * @param worldPosition is the x,y,z position of the Smart Turret in space
    * @param fuelUnitVolume is the volume of fuel unit
    * @param fuelConsumptionIntervalInSeconds is one unit of fuel consumption interval is consumed in how many seconds
    // For example:
    // OneFuelUnitConsumptionIntervalInSec = 1; // Consuming 1 unit of fuel every second.
    // OneFuelUnitConsumptionIntervalInSec = 60; // Consuming 1 unit of fuel every minute.
    // OneFuelUnitConsumptionIntervalInSec = 3600; // Consuming 1 unit of fuel every hour.
    * @param fuelMaxCapacity is the maximum capacity of fuel
   */
  function createAndAnchorSmartTurret(
    uint256 smartTurretId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public onlyAdmin {
    //Implement the logic to store the data in different modules: EntityRecord, Deployable, Location and ERC721
    _entityRecordLib().createEntityRecord(
      smartTurretId,
      entityRecordData.itemId,
      entityRecordData.typeId,
      entityRecordData.volume
    );

    _smartDeployableLib().registerDeployable(
      smartTurretId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );
    _smartDeployableLib().setSmartAssemblyType(smartTurretId, SmartAssemblyType.SMART_TURRET);

    LocationTableData memory locationData = LocationTableData({
      solarSystemId: worldPosition.solarSystemId,
      x: worldPosition.position.x,
      y: worldPosition.position.y,
      z: worldPosition.position.z
    });
    _smartDeployableLib().anchor(smartTurretId, locationData);
  }

  /**
   * @notice Configure Smart Turret
   * @param smartTurretId is smart object id of the Smart Turret
   * @param systemId is the system id of the Smart Turret logic
   */
  function configureSmartTurret(
    uint256 smartTurretId,
    ResourceId systemId
  ) public onlyAdminOrObjectOwner(smartTurretId) hookable(smartTurretId, _systemId()) {
    SmartTurretConfigTable.set(_namespace().smartTurretConfigTableId(), smartTurretId, systemId);
  }

  /**
   * @notice view function for turret logic based on proximity
   * @param smartTurretId is the is of the smart turret
   * @param characterId is the character id of the owner of the smart turret
   * @param priorityQueue is the queue of the SmartTurretTarget in proximity
   * @param turret is the Smart Turret object
   * @param turretTarget is the player entering the zone
   */
  function inProximity(
    uint256 smartTurretId,
    uint256 characterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartTurretId
    );
    if (currentState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartTurretId, currentState);
    }

    // Delegate the call to the implementation inProximity view function
    ResourceId systemId = SmartTurretConfigTable.get(_namespace().smartTurretConfigTableId(), smartTurretId);

    //If smart turret is not configured, then execute the default logic
    if (!ResourceIds.getExists(systemId)) {
      //If the corp and the smart turret owner of the target turret are same, then the turret will not attack
      uint256 smartTurretOwnerCorp = CharactersTable.getCorpId(_namespace().charactersTableId(), characterId);
      uint256 turretTargetCorp = CharactersTable.getCorpId(_namespace().charactersTableId(), turretTarget.characterId);
      if (smartTurretOwnerCorp != turretTargetCorp) {
        updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);
        for (uint256 i = 0; i < priorityQueue.length; i++) {
          updatedPriorityQueue[i] = priorityQueue[i];
        }

        updatedPriorityQueue[priorityQueue.length] = TargetPriority({ target: turretTarget, weight: 1 }); //should the weight be 1? or the heighest of all weights in the array ?
      } else {
        //If the corp and the smart turret owner of the target turret are same, then do not add the target turret to the priority queue
        updatedPriorityQueue = priorityQueue;
      }
    } else {
      bytes memory returnData = world().call(
        systemId,
        abi.encodeCall(this.inProximity, (smartTurretId, characterId, priorityQueue, turret, turretTarget))
      );

      updatedPriorityQueue = abi.decode(returnData, (TargetPriority[]));
    }

    return updatedPriorityQueue;
  }

  /**
   * @param smartTurretId is the is of the smart turret
   * @param characterId is the character id of the owner of the smart turret
   * @param priorityQueue is the queue of the SmartTurretTarget in proximity
   * @param turret is the Smart Turret object
   * @param aggressor is the player attacking inside the zone
   * @param victim is the player being attacked inside the zone
   */
  function aggression(
    uint256 smartTurretId,
    uint256 characterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory aggressor,
    SmartTurretTarget memory victim
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    State currentState = DeployableState.getCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartTurretId
    );
    if (currentState != State.ONLINE) {
      revert SmartDeployableErrors.SmartDeployable_IncorrectState(smartTurretId, currentState);
    }

    // Delegate the call to the implementation aggression view function
    ResourceId systemId = SmartTurretConfigTable.get(_namespace().smartTurretConfigTableId(), smartTurretId);

    if (!ResourceIds.getExists(systemId)) {
      //If smart turret is not configured, then execute the default logic
      updatedPriorityQueue = priorityQueue; //temporary logic
    } else {
      bytes memory returnData = world().call(
        systemId,
        abi.encodeCall(this.aggression, (smartTurretId, characterId, priorityQueue, turret, aggressor, victim))
      );

      updatedPriorityQueue = abi.decode(returnData, (TargetPriority[]));
    }

    return updatedPriorityQueue;
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
    return _namespace().smartTurretSystemId();
  }
}
