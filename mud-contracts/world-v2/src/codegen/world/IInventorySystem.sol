// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { InventoryItem } from "./../../systems/inventory/types.sol";

/**
 * @title IInventorySystem
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IInventorySystem {
  function eveworld__setInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) external;

  function eveworld__depositToInventory(uint256 smartObjectId, InventoryItem[] memory items) external;

  function eveworld__withdrawFromInventory(uint256 smartObjectId, InventoryItem[] memory items) external;
}