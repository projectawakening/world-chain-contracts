// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { LocationData } from "../../../codegen/tables/Location.sol";

/**
 * @title Interface for Location
 * @author CCP Games
 * @notice must match the corresponding Location System
 */
interface ILocation {
  function saveLocation(uint256 entityId, LocationData memory location) external;
}
