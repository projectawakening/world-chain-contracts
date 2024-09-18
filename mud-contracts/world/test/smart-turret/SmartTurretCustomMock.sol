// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "../../src/modules/smart-turret/types.sol";
import { CharactersTable, CharactersTableData } from "../../src/codegen/tables/CharactersTable.sol";

contract SmartTurretCustomMock is System {
  using SmartCharacterUtils for bytes14;

  function inProximity(
    uint256 smartTurretId,
    uint256 characterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    //TODO: Implement the logic for the system
    CharactersTableData memory characterData = CharactersTable.get(turretTarget.characterId);
    if (characterData.corpId == 100) {
      return priorityQueue;
    }

    return updatedPriorityQueue;
  }

  function aggression(
    uint256 smartTurretId,
    uint256 characterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory aggressor,
    SmartTurretTarget memory victim
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    return priorityQueue;
  }
}
