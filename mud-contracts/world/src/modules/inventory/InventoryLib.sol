// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { IInventory } from "./interfaces/IInventory.sol";
import { IEphemeralInventory } from "./interfaces/IEphemeralInventory.sol";
import { IInventoryInteract } from "./interfaces/IInventoryInteract.sol";
import { Utils } from "./Utils.sol";
import { InventoryItem } from "./types.sol";

/**
 * @title InventoryLib (makes interacting with the underlying systems cleaner)
 * Works similary to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing
 * @dev To preserve _msgSender() and other context dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into
 */
library InventoryLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function setInventoryCapacity(World memory world, uint256 smartObjectId, uint256 storageCapacity) internal {
    world.iface.call(
      world.namespace.inventorySystemId(),
      abi.encodeCall(IInventory.setInventoryCapacity, (smartObjectId, storageCapacity))
    );
  }

  function depositToInventory(World memory world, uint256 smartObjectId, InventoryItem[] memory items) internal {
    world.iface.call(
      world.namespace.inventorySystemId(),
      abi.encodeCall(IInventory.depositToInventory, (smartObjectId, items))
    );
  }

  function withdrawFromInventory(World memory world, uint256 smartObjectId, InventoryItem[] memory items) internal {
    world.iface.call(
      world.namespace.inventorySystemId(),
      abi.encodeCall(IInventory.withdrawFromInventory, (smartObjectId, items))
    );
  }

  function setEphemeralInventoryCapacity(
    World memory world,
    uint256 smartObjectId,
    uint256 ephemeralStorageCapacity
  ) internal {
    world.iface.call(
      world.namespace.ephemeralInventorySystemId(),
      abi.encodeCall(IEphemeralInventory.setEphemeralInventoryCapacity, (smartObjectId, ephemeralStorageCapacity))
    );
  }

  function depositToEphemeralInventory(
    World memory world,
    uint256 smartObjectId,
    address owner,
    InventoryItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.ephemeralInventorySystemId(),
      abi.encodeCall(IEphemeralInventory.depositToEphemeralInventory, (smartObjectId, owner, items))
    );
  }

  function withdrawFromEphemeralInventory(
    World memory world,
    uint256 smartObjectId,
    address owner,
    InventoryItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.ephemeralInventorySystemId(),
      abi.encodeCall(IEphemeralInventory.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );
  }

  function configureInteractionHandler(
    World memory world,
    uint256 smartObjectId,
    bytes memory interactionParams
  ) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteract.configureInteractionHandler, (smartObjectId, interactionParams))
    );
  }

  function inventoryToEphemeralTransfer(
    World memory world,
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteract.inventoryToEphemeralTransfer, (smartObjectId, items))
    );
  }

  function inventoryToEphemeralTransferWithParam(
    World memory world,
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory outItems
  ) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(
        IInventoryInteract.inventoryToEphemeralTransferWithParam,
        (smartObjectId, ephemeralInventoryOwner, outItems)
      )
    );
  }

  function ephemeralToInventoryTransfer(
    World memory world,
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteract.ephemeralToInventoryTransfer, (smartObjectId, items))
    );
  }
}
