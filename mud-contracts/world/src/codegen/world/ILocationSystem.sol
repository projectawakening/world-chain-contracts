// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { LocationTableData } from "./../tables/LocationTable.sol";

/**
 * @title ILocationSystem
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface ILocationSystem {
  function eveworld__saveLocation(uint256 entityId, LocationTableData memory location) external;
}