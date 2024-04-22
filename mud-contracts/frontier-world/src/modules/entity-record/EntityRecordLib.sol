// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./Utils.sol";
import { IEntityRecord } from "./interfaces/IEntityRecord.sol";

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
    uint8 typeId,
    uint256 volume
  ) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecord.createEntityRecord, (entityId, itemId, typeId, volume))
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
      abi.encodeCall(IEntityRecord.createEntityRecordOffchain, (entityId, name, dappURL, description))
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
      abi.encodeCall(IEntityRecord.setEntityMetadata, (entityId, name, dappURL, description))
    );
  }

  function setName(World memory world, uint256 entityId, string memory name) internal {
    world.iface.call(world.namespace.entityRecordSystemId(), abi.encodeCall(IEntityRecord.setName, (entityId, name)));
  }

  function setDappURL(World memory world, uint256 entityId, string memory dappURL) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecord.setDappURL, (entityId, dappURL))
    );
  }

  function setDescription(World memory world, uint256 entityId, string memory description) internal {
    world.iface.call(
      world.namespace.entityRecordSystemId(),
      abi.encodeCall(IEntityRecord.setDescription, (entityId, description))
    );
  }
}
