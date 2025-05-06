// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

// Local namespace tables
import { Fuel, FuelData, DeployableState, FuelConsumptionState, FuelEfficiencyConfig } from "../../codegen/index.sol";

// Local namespace systems
import { networkNodeSystem } from "../../codegen/systems/NetworkNodeSystemLib.sol";

// Types and parameters
import { State } from "../../../../codegen/common.sol";
import { ONE_UNIT_IN_WEI } from "./../constants.sol";
import { FuelParams } from "./types.sol";
/**
 * @title FuelSystem
 * @author CCP Games
 * FuelSystem: stores the Fuel balance of a Deployable
 */
contract FuelSystem is SmartObjectFramework {
  error Fuel_InvalidFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume, uint256 min, uint256 max);
  error Fuel_InvalidFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity, uint256 min, uint256 max);
  error Fuel_InvalidFuelAmount(uint256 smartObjectId, uint256 fuelAmount, uint256 min, uint256 max);
  error Fuel_ExceedsMaxCapacity(
    uint256 smartObjectId,
    uint256 fuelAmount,
    uint256 totalProjectedCapacity,
    uint256 maxCapacity
  );
  error Fuel_InsufficientFuel(uint256 smartObjectId, uint256 fuelAmount, uint256 availableFuel);
  error Fuel_InvalidFuelBurnRate(uint256 smartObjectId, uint256 fuelBurnRateInSeconds, uint256 min, uint256 max);
  error Fuel_InvalidFuelTypeId(uint256 smartObjectId, uint256 fuelTypeId, uint256 min, uint256 max);
  error Fuel_InvalidFuelEfficiency(uint256 fuelTypeId, uint256 fuelEfficiency, uint256 min, uint256 max);
  error Fuel_BurnAlreadyStopped(uint256 smartObjectId);
  error Fuel_BurnNotActive(uint256 smartObjectId);

  /**
   * @dev sets fuel parameters for a Network Node
   * @param smartObjectId on-chain id of the network node
   * @param fuelParams the parameters of the fuel
   */
  function configureFuelParameters(
    uint256 smartObjectId,
    FuelParams memory fuelParams
  ) public context access(smartObjectId) scope(smartObjectId) {
    // parameter restrictions based on preventing overflow / underflow maths
    if (fuelParams.fuelUnitVolume == 0 || fuelParams.fuelUnitVolume > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelUnitVolume(smartObjectId, fuelParams.fuelUnitVolume, 1, uint256(type(uint128).max));
    }
    if (fuelParams.fuelMaxCapacity == 0 || fuelParams.fuelMaxCapacity > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelMaxCapacity(smartObjectId, fuelParams.fuelMaxCapacity, 1, uint256(type(uint128).max));
    }
    // fuel burn rate must be at least 60 seconds
    if (fuelParams.fuelBurnRateInSeconds < 60 || fuelParams.fuelBurnRateInSeconds > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelBurnRate(smartObjectId, fuelParams.fuelBurnRateInSeconds, 60, uint256(type(uint128).max));
    }
    if (fuelParams.fuelTypeId == 0 || fuelParams.fuelTypeId > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelTypeId(smartObjectId, fuelParams.fuelTypeId, 1, uint256(type(uint128).max));
    }

    Fuel.set(
      smartObjectId,
      fuelParams.fuelUnitVolume,
      fuelParams.fuelTypeId,
      fuelParams.fuelMaxCapacity,
      fuelParams.fuelAmount,
      fuelParams.fuelBurnRateInSeconds,
      block.timestamp
    );
  }

  /**
   * @dev configure fuel efficiency for a fuel type
   * @param fuelTypeId the type of fuel used
   * @param fuelEfficiency the efficiency of the fuel
   */
  function configureFuelEfficiency(uint256 fuelTypeId, uint256 fuelEfficiency) public {
    if (fuelTypeId == 0 || fuelTypeId > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelTypeId(fuelTypeId, fuelEfficiency, 1, uint256(type(uint128).max));
    }
    if (fuelEfficiency < 10 || fuelEfficiency > 100) {
      revert Fuel_InvalidFuelEfficiency(fuelTypeId, fuelEfficiency, 10, 100);
    }
    FuelEfficiencyConfig.set(fuelTypeId, fuelEfficiency);
  }

  /**
   * @dev deposit an amount of fuel to a deployable
   * @param smartObjectId on-chain id of the deployable
   * @param fuelAmount of fuel in full units
   */
  function depositFuel(
    uint256 smartObjectId,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    uint256 fuelMaxCapacity = Fuel.getFuelMaxCapacity(smartObjectId);
    uint256 currentVolume = Fuel.getFuelUnitVolume(smartObjectId);

    uint256 projectedCapacity = (currentFuelAmount + fuelAmount) * currentVolume;

    if (projectedCapacity > fuelMaxCapacity) {
      revert Fuel_ExceedsMaxCapacity(smartObjectId, fuelAmount, projectedCapacity, fuelMaxCapacity);
    }

    Fuel.setFuelAmount(smartObjectId, currentFuelAmount + fuelAmount);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev withdraw an amount of fuel from a deployable
   * @param smartObjectId on-chain id of the deployable
   * @param fuelAmount of fuel in full units
   */
  function withdrawFuel(
    uint256 smartObjectId,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);

    if (fuelAmount == 0 || fuelAmount > currentFuelAmount) {
      revert Fuel_InvalidFuelAmount(smartObjectId, fuelAmount, 1, currentFuelAmount);
    }
    Fuel.setFuelAmount(smartObjectId, currentFuelAmount - fuelAmount);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev Start burning fuel for a Network Node
   * @param smartObjectId on-chain id of the deployable
   * Consumes 1 unit of fuel, sets burnStartTime and fuelConsumptionTimeRemaining in FuelConsumptionState
   */
  function startBurn(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    if (currentFuelAmount == 0) {
      revert Fuel_InsufficientFuel(smartObjectId, 1, 0);
    }
    uint256 fuelBurnRateInSeconds = Fuel.getFuelBurnRateInSeconds(smartObjectId);
    // Consume 1 unit of fuel
    Fuel.setFuelAmount(smartObjectId, currentFuelAmount - 1);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);

    // Set burn state
    FuelConsumptionState.set(smartObjectId, block.timestamp, true, fuelBurnRateInSeconds);
  }

  /**
   * @dev Stop burning fuel for a Network Node
   * @param smartObjectId on-chain id of the deployable
   * Sets burnState to false and fuelConsumptionTimeRemaining to 0
   */
  function stopBurn(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    bool burnState = FuelConsumptionState.getBurnState(smartObjectId);
    if (!burnState) {
      revert Fuel_BurnAlreadyStopped(smartObjectId);
    }
    FuelConsumptionState.set(smartObjectId, FuelConsumptionState.getBurnStartTime(smartObjectId), false, 0);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  //TODO : Implement PauseBurn

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
   * @dev sets the maximum fuel capacity of the object
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   */
  function setFuelMaxCapacity(
    uint256 smartObjectId,
    uint256 fuelMaxCapacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentCapacityUsage = Fuel.getFuelAmount(smartObjectId) * Fuel.getFuelUnitVolume(smartObjectId);
    // minimum settable fuel max capacity is the current capacity usage, must reduce the fuel amount or the unit volume for lower values
    if (fuelMaxCapacity < currentCapacityUsage) {
      revert Fuel_InvalidFuelMaxCapacity(smartObjectId, fuelMaxCapacity, currentCapacityUsage, type(uint256).max);
    }
    Fuel.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
  }

  /**
   * @dev sets the current fuel amount
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelAmount the new fuel amount in WEI. This will rest the existing fuel amount
   */
  function setFuelAmount(
    uint256 smartObjectId,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentVolume = Fuel.getFuelUnitVolume(smartObjectId);
    uint256 currentMaxCapacity = Fuel.getFuelMaxCapacity(smartObjectId);
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);

    uint256 projectedCapacity = (fuelAmount + currentFuelAmount) * currentVolume;

    if (projectedCapacity > currentMaxCapacity) {
      revert Fuel_ExceedsMaxCapacity(smartObjectId, fuelAmount, projectedCapacity, currentMaxCapacity);
    }

    Fuel.setFuelAmount(smartObjectId, fuelAmount);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev updates the amount of fuel on tables (allows event firing through table write op)
   * TODO: this could be a class-level hook that we attach to all and any function related to smart-deployables,
   * or that compose with it
   * @param smartObjectId on-chain id of the in-game deployable
   */
  function updateFuel(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    //Update only if burn is active
    if (FuelConsumptionState.getBurnState(smartObjectId)) {
      _updateFuel(smartObjectId);
    }
  }

  /**
   * @dev Returns the current fuel consumption status for a Deployable at the current block.timestamp
   * Returns: (isBurning, timeLeft, unitsToConsume, actualConsumptionRateInSeconds, fuelAmount)
   */
  function getCurrentFuelConsumptionStatus(
    uint256 smartObjectId
  )
    public
    view
    returns (uint256 timeLeft, uint256 unitsToConsume, uint256 actualConsumptionRateInSeconds, uint256 fuelAmount)
  {
    uint256 burnStartTime = FuelConsumptionState.getBurnStartTime(smartObjectId);
    bool burnState = FuelConsumptionState.getBurnState(smartObjectId);
    uint256 fuelBurnRateInSeconds = Fuel.getFuelBurnRateInSeconds(smartObjectId);
    uint256 fuelTypeId = Fuel.getFuelTypeId(smartObjectId);
    uint256 fuelEfficiency = FuelEfficiencyConfig.getEfficiency(fuelTypeId); // 0-100
    fuelAmount = Fuel.getFuelAmount(smartObjectId);

    if (!burnState || burnStartTime == 0) {
      return (0, 0, 0, fuelAmount);
    }

    actualConsumptionRateInSeconds = (fuelBurnRateInSeconds * fuelEfficiency) / 100;
    //Divide by 0 check
    if (actualConsumptionRateInSeconds == 0) {
      return (0, 0, 0, fuelAmount);
    }

    uint256 currentTime = block.timestamp;
    uint256 elapsed = currentTime > burnStartTime ? currentTime - burnStartTime : 0;
    unitsToConsume = elapsed / actualConsumptionRateInSeconds;
    uint256 timeIntoCurrentUnit = elapsed % actualConsumptionRateInSeconds;

    if (unitsToConsume > 0 && fuelAmount == 0) {
      // Out of fuel
      return (0, unitsToConsume, actualConsumptionRateInSeconds, fuelAmount);
    }

    if (elapsed >= actualConsumptionRateInSeconds && fuelAmount > 0) {
      // This unit should have finished burning
      return (0, unitsToConsume, actualConsumptionRateInSeconds, fuelAmount);
    }

    timeLeft = actualConsumptionRateInSeconds - timeIntoCurrentUnit;
    return (timeLeft, unitsToConsume, actualConsumptionRateInSeconds, fuelAmount);
  }

  /*************************
   * INTERNAL FUEL METHODS *
   **************************/
  // Mock: handle out of fuel by calling NetworkNodeSystem to bring everything offline
  function _handleOutOfFuel(uint256 smartObjectId) internal {
    networkNodeSystem.handleNodeOffline(smartObjectId);
  }

  function _updateFuel(uint256 smartObjectId) internal {
    (
      uint256 timeLeft,
      uint256 unitsToConsume,
      uint256 actualConsumptionRateInSeconds,
      uint256 fuelAmount
    ) = getCurrentFuelConsumptionStatus(smartObjectId);

    if (unitsToConsume > 0) {
      uint256 actualUnitsToConsume = unitsToConsume > fuelAmount ? fuelAmount : unitsToConsume;
      fuelAmount -= actualUnitsToConsume;
      Fuel.setFuelAmount(smartObjectId, fuelAmount);

      uint256 burnStartTime = FuelConsumptionState.getBurnStartTime(smartObjectId);
      uint256 newBurnStartTime = burnStartTime + actualUnitsToConsume * actualConsumptionRateInSeconds;

      if (fuelAmount == 0) {
        FuelConsumptionState.set(smartObjectId, newBurnStartTime, false, 0);
        _handleOutOfFuel(smartObjectId);
      } else {
        uint256 newTimeRemaining = actualConsumptionRateInSeconds -
          ((block.timestamp > newBurnStartTime) ? (block.timestamp - newBurnStartTime) : 0);
        FuelConsumptionState.set(smartObjectId, newBurnStartTime, true, newTimeRemaining);
      }
    } else {
      // Not enough time for a full unit, just update time remaining
      uint256 burnStartTime = FuelConsumptionState.getBurnStartTime(smartObjectId);
      uint256 newTimeRemaining = timeLeft;
      if (newTimeRemaining == 0) {
        if (fuelAmount > 0) {
          Fuel.setFuelAmount(smartObjectId, fuelAmount - 1);
          if (fuelAmount - 1 == 0) {
            FuelConsumptionState.set(smartObjectId, burnStartTime, false, 0);
            _handleOutOfFuel(smartObjectId);
          }
        } else {
          Fuel.setFuelAmount(smartObjectId, 0);
          FuelConsumptionState.set(smartObjectId, burnStartTime, false, 0);
          _handleOutOfFuel(smartObjectId);
        }
        Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
      }
      FuelConsumptionState.set(smartObjectId, burnStartTime, true, newTimeRemaining);
    }
  }
}
