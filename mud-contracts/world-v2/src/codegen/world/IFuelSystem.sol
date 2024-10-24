// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

/**
 * @title IFuelSystem
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IFuelSystem {
  error Fuel_NoFuel(uint256 smartObjectId);
  error Fuel_ExceedsMaxCapacity(uint256 smartObjectId, uint256 maxCapacity, uint256 fuelAmount);
  error Fuel_InvalidFuelConsumptionInterval(uint256 smartObjectId);

  function evefrontier__configureFuelParameters(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) external;

  function evefrontier__setFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) external;

  function evefrontier__setFuelConsumptionIntervalInSeconds(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds
  ) external;

  function evefrontier__setFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) external;

  function evefrontier__setFuelAmount(uint256 smartObjectId, uint256 fuelAmountInWei) external;

  function evefrontier__depositFuel(uint256 smartObjectId, uint256 fuelAmount) external;

  function evefrontier__withdrawFuel(uint256 smartObjectId, uint256 fuelAmount) external;

  function evefrontier__updateFuel(uint256 smartObjectId) external;

  function evefrontier__currentFuelAmountInWei(uint256 smartObjectId) external view returns (uint256 amount);
}