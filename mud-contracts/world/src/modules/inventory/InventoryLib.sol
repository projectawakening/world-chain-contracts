// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { IInventorySystem } from "./interfaces/IInventorySystem.sol";
import { IEphemeralInventorySystem } from "./interfaces/IEphemeralInventorySystem.sol";
import { IInventoryInteractSystem } from "./interfaces/IInventoryInteractSystem.sol";
import { Utils } from "./Utils.sol";
import { InventoryItem } from "./types.sol";
import { TransferItem } from "./types.sol";

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
      abi.encodeCall(IInventorySystem.setInventoryCapacity, (smartObjectId, storageCapacity))
    );
  }

  function depositToInventory(World memory world, uint256 smartObjectId, InventoryItem[] memory items) internal {
    world.iface.call(
      world.namespace.inventorySystemId(),
      abi.encodeCall(IInventorySystem.depositToInventory, (smartObjectId, items))
    );
  }

  function withdrawFromInventory(World memory world, uint256 smartObjectId, InventoryItem[] memory items) internal {
    world.iface.call(
      world.namespace.inventorySystemId(),
      abi.encodeCall(IInventorySystem.withdrawFromInventory, (smartObjectId, items))
    );
  }

  function setEphemeralInventoryCapacity(
    World memory world,
    uint256 smartObjectId,
    uint256 ephemeralStorageCapacity
  ) internal {
    world.iface.call(
      world.namespace.ephemeralInventorySystemId(),
      abi.encodeCall(IEphemeralInventorySystem.setEphemeralInventoryCapacity, (smartObjectId, ephemeralStorageCapacity))
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
      abi.encodeCall(IEphemeralInventorySystem.depositToEphemeralInventory, (smartObjectId, owner, items))
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
      abi.encodeCall(IEphemeralInventorySystem.withdrawFromEphemeralInventory, (smartObjectId, owner, items))
    );
  }

  // InventoryInteract System functionality
  function ephemeralToInventoryTransfer(
    World memory world,
    uint256 smartObjectId,
    TransferItem[] memory items
  ) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteractSystem.ephemeralToInventoryTransfer, (smartObjectId, items))
    );
  }

  function inventoryToEphemeralTransfer(
    World memory world,
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    TransferItem[] memory outItems
  ) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(
        IInventoryInteractSystem.inventoryToEphemeralTransfer,
        (smartObjectId, ephemeralInventoryOwner, outItems)
      )
    );
  }

  function setApprovedAccessList(World memory world, uint256 smartObjectId, address[] memory accessList) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteractSystem.setApprovedAccessList, (smartObjectId, accessList))
    );
  }

  function setAllInventoryTransferAccess(World memory world, uint256 smartObjectId, bool isEnforced) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteractSystem.setAllInventoryTransferAccess, (smartObjectId, isEnforced))
    );
  }

  function setEphemeralToInventoryTransferAccess(World memory world, uint256 smartObjectId, bool isEnforced) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteractSystem.setEphemeralToInventoryTransferAccess, (smartObjectId, isEnforced))
    );
  }

  function setInventoryToEphemeralTransferAccess(World memory world, uint256 smartObjectId, bool isEnforced) internal {
    world.iface.call(
      world.namespace.inventoryInteractSystemId(),
      abi.encodeCall(IInventoryInteractSystem.setInventoryToEphemeralTransferAccess, (smartObjectId, isEnforced))
    );
  }
}
