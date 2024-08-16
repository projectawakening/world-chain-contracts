// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";

/**
 * @title FuelSystem
 * @author CCP Games
 * FuelSystem: stores the Fuel balance of a Smart Deployable
 */
contract FuelSystem is System {
  /**
   * @dev sets fuel parameters for a smart deployable
   * @param smartObjectId smartObjectId of the in-game object
   * @param fuelUnitVolume the volume of a single unit of fuel
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   * @param fuelAmount the current fuel amount
   * @param lastUpdatedAt the last time the fuel was updated
   *
   */
  function setFuelBalance(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 lastUpdatedAt
  ) public {
    Fuel.set(
      smartObjectId,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      fuelAmount,
      lastUpdatedAt
    );
  }

  /**
   * @dev sets the volume of a single unit of fuel
   * @param smartObjectId smartObjectId of the deployable
   * @param fuelUnitVolume the volume of a single unit of fuel
   */
  function setFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    Fuel.setFuelUnitVolume(smartObjectId, fuelUnitVolume);
  }

  /**
   * @dev sets the interval in seconds at which fuel is consumed
   * @param smartObjectId smartObjectId of the deployable
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   */
  function setFuelConsumptionIntervalInSeconds(uint256 smartObjectId, uint256 fuelConsumptionIntervalInSeconds) public {
    Fuel.setFuelConsumptionIntervalInSeconds(smartObjectId, fuelConsumptionIntervalInSeconds);
  }

  /**
   * @dev sets the maximum fuel capacity of the object
   * @param smartObjectId smartObjectId of the deployable
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   */
  function setFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) public {
    Fuel.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
  }

  /**
   * @dev sets the current fuel amount
   * @param smartObjectId smartObjectId of the deployable
   * @param fuelAmount the current fuel amount
   */
  function setFuelAmount(uint256 smartObjectId, uint256 fuelAmount) public {
    Fuel.setFuelAmount(smartObjectId, fuelAmount);
  }

  /**
   * @dev sets the last time the fuel was updated
   * @param smartObjectId smartObjectId of the deployable
   * @param lastUpdatedAt the last time the fuel was updated
   */
  function setLastUpdatedAt(uint256 smartObjectId, uint256 lastUpdatedAt) public {
    Fuel.setLastUpdatedAt(smartObjectId, lastUpdatedAt);
  }

  // depositFuel
  // withdrawFuel
  // updateFuel
  // get currentFuelAmount
}
