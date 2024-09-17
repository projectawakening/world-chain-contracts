// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { State, SmartObjectData, SmartAssemblyType } from "./types.sol";
import { Utils } from "./Utils.sol";
import { ISmartDeployable } from "./interfaces/ISmartDeployable.sol";

import { LocationTableData } from "../../codegen/tables/LocationTable.sol";

/**
 * @title Smart Deployable Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library SmartDeployableLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function registerDeployable(
    World memory world,
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolumeInWei,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacityInWei
  ) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(
        ISmartDeployable.registerDeployable,
        (entityId, smartObjectData, fuelUnitVolumeInWei, fuelConsumptionIntervalInSeconds, fuelMaxCapacityInWei)
      )
    );
  }

  function setSmartAssemblyType(World memory world, uint256 entityId, SmartAssemblyType smartAssemblyType) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.setSmartAssemblyType, (entityId, smartAssemblyType))
    );
  }

  function registerDeployableToken(World memory world, address tokenAddress) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.registerDeployableToken, (tokenAddress))
    );
  }

  function destroyDeployable(World memory world, uint256 entityId) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.destroyDeployable, (entityId))
    );
  }

  function bringOnline(World memory world, uint256 entityId) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.bringOnline, (entityId))
    );
  }

  function bringOffline(World memory world, uint256 entityId) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.bringOffline, (entityId))
    );
  }

  function anchor(World memory world, uint256 entityId, LocationTableData memory location) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.anchor, (entityId, location))
    );
  }

  function unanchor(World memory world, uint256 entityId) internal {
    world.iface.call(world.namespace.smartDeployableSystemId(), abi.encodeCall(ISmartDeployable.unanchor, (entityId)));
  }

  function globalPause(World memory world) internal {
    world.iface.call(world.namespace.smartDeployableSystemId(), abi.encodeCall(ISmartDeployable.globalPause, ()));
  }

  function globalResume(World memory world) internal {
    world.iface.call(world.namespace.smartDeployableSystemId(), abi.encodeCall(ISmartDeployable.globalResume, ()));
  }

  function setFuelConsumptionPerMinute(
    World memory world,
    uint256 entityId,
    uint256 fuelConsumptionIntervalInSeconds
  ) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.setFuelConsumptionPerMinute, (entityId, fuelConsumptionIntervalInSeconds))
    );
  }

  function setFuelMaxCapacity(World memory world, uint256 entityId, uint256 capacityInWei) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.setFuelMaxCapacity, (entityId, capacityInWei))
    );
  }

  function depositFuel(World memory world, uint256 entityId, uint256 unitAmount) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.depositFuel, (entityId, unitAmount))
    );
  }

  function withdrawFuel(World memory world, uint256 entityId, uint256 unitAmount) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.withdrawFuel, (entityId, unitAmount))
    );
  }

  function updateFuel(World memory world, uint256 entityId) internal {
    world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.updateFuel, (entityId))
    );
  }

  function currentFuelAmount(World memory world, uint256 entityId) internal returns (uint256 amount) {
    bytes memory returnData = world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.currentFuelAmount, (entityId))
    );
    return abi.decode(returnData, (uint256));
  }

  function currentFuelAmountInWei(World memory world, uint256 entityId) internal returns (uint256 amount) {
    bytes memory returnData = world.iface.call(
      world.namespace.smartDeployableSystemId(),
      abi.encodeCall(ISmartDeployable.currentFuelAmountInWei, (entityId))
    );
    return abi.decode(returnData, (uint256));
  }
}
