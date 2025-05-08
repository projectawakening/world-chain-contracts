// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

struct FuelParams {
  uint256 fuelTypeId;
  uint256 fuelUnitVolume;
  uint256 fuelMaxCapacity;
  uint256 fuelBurnRateInSeconds;
  uint256 fuelAmount;
}
