// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

// Local namespace tables
import { Fuel, FuelData, DeployableState, GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";

// Types and parameters
import { State } from "../../../../codegen/common.sol";
import { ONE_UNIT_IN_WEI } from "./../constants.sol";

/**
 * @title FuelSystem
 * @author CCP Games
 * FuelSystem: stores the Fuel balance of a Deployable
 */
contract FuelSystem is SmartObjectFramework {
  error Fuel_InvalidFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume, uint256 min, uint256 max);
  error Fuel_InvalidFuelConsumptionInterval(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 min,
    uint256 max
  );
  error Fuel_InvalidFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity, uint256 min, uint256 max);
  error Fuel_InvalidFuelAmount(uint256 smartObjectId, uint256 fuelAmount, uint256 min, uint256 max);
  error Fuel_ExceedsMaxCapacity(
    uint256 smartObjectId,
    uint256 fuelAmount,
    uint256 totalProjectedCapacity,
    uint256 maxCapacity
  );
  error Fuel_InsufficientFuel(uint256 smartObjectId, uint256 fuelAmount, uint256 availableFuel);

  /**
   * @dev sets fuel parameters for a Deployable
   * @param smartObjectId on-chain id of the in-game object
   * @param fuelUnitVolume the volume of a single unit of fuel
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   * @param fuelAmount the current fuel amount
   */
  function configureFuelParameters(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    // parameter restrictions based on preventing overflow / underflow maths
    if (fuelUnitVolume == 0 || fuelUnitVolume > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelUnitVolume(smartObjectId, fuelUnitVolume, 1, uint256(type(uint128).max));
    }
    if (
      fuelConsumptionIntervalInSeconds <= 1 || fuelConsumptionIntervalInSeconds > (type(uint256).max / ONE_UNIT_IN_WEI)
    ) {
      revert Fuel_InvalidFuelConsumptionInterval(
        smartObjectId,
        fuelConsumptionIntervalInSeconds,
        1,
        (type(uint256).max / ONE_UNIT_IN_WEI)
      );
    }
    if (fuelAmount > uint256(type(uint128).max) / ONE_UNIT_IN_WEI) {
      revert Fuel_InvalidFuelAmount(smartObjectId, fuelAmount, 0, uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    }
    if (fuelMaxCapacity < fuelAmount * fuelUnitVolume || fuelMaxCapacity <= fuelUnitVolume) {
      revert Fuel_InvalidFuelMaxCapacity(
        smartObjectId,
        fuelMaxCapacity,
        fuelAmount == 0 ? fuelUnitVolume + 1 : fuelAmount * fuelUnitVolume,
        uint256(type(uint256).max)
      );
    }

    Fuel.set(
      smartObjectId,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      fuelAmount * ONE_UNIT_IN_WEI,
      block.timestamp
    );
  }

  /**
   * @dev sets the volume of a single unit of fuel
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelUnitVolume the volume of a single unit of fuel
   */
  function setFuelUnitVolume(
    uint256 smartObjectId,
    uint256 fuelUnitVolume
  ) public context access(smartObjectId) scope(smartObjectId) {
    // max settable fuel unit volume is current maxCapacity / current fuel amount, must increase the max capacity or decrease the fuel amount for higher values
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    if (fuelUnitVolume == 0 || fuelUnitVolume * currentFuelAmount > Fuel.getFuelMaxCapacity(smartObjectId)) {
      if (currentFuelAmount != 0) {
        revert Fuel_InvalidFuelUnitVolume(
          smartObjectId,
          fuelUnitVolume,
          1,
          Fuel.getFuelMaxCapacity(smartObjectId) / currentFuelAmount
        );
      } else {
        revert Fuel_InvalidFuelUnitVolume(smartObjectId, fuelUnitVolume, 1, Fuel.getFuelMaxCapacity(smartObjectId));
      }
    }
    Fuel.setFuelUnitVolume(smartObjectId, fuelUnitVolume);
  }

  /**
   * @dev sets the interval in seconds at which fuel is consumed
   * This resets the rate of Fuel consumption for deployables when in an ONLINE state
   * WARNING: this will retroactively change the consumption rate of a deployable since it was last brought online.
   * @param smartObjectId the smart object id of the deployable
   * @param fuelConsumptionIntervalInSeconds the interval in seconds at which fuel is consumed
   * For example:
   * fuelConsumptionIntervalInSec = 1; // Consuming 1 unit of fuel every second.
   * fuelConsumptionIntervalInSec = 60; // Consuming 1 unit of fuel every minute.
   * fuelConsumptionIntervalInSec = 3600; // Consuming 1 unit of fuel every hour.
   */
  function setFuelConsumptionIntervalInSeconds(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds
  ) public context access(smartObjectId) scope(smartObjectId) {
    // consistent range enforcement
    if (
      fuelConsumptionIntervalInSeconds <= 1 || fuelConsumptionIntervalInSeconds > (type(uint256).max / ONE_UNIT_IN_WEI)
    ) {
      revert Fuel_InvalidFuelConsumptionInterval(
        smartObjectId,
        fuelConsumptionIntervalInSeconds,
        1,
        (type(uint256).max / ONE_UNIT_IN_WEI)
      );
    }
    Fuel.setFuelConsumptionIntervalInSeconds(smartObjectId, fuelConsumptionIntervalInSeconds);
  }

  /**
   * @dev sets the maximum fuel capacity of the object
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   */
  function setFuelMaxCapacity(
    uint256 smartObjectId,
    uint256 fuelMaxCapacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentCapacityUsage = _currentFuelAmount(smartObjectId) * Fuel.getFuelUnitVolume(smartObjectId);
    // minimum settable fuel max capacity is the current capacity usage, must reduce the fuel amount or the unit volume for lower values
    if (fuelMaxCapacity < currentCapacityUsage) {
      revert Fuel_InvalidFuelMaxCapacity(smartObjectId, fuelMaxCapacity, currentCapacityUsage, type(uint256).max);
    }
    Fuel.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
  }

  /**
   * @dev sets the current fuel amount
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelAmountInWei the new fuel amount in WEI. This will rest the existing fuel amount
   */
  function setFuelAmount(
    uint256 smartObjectId,
    uint256 fuelAmountInWei
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentVolume = Fuel.getFuelUnitVolume(smartObjectId);
    uint256 currentMaxCapacity = Fuel.getFuelMaxCapacity(smartObjectId);
    // fuelAmountInWei is fine grained value setting in the base of (fuelAmount * ONE_UNIT_IN_WEI)
    // max settable fuel amount is the minimum of our two restrictions
    if ((fuelAmountInWei / ONE_UNIT_IN_WEI) * currentVolume > currentMaxCapacity) {
      revert Fuel_InvalidFuelAmount(
        smartObjectId,
        fuelAmountInWei,
        0,
        (currentMaxCapacity * ONE_UNIT_IN_WEI) / currentVolume > uint256(type(uint128).max)
          ? uint256(type(uint128).max)
          : (currentMaxCapacity * ONE_UNIT_IN_WEI) / currentVolume
      );
    }
    if (fuelAmountInWei > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelAmount(
        smartObjectId,
        fuelAmountInWei,
        0,
        (currentMaxCapacity * ONE_UNIT_IN_WEI) / currentVolume > uint256(type(uint128).max)
          ? uint256(type(uint128).max)
          : (currentMaxCapacity * ONE_UNIT_IN_WEI) / currentVolume
      );
    }

    _updateFuel(smartObjectId);
    Fuel.setFuelAmount(smartObjectId, fuelAmountInWei);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev deposit an amount of fuel for a Deployable
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelAmount of fuel in full units
   */
  function depositFuel(
    uint256 smartObjectId,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    _updateFuel(smartObjectId);
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    uint256 currentVolume = Fuel.getFuelUnitVolume(smartObjectId);
    uint256 currentMaxCapacity = Fuel.getFuelMaxCapacity(smartObjectId);

    if ((((fuelAmount * ONE_UNIT_IN_WEI) + currentFuelAmount) * currentVolume) / ONE_UNIT_IN_WEI > currentMaxCapacity) {
      revert Fuel_InvalidFuelAmount(
        smartObjectId,
        fuelAmount,
        1,
        (currentMaxCapacity / currentVolume) - currentFuelAmount / ONE_UNIT_IN_WEI >
          uint256(type(uint128).max) / ONE_UNIT_IN_WEI
          ? uint256(type(uint128).max) / ONE_UNIT_IN_WEI
          : (currentMaxCapacity / currentVolume) - currentFuelAmount / ONE_UNIT_IN_WEI
      );
    }

    uint256 totalProjectedCapacity = ((currentFuelAmount + (fuelAmount * ONE_UNIT_IN_WEI)) * currentVolume) /
      ONE_UNIT_IN_WEI;

    if (totalProjectedCapacity > currentMaxCapacity) {
      revert Fuel_ExceedsMaxCapacity(smartObjectId, fuelAmount, totalProjectedCapacity, currentMaxCapacity);
    }

    Fuel.setFuelAmount(smartObjectId, currentFuelAmount + (fuelAmount * ONE_UNIT_IN_WEI));
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev withdraw an amount of fuel for a Deployable
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelAmount of fuel in full units
   */
  function withdrawFuel(
    uint256 smartObjectId,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    _updateFuel(smartObjectId);
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    if (fuelAmount == 0) {
      revert Fuel_InvalidFuelAmount(smartObjectId, fuelAmount, 1, uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    }
    // max withdrawable fuel amount is the current fuel amount (in base of WEI)
    if (currentFuelAmount < fuelAmount * ONE_UNIT_IN_WEI) {
      revert Fuel_InsufficientFuel(smartObjectId, fuelAmount, currentFuelAmount);
    }

    Fuel.setFuelAmount(smartObjectId, currentFuelAmount - (fuelAmount * ONE_UNIT_IN_WEI));
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev updates the amount of fuel on tables (allows event firing through table write op)
   * TODO: this could be a class-level hook that we attach to all and any function related to smart-deployables,
   * or that compose with it
   * @param smartObjectId on-chain id of the in-game deployable
   */
  function updateFuel(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    _updateFuel(smartObjectId);
  }

  function currentFuelAmountInWei(uint256 smartObjectId) public view returns (uint256 amount) {
    return _currentFuelAmount(smartObjectId);
  }

  /*************************
   * INTERNAL FUEL METHODS *
   **************************/

  /**
   * @dev Updates current fuel state on-chain
   * @param smartObjectId on-chain id of the in-game deployable
   */
  function _updateFuel(uint256 smartObjectId) internal {
    uint256 currentFuel = _currentFuelAmount(smartObjectId);
    State currentState = DeployableState.getCurrentState(smartObjectId);

    if (currentFuel == 0 && currentState == State.ONLINE) {
      // set to OFFLINE
      DeployableState.setPreviousState(smartObjectId, currentState);
      DeployableState.setCurrentState(smartObjectId, State.ANCHORED);
      DeployableState.setUpdatedBlockNumber(smartObjectId, block.number);
      DeployableState.setUpdatedBlockTime(smartObjectId, block.timestamp);

      Fuel.setFuelAmount(smartObjectId, 0);
    } else {
      Fuel.setFuelAmount(smartObjectId, currentFuel);
    }
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev Calculate the current fuel amount for a given entity.
   * @param smartObjectId on-chain id of the in-game deployable
   * @return the current fuel amount in WEI.
   */
  function _currentFuelAmount(uint256 smartObjectId) internal view returns (uint256) {
    // Check if the entity is not online. If it's not online, return the fuel amount directly.
    if (DeployableState.getCurrentState(smartObjectId) != State.ONLINE) {
      return Fuel.getFuelAmount(smartObjectId);
    }

    // Fetch the fuel balance data for the entity.
    FuelData memory fuelData = Fuel.get(smartObjectId);

    // For example:
    // OneFuelUnitConsumptionIntervalInSec = 1; // Consuming 1 unit of fuel every second.
    // OneFuelUnitConsumptionIntervalInSec = 60; // Consuming 1 unit of fuel every minute.
    // OneFuelUnitConsumptionIntervalInSec = 3600; // Consuming 1 unit of fuel every hour.
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
    if (bringOnlineTimestamp <= globalData.lastGlobalOffline) {
      bringOnlineTimestamp = globalData.lastGlobalOffline;
      uint256 lastGlobalOnline = globalData.lastGlobalOnline;
      if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

      uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spent online during server downtime
      return (elapsedRefundTime * ONE_UNIT_IN_WEI) / Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId);
    } else {
      return 0;
    }
  }
}
