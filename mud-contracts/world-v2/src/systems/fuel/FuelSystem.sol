// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";
import { DeployableState, GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { FuelErrors } from "./FuelErrors.sol"; //

import { DECIMALS, ONE_UNIT_IN_WEI } from "../smart-deployable/constants.sol";

import { State } from "../../codegen/common.sol";

/**
 * @title FuelSystem
 * @author CCP Games
 * FuelSystem: stores the Fuel balance of a Smart Deployable
 */
contract FuelSystem is System, FuelErrors {
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
  function configureFuelParameters(
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
    Fuel.setLastUpdatedAt(entityId, block.timestamp);
  }

  /**
   * @dev deposit an amount of fuel for a Smart Deployable
   * @param entityId to deposit fuel to
   * @param fuelAmount of fuel in full units
   * TODO: make this function admin only
   */
  function depositFuel(uint256 entityId, uint256 fuelAmount) public {
    _updateFuel(entityId);
    FuelData memory fuel = Fuel.get(entityId);
    if (
      (((Fuel.getFuelAmount(entityId) + fuelAmount * ONE_UNIT_IN_WEI) * Fuel.getFuelUnitVolume(entityId))) /
        ONE_UNIT_IN_WEI >
      Fuel.getFuelMaxCapacity(entityId)
    ) {
      revert Fuel_TooMuchFuelDeposited(entityId, fuelAmount);
    }

    Fuel.setFuelAmount(entityId, _currentFuelAmount(entityId) + fuelAmount * ONE_UNIT_IN_WEI);
    Fuel.setLastUpdatedAt(entityId, block.timestamp);
  }

  /**
   * @dev withdraw an amount of fuel for a Smart Deployable
   * @param entityId to withdraw fuel from
   * @param fuelAmount of fuel in full units
   * TODO: make this function admin only
   */
  function withdrawFuel(uint256 entityId, uint256 fuelAmount) public {
    _updateFuel(entityId);

    Fuel.setFuelAmount(
      entityId,
      (_currentFuelAmount(entityId) - fuelAmount * ONE_UNIT_IN_WEI) // will revert if underflow
    );
    Fuel.setLastUpdatedAt(entityId, block.timestamp);
  }

  /*************************
   * INTERNAL FUEL METHODS *
   **************************/

  /**
   * @dev Deposit fuel into a smart deployable.
   * @param entityId The entity ID to deposit fuel into.
   */
  function _updateFuel(uint256 entityId) internal {
    uint256 currentFuel = _currentFuelAmount(entityId);
    State previousState = DeployableState.getCurrentState(entityId);

    if (currentFuel == 0 && (previousState == State.ONLINE)) {
      // _bringOffline() with manual function calls to avoid circular references (TODO: refactor decoupling to avoid redundancy)
      DeployableState.setPreviousState(entityId, previousState);
      DeployableState.setCurrentState(entityId, State.ANCHORED);
      DeployableState.setUpdatedBlockNumber(entityId, block.number);
      DeployableState.setUpdatedBlockTime(entityId, block.timestamp);

      Fuel.setFuelAmount(entityId, 0);
    } else {
      Fuel.setFuelAmount(entityId, currentFuel);
    }
  }

  /**
   * @dev Calculate the current fuel amount for a given entity.
   * @param entityId The entity ID to calculate the fuel amount for.
   * @return The current fuel amount.
   */
  function _currentFuelAmount(uint256 entityId) internal view returns (uint256) {
    // Check if the entity is not online. If it's not online, return the fuel amount directly.
    if (DeployableState.getCurrentState(entityId) != State.ONLINE) {
      return Fuel.getFuelAmount(entityId);
    }

    // Fetch the fuel balance data for the entity.
    FuelData memory fuelData = Fuel.get(entityId);

    uint256 oneFuelUnitConsumptionIntervalInSec = fuelData.fuelConsumptionIntervalInSeconds;

    // Calculate the fuel consumed since the last update.
    uint256 fuelConsumed = ((block.timestamp - fuelData.lastUpdatedAt) * ONE_UNIT_IN_WEI) /
      oneFuelUnitConsumptionIntervalInSec;

    // Subtract any global offline fuel refund from the consumed fuel.
    fuelConsumed -= _globalOfflineFuelRefund(entityId);

    // If the consumed fuel is greater than or equal to the current fuel amount, return 0.
    if (fuelConsumed >= fuelData.fuelAmount) {
      return 0;
    }

    // Return the remaining fuel amount.
    return fuelData.fuelAmount - fuelConsumed;
  }

  /**
   * @dev Calculate the global offline fuel refund for a given entity.
   * @param entityId The entity ID to calculate the refund for.
   * @return The amount of fuel to refund.
   */
  function _globalOfflineFuelRefund(uint256 entityId) internal view returns (uint256) {
    // Fetch the global deployable state data.
    GlobalDeployableStateData memory globalData = GlobalDeployableState.get();

    if (globalData.lastGlobalOffline == 0) return 0; // servers have never been shut down
    if (DeployableState.getCurrentState(entityId) != State.ONLINE) return 0;

    uint256 bringOnlineTimestamp = DeployableState.getUpdatedBlockTime(entityId);
    if (bringOnlineTimestamp < globalData.lastGlobalOffline) bringOnlineTimestamp = globalData.lastGlobalOffline;

    uint256 lastGlobalOnline = globalData.lastGlobalOnline;
    if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

    uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spent online during server downtime
    return ((elapsedRefundTime * ONE_UNIT_IN_WEI) / (Fuel.getFuelConsumptionIntervalInSeconds(entityId)));
  }
}
