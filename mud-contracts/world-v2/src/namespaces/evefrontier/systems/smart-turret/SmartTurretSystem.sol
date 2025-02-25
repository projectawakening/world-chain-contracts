// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

import { DeployableState } from "../../codegen/index.sol";
import { SmartTurretConfig } from "../../codegen/index.sol";
import { Characters } from "../../codegen/index.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { DeployableSystemLib, deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { WorldPosition } from "../location/types.sol";
import { LocationData } from "../../codegen/tables/Location.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "./types.sol";
import { SMART_TURRET } from "../constants.sol";
import { CreateAndAnchorDeployableParams } from "../deployable/types.sol";
import { AggressionParams } from "./types.sol";
import { Initialize } from "../../codegen/index.sol";
import { smartTurretSystem } from "../../codegen/systems/SmartTurretSystemLib.sol";

contract SmartTurretSystem is SmartObjectFramework {
  error SmartTurret_NotConfigured(uint256 smartObjectId);

  /**
   * @notice Create and anchor a Smart Turret
   * @param params CreateAndAnchorDeployableParams
   */
  function createAndAnchorSmartTurret(
    CreateAndAnchorDeployableParams memory params
  ) public context access(params.smartObjectId) scope(getSmartTurretClassId()) {
    entitySystem.instantiate(getSmartTurretClassId(), params.smartObjectId, params.smartObjectData.owner);

    params.smartAssemblyType = SMART_TURRET;
    deployableSystem.createAndAnchorDeployable(params);
  }

  /**
   * @notice Configure Smart Turret
   * @param smartObjectId is smart object id of the Smart Turret
   * @param systemId is the system id of the Smart Turret logic
   * // TODO make it configurable only by owner of the smart turret
   */
  function configureSmartTurret(
    uint256 smartObjectId,
    ResourceId systemId
  ) public context access(smartObjectId) scope(smartObjectId) {
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
  ) public context returns (TargetPriority[] memory updatedPriorityQueue) {
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
      bytes memory returnData = getWorld().call(
        systemId,
        abi.encodeCall(this.inProximity, (smartObjectId, turretOwnerCharacterId, priorityQueue, turret, turretTarget))
      );

      updatedPriorityQueue = abi.decode(returnData, (TargetPriority[]));
    }

    return updatedPriorityQueue;
  }

  /**
   * @notice view function for turret logic based on aggression
   * @param params AggressionParams
   */
  function aggression(
    AggressionParams memory params
  ) public context returns (TargetPriority[] memory updatedPriorityQueue) {
    State currentState = DeployableState.getCurrentState(params.smartObjectId);
    if (currentState != State.ONLINE) {
      revert DeployableSystem.Deployable_IncorrectState(params.smartObjectId, currentState);
    }

    // Delegate the call to the implementation aggression view function
    ResourceId systemId = SmartTurretConfig.get(params.smartObjectId);

    if (!ResourceIds.getExists(systemId)) {
      //If the corp of the smart turret owner of the aggressor are same, then the turret will not attack
      uint256 turretOwnerCorp = Characters.getTribeId(params.turretOwnerCharacterId);
      uint256 aggressorCorp = Characters.getTribeId(params.aggressor.characterId);

      if (turretOwnerCorp != aggressorCorp) {
        updatedPriorityQueue = new TargetPriority[](params.priorityQueue.length + 1);
        for (uint256 i = 0; i < params.priorityQueue.length; i++) {
          updatedPriorityQueue[i] = params.priorityQueue[i];
        }

        updatedPriorityQueue[params.priorityQueue.length] = TargetPriority({ target: params.aggressor, weight: 1 }); //should the weight be 1? or the heighest of all weights in the array ?
      } else {
        updatedPriorityQueue = params.priorityQueue;
      }
    } else {
      bytes memory returnData = getWorld().call(systemId, abi.encodeCall(this.aggression, (params)));

      updatedPriorityQueue = abi.decode(returnData, (TargetPriority[]));
    }

    return updatedPriorityQueue;
  }

  function getSmartTurretClassId() public view returns (uint256) {
    return Initialize.get(smartTurretSystem.toResourceId());
  }

  function getWorld() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }
}
