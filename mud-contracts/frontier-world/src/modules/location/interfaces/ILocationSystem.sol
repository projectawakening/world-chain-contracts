// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";

/**
 * @title Interface for Location
 * @author CCP Games
 * @notice must match the corresponding Location System
 */
interface ILocationSystem {
  function saveLocation(uint256 entityId, LocationTableData memory location) external;
}
