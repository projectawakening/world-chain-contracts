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
   * @param entityId entityId of the in-game object
   * @param fuelUnitVolume the volume of a single unit of fuel
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   * @param fuelAmount the current fuel amount
   * @param lastUpdatedAt the last time the fuel was updated
   *
   */
  function setFuelBalance(
    uint256 entityId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 lastUpdatedAt
  ) public {
    Fuel.set(entityId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount, lastUpdatedAt);
  }

  /**
   * @dev gets the fuel balance of a smart deployable
   * @param entityId entityId of the in-game object
   * @return FuelData struct of the fuel balance
   */
  function getFuelBalance(uint256 entityId) public view returns (FuelData memory) {
    return Fuel.get(entityId);
  }

  /**
   * @dev sets the volume of a single unit of fuel
   * @param entityId entityId of the deployable
   * @param fuelUnitVolume the volume of a single unit of fuel
   */
  function setFuelUnitVolume(uint256 entityId, uint256 fuelUnitVolume) public {
    Fuel.setFuelUnitVolume(entityId, fuelUnitVolume);
  }

  /**
   * @dev sets the interval in seconds at which fuel is consumed
   * @param entityId entityId of the deployable
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   */
  function setFuelConsumptionIntervalInSeconds(uint256 entityId, uint256 fuelConsumptionIntervalInSeconds) public {
    Fuel.setFuelConsumptionIntervalInSeconds(entityId, fuelConsumptionIntervalInSeconds);
  }

  /**
   * @dev sets the maximum fuel capacity of the object
   * @param entityId entityId of the deployable
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   */
  function setFuelMaxCapacity(uint256 entityId, uint256 fuelMaxCapacity) public {
    Fuel.setFuelMaxCapacity(entityId, fuelMaxCapacity);
  }

  /**
   * @dev sets the current fuel amount
   * @param entityId entityId of the deployable
   * @param fuelAmount the current fuel amount
   */
  function setFuelAmount(uint256 entityId, uint256 fuelAmount) public {
    Fuel.setFuelAmount(entityId, fuelAmount);
  }

  /**
   * @dev sets the last time the fuel was updated
   * @param entityId entityId of the deployable
   * @param lastUpdatedAt the last time the fuel was updated
   */
  function setLastUpdatedAt(uint256 entityId, uint256 lastUpdatedAt) public {
    Fuel.setLastUpdatedAt(entityId, lastUpdatedAt);
  }

  /**
   * @dev get the fuel amount of a Smart Deployable
   * @param entityId to get fuel amount of
   * @return fuelAmount of the Smart Deployable
   */
  function getFuelAmount(uint256 entityId) public view returns (uint256 fuelAmount) {
    return Fuel.getFuelAmount(entityId);
  }

  /**
   * @dev deposit an amount of fuel for a Smart Deployable
   * @param entityId to deposit fuel to
   * @param fuelAmount of fuel in full units
   * TODO: make this function admin only
   */
  function depositFuel(uint256 entityId, uint256 fuelAmount) public {
    FuelData memory fuel = Fuel.get(entityId);
    require(fuel.fuelAmount + fuelAmount <= fuel.fuelMaxCapacity, "FuelSystem: deposit exceeds max capacity");

    Fuel.setFuelAmount(entityId, fuel.fuelAmount + fuelAmount);

    Fuel.setLastUpdatedAt(entityId, block.timestamp);
  }

  /**
   * @dev withdraw an amount of fuel for a Smart Deployable
   * @param entityId to withdraw fuel from
   * @param fuelAmount of fuel in full units
   * TODO: make this function admin only
   */
  function withdrawFuel(uint256 entityId, uint256 fuelAmount) public {
    FuelData memory fuel = Fuel.get(entityId);
    require(fuel.fuelAmount - fuelAmount >= 0, "FuelSystem: withdraw exceeds current fuel amount");

    Fuel.setFuelAmount(entityId, fuel.fuelAmount - fuelAmount);

    Fuel.setLastUpdatedAt(entityId, block.timestamp);
  }
}
