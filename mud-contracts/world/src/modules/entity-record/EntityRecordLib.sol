// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./Utils.sol";
import { IEntityRecordSystem } from "./interfaces/IEntityRecordSystem.sol";

/**
 * @title Entity Record Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library EntityRecordLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  // Entity Record methods
  function createEntityRecord(
    World memory world,
    uint256 entityId,
    uint256 itemId,
    uint256 typeId,
    uint256 volume
  ) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecordSystem.createEntityRecord, (entityId, itemId, typeId, volume))
    );
  }

  function createEntityRecordOffchain(
    World memory world,
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecordSystem.createEntityRecordOffchain, (entityId, name, dappURL, description))
    );
  }

  function setEntityMetadata(
    World memory world,
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecordSystem.setEntityMetadata, (entityId, name, dappURL, description))
    );
  }

  function setName(World memory world, uint256 entityId, string memory name) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecordSystem.setName, (entityId, name))
    );
  }

  function setDappURL(World memory world, uint256 entityId, string memory dappURL) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecordSystem.setDappURL, (entityId, dappURL))
    );
  }

  function setDescription(World memory world, uint256 entityId, string memory description) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecordSystem.setDescription, (entityId, description))
    );
  }
}
