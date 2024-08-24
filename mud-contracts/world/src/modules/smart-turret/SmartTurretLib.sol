pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { EntityRecordData, WorldPosition } from "../smart-storage-unit/types.sol";
import { ISmartTurret } from "./interfaces/ISmartTurret.sol";
import { SmartObjectData } from "../smart-deployable/types.sol";
import { Target } from "./types.sol";

import { Utils } from "./Utils.sol";

/**
 * @title Smart Turret Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
contract SmartTurretLib {
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
}
