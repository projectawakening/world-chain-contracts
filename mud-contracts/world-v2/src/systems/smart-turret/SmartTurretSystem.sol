// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { SmartTurretConfig } from "../../codegen/index.sol";
import { Characters, CharacterToken } from "../../codegen/index.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { DeployableUtils } from "../deployable/DeployableUtils.sol";
import { FuelUtils } from "../fuel/FuelUtils.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { WorldPosition } from "../location/types.sol";
import { LocationData } from "../../codegen/tables/Location.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "./types.sol";
import { SMART_TURRET } from "../constants.sol";
import { EveSystem } from "../EveSystem.sol";

contract SmartTurretSystem is EveSystem {
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();

  /**
      * @notice Create and anchor a Smart Turret
      * @param smartObjectId is smart object id of the Smart Turret
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
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
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
          SMART_TURRET,
          entityRecordData,
          smartObjectData,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          locationData
        )
      )
    );
  }

  /**
   * @notice Configure Smart Turret
   * @param smartObjectId is smart object id of the Smart Turret
   * @param systemId is the system id of the Smart Turret logic
   * // TODO make it configurable only by owner of the smart turret
   */
  function configureSmartTurret(uint256 smartObjectId, ResourceId systemId) public {
    SmartTurretConfig.set(smartObjectId, systemId);
  }

  /**
   * @notice view function for turret logic based on proximity
   * @param smartObjectId is the is of the smart turret
   * @param turretOwnerCharacterId is the character id of the owner of the smart turret
   * @param priorityQueue is the queue of the SmartTurretTarget in proximity
   * @param turret is the Smart Turret object
   * @param turretTarget is the player entering the zone
   */
  function inProximity(
    uint256 smartObjectId,
    uint256 turretOwnerCharacterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (currentState != State.ONLINE) {
      revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
    }

    // Delegate the call to the implementation inProximity view function
    ResourceId systemId = SmartTurretConfig.get(smartObjectId);

    //If smart turret is not configured, then execute the default logic
    if (!ResourceIds.getExists(systemId)) {
      //If the corp and the smart turret owner of the target turret are same, then the turret will not attack
      uint256 smartTurretOwnerCorp = Characters.getTribeId(turretOwnerCharacterId);
      uint256 turretTargetCorp = Characters.getTribeId(turretTarget.characterId);
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
        abi.encodeCall(this.inProximity, (smartObjectId, turretOwnerCharacterId, priorityQueue, turret, turretTarget))
      );

      updatedPriorityQueue = abi.decode(returnData, (TargetPriority[]));
    }

    return updatedPriorityQueue;
  }

  /**
   * @param smartObjectId is the is of the smart turret
   * @param turretOwnerCharacterId is the character id of the owner of the smart turret
   * @param priorityQueue is the queue of the SmartTurretTarget in proximity
   * @param turret is the Smart Turret object
   * @param aggressor is the player attacking inside the zone
   * @param victim is the player being attacked inside the zone
   */
  function aggression(
    uint256 smartObjectId,
    uint256 turretOwnerCharacterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory aggressor,
    SmartTurretTarget memory victim
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (currentState != State.ONLINE) {
      revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
    }

    // Delegate the call to the implementation aggression view function
    ResourceId systemId = SmartTurretConfig.get(smartObjectId);

    if (!ResourceIds.getExists(systemId)) {
      //If the corp of the smart turret owner of the aggressor are same, then the turret will not attack
      uint256 turretOwnerCorp = Characters.getTribeId(turretOwnerCharacterId);
      uint256 aggressorCorp = Characters.getTribeId(aggressor.characterId);

      if (turretOwnerCorp != aggressorCorp) {
        updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);
        for (uint256 i = 0; i < priorityQueue.length; i++) {
          updatedPriorityQueue[i] = priorityQueue[i];
        }

        updatedPriorityQueue[priorityQueue.length] = TargetPriority({ target: aggressor, weight: 1 }); //should the weight be 1? or the heighest of all weights in the array ?
      } else {
        updatedPriorityQueue = priorityQueue;
      }
    } else {
      bytes memory returnData = world().call(
        systemId,
        abi.encodeCall(
          this.aggression,
          (smartObjectId, turretOwnerCharacterId, priorityQueue, turret, aggressor, victim)
        )
      );

      updatedPriorityQueue = abi.decode(returnData, (TargetPriority[]));
    }

    return updatedPriorityQueue;
  }
}
