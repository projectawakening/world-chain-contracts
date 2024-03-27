// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./Utils.sol";
import { ILocation } from "./interfaces/ILocation.sol";
import { LocationData } from "../../codegen/tables/Location.sol";

/**
 * @title Location Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library LocationLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function saveLocation(World memory world, uint256 entityId, LocationData memory locationData) internal {
    world.iface.call(world.namespace.locationSystemId(), abi.encodeCall(ILocation.saveLocation, (entityId, locationData)));
  }
}
