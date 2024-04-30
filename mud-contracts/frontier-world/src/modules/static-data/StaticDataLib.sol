// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./Utils.sol";
import { IStaticData } from "./interfaces/IStaticData.sol";
import { StaticDataGlobalTableData } from "../../codegen/tables/StaticDataGlobalTable.sol";

/**
 * @title Static Data Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library StaticDataLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function setBaseURI(World memory world, ResourceId systemId, string memory baseURI) internal {
    world.iface.call(world.namespace.staticDataSystemId(), abi.encodeCall(IStaticData.setBaseURI, (systemId, baseURI)));
  }

  function setName(World memory world, ResourceId systemId, string memory name) internal {
    world.iface.call(world.namespace.staticDataSystemId(), abi.encodeCall(IStaticData.setName, (systemId, name)));
  }

  function setSymbol(World memory world, ResourceId systemId, string memory symbol) internal {
    world.iface.call(world.namespace.staticDataSystemId(), abi.encodeCall(IStaticData.setSymbol, (systemId, symbol)));
  }

  function setMetadata(World memory world, ResourceId systemId, StaticDataGlobalTableData memory data) internal {
    world.iface.call(world.namespace.staticDataSystemId(), abi.encodeCall(IStaticData.setMetadata, (systemId, data)));
  }

  function setCid(World memory world, uint256 entityId, string memory cid) internal {
    world.iface.call(world.namespace.staticDataSystemId(), abi.encodeCall(IStaticData.setCid, (entityId, cid)));
  }
}
