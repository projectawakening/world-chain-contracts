pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { Utils } from "./Utils.sol";
import { ISmartStorageUnit } from "./interfaces/ISmartStorageUnit.sol";
import { EntityRecordData, SmartObjectData, WorldPosition } from "./types.sol";
import { InventoryItem } from "../inventory/types.sol";

/**
 * @title Smart Storage Unit Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library SmartStorageUnitLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function createAndAnchorSmartStorageUnit(
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
      world.namespace.smartStorageUnitSystemId(),
      abi.encodeCall(
        ISmartStorageUnit.createAndAnchorSmartStorageUnit,
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

  function createAndDepositItemsToInventory(
    World memory world,
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.smartStorageUnitSystemId(),
      abi.encodeCall(ISmartStorageUnit.createAndDepositItemsToInventory, (smartObjectId, items))
    );
  }

  function createAndDepositItemsToEphemeralInventory(
    World memory world,
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.smartStorageUnitSystemId(),
      abi.encodeCall(
        ISmartStorageUnit.createAndDepositItemsToEphemeralInventory,
        (smartObjectId, inventoryOwner, items)
      )
    );
  }

  function setDeployableMetadata(
    World memory world,
    uint256 smartObjectId,
    string memory name,
    string memory dappURL,
    string memory description
  ) internal {
    world.iface.call(
      world.namespace.smartStorageUnitSystemId(),
      abi.encodeCall(ISmartStorageUnit.setDeployableMetadata, (smartObjectId, name, dappURL, description))
    );
  }

  function setSSUClassId(World memory world, uint256 classId) internal {
    world.iface.call(
      world.namespace.smartStorageUnitSystemId(),
      abi.encodeCall(ISmartStorageUnit.setSSUClassId, (classId))
    );
  }
}
