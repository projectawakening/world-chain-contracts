// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { EntityRecordData, WorldPosition } from "../smart-storage-unit/types.sol";
import { SmartObjectData } from "../smart-deployable/types.sol";

import { ISmartTurret } from "./interfaces/ISmartTurret.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "./types.sol";
import { Utils } from "./Utils.sol";

/**
 * @title Smart Turret Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library SmartTurretLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function createAndAnchorSmartTurret(
    World memory world,
    uint256 smartTurretId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) internal {
    world.iface.call(
      world.namespace.smartTurretSystemId(),
      abi.encodeCall(
        ISmartTurret.createAndAnchorSmartTurret,
        (
          smartTurretId,
          entityRecordData,
          smartObjectData,
          worldPosition,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity
        )
      )
    );
  }

  function configureSmartTurret(World memory world, uint256 smartTurretId, ResourceId systemId) internal {
    world.iface.call(
      world.namespace.smartTurretSystemId(),
      abi.encodeCall(ISmartTurret.configureSmartTurret, (smartTurretId, systemId))
    );
  }

  function inProximity(
    World memory world,
    uint256 smartTurretId,
    uint256 turretOwnerCharacterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) internal returns (TargetPriority[] memory updatedPriorityQueue) {
    bytes memory data = world.iface.call(
      world.namespace.smartTurretSystemId(),
      abi.encodeCall(
        ISmartTurret.inProximity,
        (smartTurretId, turretOwnerCharacterId, priorityQueue, turret, turretTarget)
      )
    );
    return abi.decode(data, (TargetPriority[]));
  }

  function aggression(
    World memory world,
    uint256 smartTurretId,
    uint256 turretOwnerCharacterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory aggressor,
    SmartTurretTarget memory victim
  ) internal returns (TargetPriority[] memory updatedPriorityQueue) {
    bytes memory data = world.iface.call(
      world.namespace.smartTurretSystemId(),
      abi.encodeCall(
        ISmartTurret.aggression,
        (smartTurretId, turretOwnerCharacterId, priorityQueue, turret, aggressor, victim)
      )
    );
    return abi.decode(data, (TargetPriority[]));
  }
}
