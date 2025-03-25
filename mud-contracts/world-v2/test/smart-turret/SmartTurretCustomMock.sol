// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
// import { TargetPriority, Turret, SmartTurretTarget } from "../../src/namespaces/evefrontier/systems/smart-turret/types.sol";
// import { Characters, CharactersData } from "../../src/namespaces/evefrontier/codegen/tables/Characters.sol";
// import { AggressionParams } from "../../src/namespaces/evefrontier/systems/smart-turret/types.sol";

contract SmartTurretCustomMock is System {
  // function inProximity(
  //   uint256 smartTurretId,
  //   uint256 characterId,
  //   TargetPriority[] memory priorityQueue,
  //   Turret memory turret,
  //   SmartTurretTarget memory turretTarget
  // ) public returns (TargetPriority[] memory updatedPriorityQueue) {
  //   //TODO: Implement the logic for the system
  //   CharactersData memory characterData = Characters.get(turretTarget.characterId);
  //   if (characterData.tribeId == 100) {
  //     return priorityQueue;
  //   }
  //   return updatedPriorityQueue;
  // }
  // function aggression(AggressionParams memory params) public returns (TargetPriority[] memory updatedPriorityQueue) {
  //   return params.priorityQueue;
  // }
}
