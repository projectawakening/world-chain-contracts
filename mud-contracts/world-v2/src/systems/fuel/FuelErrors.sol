// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { State } from "../smart-deployable/types.sol";

interface FuelErrors {
  error Fuel_NoFuel(uint256 entityId);
  error Fuel_TooMuchFuelDeposited(uint256 entityId, uint256 amountDeposited);
  error Fuel_InvalidFuelConsumptionInterval(uint256 entityId);
}
