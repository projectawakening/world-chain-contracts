pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { Utils } from "./Utils.sol";
import { IGateKeeper } from "./interfaces/IGateKeeper.sol";
import { SmartObjectData, EntityRecordData, WorldPosition } from "../smart-storage-unit/types.sol";
import { InventoryItem } from "../inventory/types.sol";

/**
 * @title GateKeeper Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library GateKeeperLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function createAndAnchorGateKeeper(
    World memory world,
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) internal {
    world.iface.call(
      world.namespace.gateKeeperSystemId(),
      abi.encodeCall(
        IGateKeeper.createAndAnchorGateKeeper,
        (
          smartObjectId,
          entityRecordData,
          smartObjectData,
          worldPosition,
          fuelUnitVolume,
          fuelConsumptionPerMinute,
          fuelMaxCapacity,
          storageCapacity,
          ephemeralStorageCapacity
        )
      )
    );
  }

  function setAcceptedItemTypeId(World memory world, uint256 smartObjectId, uint256 entityTypeId) internal {
    world.iface.call(
      world.namespace.gateKeeperSystemId(),
      abi.encodeCall(IGateKeeper.setAcceptedItemTypeId, (smartObjectId, entityTypeId))
    );
  }

  function setTargetQuantity(World memory world, uint256 smartObjectId, uint256 targetItemQuantity) internal {
    world.iface.call(
      world.namespace.gateKeeperSystemId(),
      abi.encodeCall(IGateKeeper.setTargetQuantity, (smartObjectId, targetItemQuantity))
    );
  }
}
