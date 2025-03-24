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
import { DeployableState, SmartTurretConfig, Characters, CharactersByAccount, OwnershipByObject, Initialize } from "../../codegen/index.sol";

// Local namespace systems
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { smartTurretSystem } from "../../codegen/systems/SmartTurretSystemLib.sol";

// Types and parameters
import { State, CreateAndAnchorParams } from "../deployable/types.sol";
import { TargetPriority, Turret, SmartTurretTarget, AggressionParams } from "./types.sol";
import { SMART_TURRET } from "../constants.sol";

contract SmartTurretSystem is SmartObjectFramework {
  /**
   * @notice Create and anchor a Smart Turret
   * @param params CreateAndAnchorDeployableParams
   */
  function createAndAnchorTurret(
    CreateAndAnchorParams memory params
  ) public context access(params.smartObjectId) scope(getSmartTurretClassId()) {
    entitySystem.instantiate(getSmartTurretClassId(), params.smartObjectId, params.owner);

    params.assemblyType = SMART_TURRET;
    deployableSystem.createAndAnchor(params);
  }

  /**
   * @notice Configure Smart Turret
   * @param smartObjectId is smart object id of the Smart Turret
   * @param systemId is the system id of the Smart Turret logic
   * // TODO make it configurable only by owner of the smart turret
   */
  function configureTurret(
    uint256 smartObjectId,
    ResourceId systemId
  ) public context access(smartObjectId) scope(smartObjectId) {
    SmartTurretConfig.set(smartObjectId, systemId);
  }

  /**
   * @notice view function for turret logic based on proximity
   * @param smartObjectId is the is of the smart turret
   * @param priorityQueue is the queue of existing SmartTurretTargets in proximity
   * @param turret is the Smart Turret object
   * @param turretTarget is the new SmartTurretTarget entering the zone
   */
  function inProximity(
    uint256 smartObjectId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public context returns (TargetPriority[] memory updatedPriorityQueue) {
    State currentState = DeployableState.getCurrentState(smartObjectId);
    if (currentState != State.ONLINE) {
      revert DeployableSystem.Deployable_IncorrectState(smartObjectId, currentState);
    }

    // check if there is a configured implementation for the inProximity view function
    ResourceId systemId = SmartTurretConfig.get(smartObjectId);

    //If smart turret is not configured, then execute the default logic
    if (!ResourceIds.getExists(systemId)) {
      // If the tribe of the smart turret owner and of the target are same, then the turret will not attack
      address smartTurretOwner = OwnershipByObject.get(smartObjectId);
      uint256 turretOwnerCharacterId = CharactersByAccount.getSmartObjectId(smartTurretOwner);
      uint256 smartTurretOwnerTribe = Characters.getTribeId(turretOwnerCharacterId);
      uint256 turretTargetTribe = Characters.getTribeId(turretTarget.characterId);
      if (smartTurretOwnerTribe != turretTargetTribe) {
        updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);
        for (uint256 i = 0; i < priorityQueue.length; i++) {
          updatedPriorityQueue[i] = priorityQueue[i];
        }
        updatedPriorityQueue[priorityQueue.length] = TargetPriority({ target: turretTarget, weight: 1 });
      } else {
        // If the tribe of the smart turret owner and of the new target are same, then do not add the new target to the priority queue
        updatedPriorityQueue = priorityQueue;
      }
    } else {
      bytes memory returnData = getWorld().call(
        systemId,
        abi.encodeCall(this.inProximity, (smartObjectId, priorityQueue, turret, turretTarget))
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

    // check if there is a configured implementation for the aggression view function
    ResourceId systemId = SmartTurretConfig.get(params.smartObjectId);

    if (!ResourceIds.getExists(systemId)) {
      // If the tribe of the smart turret owner and of the aggressor are same, then the turret will not attack
      address turretOwner = OwnershipByObject.get(params.smartObjectId);
      uint256 turretOwnerCharacterId = CharactersByAccount.getSmartObjectId(turretOwner);
      uint256 turretOwnerTribe = Characters.getTribeId(turretOwnerCharacterId);
      uint256 aggressorTribe = Characters.getTribeId(params.aggressor.characterId);

      if (turretOwnerTribe != aggressorTribe) {
        updatedPriorityQueue = new TargetPriority[](params.priorityQueue.length + 1);
        for (uint256 i = 0; i < params.priorityQueue.length; i++) {
          updatedPriorityQueue[i] = params.priorityQueue[i];
        }

        updatedPriorityQueue[params.priorityQueue.length] = TargetPriority({ target: params.aggressor, weight: 1 });
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
