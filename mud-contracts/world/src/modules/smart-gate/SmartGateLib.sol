// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { EntityRecordData, WorldPosition } from "../smart-storage-unit/types.sol";
import { SmartObjectData } from "../smart-deployable/types.sol";

import { ISmartGate } from "./interfaces/ISmartGate.sol";
import { Utils } from "./Utils.sol";

/**
 * @title Smart Gate Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library SmartGateLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function createAndAnchorSmartGate(
    World memory world,
    uint256 smartGateId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 maxDistance
  ) internal {
    world.iface.call(
      world.namespace.smartGateSystemId(),
      abi.encodeCall(
        ISmartGate.createAndAnchorSmartGate,
        (
          smartGateId,
          entityRecordData,
          smartObjectData,
          worldPosition,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          maxDistance
        )
      )
    );
  }

  function configureSmartGate(World memory world, uint256 smartGateId, ResourceId systemId) internal {
    world.iface.call(
      world.namespace.smartGateSystemId(),
      abi.encodeCall(ISmartGate.configureSmartGate, (smartGateId, systemId))
    );
  }

  function linkSmartGates(World memory world, uint256 sourceGateId, uint256 destinationGateId) internal {
    world.iface.call(
      world.namespace.smartGateSystemId(),
      abi.encodeCall(ISmartGate.linkSmartGates, (sourceGateId, destinationGateId))
    );
  }

  function unlinkSmartGates(World memory world, uint256 sourceGateId, uint256 destinationGateId) internal {
    world.iface.call(
      world.namespace.smartGateSystemId(),
      abi.encodeCall(ISmartGate.unlinkSmartGates, (sourceGateId, destinationGateId))
    );
  }

  function canJump(
    World memory world,
    uint256 characterId,
    uint256 sourceGateId,
    uint256 destinationGateId
  ) internal returns (bool) {
    bytes memory returnedData = world.iface.call(
      world.namespace.smartGateSystemId(),
      abi.encodeCall(ISmartGate.canJump, (characterId, sourceGateId, destinationGateId))
    );

    return abi.decode(returnedData, (bool));
  }

  function isGateLinked(World memory world, uint256 sourceGateId, uint256 destinationGateId) internal returns (bool) {
    bytes memory returnedData = world.iface.call(
      world.namespace.smartGateSystemId(),
      abi.encodeCall(ISmartGate.isGateLinked, (sourceGateId, destinationGateId))
    );

    return abi.decode(returnedData, (bool));
  }
}
