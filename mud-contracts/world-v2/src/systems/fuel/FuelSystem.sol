// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";
import { DeployableState, GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";

import { State } from "../../codegen/common.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "../deployable/constants.sol";

/**
 * @title FuelSystem
 * @author CCP Games
 * FuelSystem: stores the Fuel balance of a Smart Deployable
 */
contract FuelSystem is System {
  error Fuel_NoFuel(uint256 smartObjectId);
  error Fuel_TooMuchFuelDeposited(uint256 smartObjectId, uint256 amountDeposited);
  error Fuel_InvalidFuelConsumptionInterval(uint256 smartObjectId);

  /**
   * @dev sets fuel parameters for a smart deployable
   * @param smartObjectId on-chain id of the in-game object
   * @param fuelUnitVolume the volume of a single unit of fuel
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   * @param fuelAmount the current fuel amount
   * @param lastUpdatedAt the last time the fuel was updated
   *
   */
  function configureFuelParameters(
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
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelUnitVolume the volume of a single unit of fuel
   */
  function setFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    Fuel.setFuelUnitVolume(smartObjectId, fuelUnitVolume);
  }

  /**
   * @dev sets the interval in seconds at which fuel is consumed
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   */
  function setFuelConsumptionIntervalInSeconds(uint256 smartObjectId, uint256 fuelConsumptionIntervalInSeconds) public {
    Fuel.setFuelConsumptionIntervalInSeconds(smartObjectId, fuelConsumptionIntervalInSeconds);
  }

  /**
   * @dev sets the maximum fuel capacity of the object
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   */
  function setFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) public {
    Fuel.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
  }

  /**
   * @dev sets the current fuel amount
   * @param smartObjectId on-chain if of the in-game deployable
   * @param fuelAmount the current fuel amount
   */
  function setFuelAmount(uint256 smartObjectId, uint256 fuelAmount) public {
    Fuel.setFuelAmount(smartObjectId, fuelAmount);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev deposit an amount of fuel for a Smart Deployable
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelAmount of fuel in full units
   * TODO: make this function admin only
   */
  function depositFuel(uint256 smartObjectId, uint256 fuelAmount) public {
    _updateFuel(smartObjectId);
    if (
      (((Fuel.getFuelAmount(smartObjectId) + fuelAmount * ONE_UNIT_IN_WEI) * Fuel.getFuelUnitVolume(smartObjectId))) /
        ONE_UNIT_IN_WEI >
      Fuel.getFuelMaxCapacity(smartObjectId)
    ) {
      revert Fuel_TooMuchFuelDeposited(smartObjectId, fuelAmount);
    }

    Fuel.setFuelAmount(smartObjectId, _currentFuelAmount(smartObjectId) + fuelAmount * ONE_UNIT_IN_WEI);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev withdraw an amount of fuel for a Smart Deployable
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelAmount of fuel in full units
   * TODO: make this function admin only
   */
  function withdrawFuel(uint256 smartObjectId, uint256 fuelAmount) public {
    _updateFuel(smartObjectId);

    Fuel.setFuelAmount(
      smartObjectId,
      (_currentFuelAmount(smartObjectId) - fuelAmount * ONE_UNIT_IN_WEI) // will revert if underflow
    );
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev updates the amount of fuel on tables (allows event firing through table write op)
   * TODO: this should be a class-level hook that we attach to all and any function related to smart-deployables,
   * or that compose with it
   * @param smartObjectId on-chain id of the in-game deployable
   */
  function updateFuel(uint256 smartObjectId) public {
    _updateFuel(smartObjectId);
  }

  /*************************
   * INTERNAL FUEL METHODS *
   **************************/

  /**
   * @dev Deposit fuel into a smart deployable.
   * @param smartObjectId on-chain id of the in-game deployable
   */
  function _updateFuel(uint256 smartObjectId) internal {
    uint256 currentFuel = _currentFuelAmount(smartObjectId);
    State previousState = DeployableState.getCurrentState(smartObjectId);

    if (currentFuel == 0 && (previousState == State.ONLINE)) {
      // _bringOffline() with manual function calls to avoid circular references (TODO: refactor decoupling to avoid redundancy)
      DeployableState.setPreviousState(smartObjectId, previousState);
      DeployableState.setCurrentState(smartObjectId, State.ANCHORED);
      DeployableState.setUpdatedBlockNumber(smartObjectId, block.number);
      DeployableState.setUpdatedBlockTime(smartObjectId, block.timestamp);

      Fuel.setFuelAmount(smartObjectId, 0);
    } else {
      Fuel.setFuelAmount(smartObjectId, currentFuel);
    }
  }

  /**
   * @dev Calculate the current fuel amount for a given entity.
   * @param smartObjectId on-chain id of the in-game deployable
   * @return the current fuel amount.
   */
  function _currentFuelAmount(uint256 smartObjectId) internal view returns (uint256) {
    // Check if the entity is not online. If it's not online, return the fuel amount directly.
    if (DeployableState.getCurrentState(smartObjectId) != State.ONLINE) {
      return Fuel.getFuelAmount(smartObjectId);
    }

    // Fetch the fuel balance data for the entity.
    FuelData memory fuelData = Fuel.get(smartObjectId);

    uint256 oneFuelUnitConsumptionIntervalInSec = fuelData.fuelConsumptionIntervalInSeconds;

    // Calculate the fuel consumed since the last update.
    uint256 fuelConsumed = ((block.timestamp - fuelData.lastUpdatedAt) * ONE_UNIT_IN_WEI) /
      oneFuelUnitConsumptionIntervalInSec;

    // Subtract any global offline fuel refund from the consumed fuel.
    fuelConsumed -= _globalOfflineFuelRefund(smartObjectId);

    // If the consumed fuel is greater than or equal to the current fuel amount, return 0.
    if (fuelConsumed >= fuelData.fuelAmount) {
      return 0;
    }

    // Return the remaining fuel amount.
    return fuelData.fuelAmount - fuelConsumed;
  }

  /**
   * @dev Calculate the global offline fuel refund for a given entity.
   * @param smartObjectId on-chain id of the in-game deployable
   * @return the amount of fuel to refund.
   */
  function _globalOfflineFuelRefund(uint256 smartObjectId) internal view returns (uint256) {
    // Fetch the global deployable state data.
    GlobalDeployableStateData memory globalData = GlobalDeployableState.get();

    if (globalData.lastGlobalOffline == 0) return 0; // servers have never been shut down
    if (DeployableState.getCurrentState(smartObjectId) != State.ONLINE) return 0; // no refunds if it's not running

    uint256 bringOnlineTimestamp = DeployableState.getUpdatedBlockTime(smartObjectId);
    if (bringOnlineTimestamp < globalData.lastGlobalOffline) bringOnlineTimestamp = globalData.lastGlobalOffline;

    uint256 lastGlobalOnline = globalData.lastGlobalOnline;
    if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

    uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spent online during server downtime
    return ((elapsedRefundTime * ONE_UNIT_IN_WEI) / (Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId)));
  }
}
