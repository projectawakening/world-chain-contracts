// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

// Local namespace tables
import { Fuel, FuelData, DeployableState, FuelConsumptionState, FuelEfficiencyConfig, NetworkNode, Tenant, EntityRecord } from "../../codegen/index.sol";

// Local namespace systems
import { networkNodeSystem } from "../../codegen/systems/NetworkNodeSystemLib.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { SmartAssemblySystem } from "../smart-assembly/SmartAssemblySystem.sol";

// Types and parameters
import { State } from "../../../../codegen/common.sol";
import { ONE_UNIT_IN_WEI, NETWORK_NODE, MIN_FUEL_EFFICIENCY, MAX_FUEL_EFFICIENCY, PERCENTAGE_DIVISOR, MIN_FUEL_BURN_RATE } from "./../constants.sol";
import { FuelParams } from "./types.sol";
import { EntityRecordParams } from "../entity-record/types.sol";

import { ObjectIdLib } from "../../libraries/ObjectIdLib.sol";

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
  error Fuel_InvalidFuelTypeId(uint256 smartObjectId, uint256 fuelSmartObjectId);
  error Fuel_InvalidFuelEfficiency(uint256 fuelSmartObjectId, uint256 fuelEfficiency, uint256 min, uint256 max);
  error Fuel_BurnAlreadyStopped(uint256 smartObjectId);
  error Fuel_BurnNotActive(uint256 smartObjectId);
  error Fuel_TypeMismatch(uint256 smartObjectId, uint256 currentFuelSmartObjectId, uint256 newFuelSmartObjectId);
  error Fuel_InvalidFuelSmartObjectId(uint256 smartObjectId, uint256 fuelSmartObjectId);

  /**
   * @dev sets fuel parameters for a Network Node
   * @param smartObjectId on-chain id of the network node
   * @param fuelParams the parameters of the fuel
   */
  function configureFuelParameters(
    uint256 smartObjectId,
    FuelParams memory fuelParams
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (fuelParams.fuelMaxCapacity == 0 || fuelParams.fuelMaxCapacity > uint256(type(uint128).max)) {
      revert Fuel_InvalidFuelMaxCapacity(smartObjectId, fuelParams.fuelMaxCapacity, 1, uint256(type(uint128).max));
    }
    // fuel burn rate must be at least 60 seconds
    if (
      fuelParams.fuelBurnRateInSeconds < MIN_FUEL_BURN_RATE ||
      fuelParams.fuelBurnRateInSeconds > uint256(type(uint128).max)
    ) {
      revert Fuel_InvalidFuelBurnRate(
        smartObjectId,
        fuelParams.fuelBurnRateInSeconds,
        MIN_FUEL_BURN_RATE,
        uint256(type(uint128).max)
      );
    }

    Fuel.setFuelMaxCapacity(smartObjectId, fuelParams.fuelMaxCapacity);
    Fuel.setFuelBurnRateInSeconds(smartObjectId, fuelParams.fuelBurnRateInSeconds);
    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev configure fuel efficiency for a fuel type
   * @param smartObjectId on-chain id of the deployable
   * @param fuelEntityParams the parameters of the fuel
   * @param fuelEfficiency the efficiency of the fuel
   * TODO: access control for this function
   */
  function configureFuelEfficiency(
    uint256 smartObjectId,
    EntityRecordParams memory fuelEntityParams,
    uint256 fuelEfficiency
  ) public context access(smartObjectId) {
    bytes32 tenantId = Tenant.get();

    if (tenantId != fuelEntityParams.tenantId) {
      revert SmartAssemblySystem.SmartAssembly_InvalidTenantId(smartObjectId, fuelEntityParams.tenantId);
    }

    if (ObjectIdLib.calculateNonSingletonId(tenantId, fuelEntityParams.typeId) != smartObjectId) {
      revert Fuel_InvalidFuelTypeId(smartObjectId, fuelEntityParams.typeId);
    }
    if (fuelEfficiency < 10 || fuelEfficiency > 100) {
      revert Fuel_InvalidFuelEfficiency(smartObjectId, fuelEfficiency, 10, 100);
    }

    entityRecordSystem.createRecord(smartObjectId, fuelEntityParams);
    FuelEfficiencyConfig.set(smartObjectId, fuelEfficiency);
  }

  /**
   * @dev deposit an amount of fuel to a deployable
   * @param smartObjectId on-chain id of the deployable
   * @param fuelSmartObjectId the smart object id of the fuel
   * @param fuelAmount of fuel in full units
   */
  function depositFuel(
    uint256 smartObjectId,
    uint256 fuelSmartObjectId,
    uint256 fuelAmount
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (!EntityRecord.getExists(fuelSmartObjectId)) {
      revert Fuel_InvalidFuelSmartObjectId(smartObjectId, fuelSmartObjectId);
    }

    if (fuelAmount == 0) {
      revert Fuel_InvalidFuelAmount(smartObjectId, fuelAmount, 1, type(uint256).max);
    }

    //cannot deposit fuel of different type unless the fuelAmount is 0
    if (
      Fuel.getFuelSmartObjectId(smartObjectId) != 0 && Fuel.getFuelSmartObjectId(smartObjectId) != fuelSmartObjectId
    ) {
      if (Fuel.getFuelAmount(smartObjectId) != 0) {
        revert Fuel_TypeMismatch(smartObjectId, Fuel.getFuelSmartObjectId(smartObjectId), fuelSmartObjectId);
      }
    }

    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    uint256 fuelMaxCapacity = Fuel.getFuelMaxCapacity(smartObjectId);
    uint256 currentVolume = EntityRecord.getVolume(fuelSmartObjectId);

    // Convert volume to fixed-point representation if it's not already
    currentVolume = currentVolume == 0 ? ONE_UNIT_IN_WEI : currentVolume;
    uint256 projectedCapacity = ((currentFuelAmount + fuelAmount) * currentVolume) / ONE_UNIT_IN_WEI;

    if (projectedCapacity > fuelMaxCapacity) {
      revert Fuel_ExceedsMaxCapacity(smartObjectId, fuelAmount, projectedCapacity, fuelMaxCapacity);
    }

    Fuel.setFuelSmartObjectId(smartObjectId, fuelSmartObjectId);
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
   * Consumes 1 unit of fuel, sets burnStartTime and preserves elapsed time
   */
  function startBurn(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    if (currentFuelAmount == 0) {
      revert Fuel_InsufficientFuel(smartObjectId, 1, 0);
    }

    // Get the previous elapsed time
    uint256 previousElapsedTime = FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId);

    if (previousElapsedTime == 0) {
      // Consume 1 unit of fuel
      Fuel.setFuelAmount(smartObjectId, currentFuelAmount - 1);
      Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
    }

    // Set burn state with previous elapsed time
    FuelConsumptionState.set(smartObjectId, block.timestamp, true, previousElapsedTime, 0);
  }

  /**
   * @dev Stop burning fuel for a Network Node
   * @param smartObjectId on-chain id of the deployable
   * Sets burnState to false and preserves elapsed time for next burn cycle
   */
  function stopBurn(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    bool burnState = FuelConsumptionState.getBurnState(smartObjectId);
    if (burnState) {
      // Keep elapsedTime for fuel consumption calculations
      uint256 burnStartTime = FuelConsumptionState.getBurnStartTime(smartObjectId);
      uint256 elapsedTime = block.timestamp > burnStartTime ? block.timestamp - burnStartTime : 0;

      uint256 previousElapsedTime = FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId);
      uint256 currentElapsedTime = previousElapsedTime + elapsedTime;

      // If the previous cycle is equal to the burn rate, then it means its completed a full cycle, so reset the previous cycle elapsed time to 0
      if (currentElapsedTime >= Fuel.getFuelBurnRateInSeconds(smartObjectId)) {
        currentElapsedTime = 0;
      }

      // Preserve elapsed time, just set burn state to false
      FuelConsumptionState.set(smartObjectId, 0, false, currentElapsedTime, 0);
      Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
    }
  }

  //TODO : Implement PauseBurn

  /**
   * @dev sets the maximum fuel capacity of the object
   * @param smartObjectId on-chain id of the in-game deployable
   * @param fuelMaxCapacity the maximum fuel capacity of the object
   */
  function setFuelMaxCapacity(
    uint256 smartObjectId,
    uint256 fuelMaxCapacity
  ) public context access(smartObjectId) scope(smartObjectId) {
    uint256 currentCapacityUsage = Fuel.getFuelAmount(smartObjectId) * EntityRecord.getVolume(smartObjectId);
    // minimum settable fuel max capacity is the current capacity usage, must reduce the fuel amount or the unit volume for lower values
    if (fuelMaxCapacity < currentCapacityUsage) {
      revert Fuel_InvalidFuelMaxCapacity(smartObjectId, fuelMaxCapacity, currentCapacityUsage, type(uint256).max);
    }
    Fuel.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
  }

  /**
   * @dev updates the amount of fuel on tables (allows event firing through table write op)
   * TODO: this could be a class-level hook that we attach to all and any function related to smart-deployables,
   * or that compose with it
   * @param smartObjectId on-chain id of the in-game deployable
   */
  function updateFuel(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    //Update only if there is enough fuel and burn is active
    if (FuelConsumptionState.getBurnState(smartObjectId)) {
      _updateFuel(smartObjectId);
    }
  }

  /**
   * @dev Returns the current fuel consumption status for a Deployable at the current block.timestamp
   * Returns: (elapsedTime, unitsToConsume, actualConsumptionRateInSeconds, fuelAmount)
   */
  function getCurrentFuelConsumptionStatus(
    uint256 smartObjectId
  )
    public
    view
    returns (uint256 elapsedTime, uint256 unitsToConsume, uint256 actualConsumptionRateInSeconds, uint256 fuelAmount)
  {
    uint256 fuelBurnRateInSeconds = Fuel.getFuelBurnRateInSeconds(smartObjectId);
    uint256 fuelSmartObjectId = Fuel.getFuelSmartObjectId(smartObjectId);
    uint256 burnStartTime = FuelConsumptionState.getBurnStartTime(smartObjectId);
    bool burnState = FuelConsumptionState.getBurnState(smartObjectId);
    uint256 fuelEfficiency = FuelEfficiencyConfig.getEfficiency(fuelSmartObjectId);
    fuelAmount = Fuel.getFuelAmount(smartObjectId);

    if (!burnState || burnStartTime == 0 || fuelBurnRateInSeconds < MIN_FUEL_BURN_RATE) {
      return (elapsedTime, 0, 0, fuelAmount);
    }

    // Calculate actual burn rate based on efficiency
    actualConsumptionRateInSeconds = fuelEfficiency >= MIN_FUEL_EFFICIENCY && fuelEfficiency <= MAX_FUEL_EFFICIENCY
      ? (fuelBurnRateInSeconds * fuelEfficiency) / PERCENTAGE_DIVISOR
      : fuelBurnRateInSeconds;

    uint256 currentTime = block.timestamp;
    uint256 elapsed = currentTime > burnStartTime ? currentTime - burnStartTime : 0;

    // Add previous cycle elapsed time to the current elapsed time only unit the first unit is being consumed
    uint256 previousCycleElapsedTime = FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId);
    if (previousCycleElapsedTime > 0) {
      elapsed += previousCycleElapsedTime;
    }
    //when the last unit is being consumed, we only consider for 1 unit of fuel window
    if (fuelAmount == 0) {
      elapsed = elapsed < actualConsumptionRateInSeconds ? elapsed : 0;
      return (elapsed, 0, actualConsumptionRateInSeconds, fuelAmount);
    }

    // Calculate units to consume based on total elapsed time
    unitsToConsume = elapsed / actualConsumptionRateInSeconds;
    elapsedTime = elapsed % actualConsumptionRateInSeconds;

    return (elapsedTime, unitsToConsume, actualConsumptionRateInSeconds, fuelAmount);
  }

  /*************************
   * INTERNAL FUEL METHODS *
   **************************/
  // Mock: handle out of fuel by calling NetworkNodeSystem to bring everything offline
  function _handleOutOfFuel(uint256 smartObjectId) internal {
    //stop burn before bringing offline
    if (DeployableState.getCurrentState(smartObjectId) == State.ONLINE) {
      deployableSystem.bringOffline(smartObjectId);
    }
  }

  /**
   * @dev Internal function to update fuel consumption state and handle fuel burning
   * @param smartObjectId The ID of the smart object to update fuel for
   * @notice This function handles:
   */
  function _updateFuel(uint256 smartObjectId) internal {
    // Get current fuel consumption status
    (
      uint256 elapsedTime,
      uint256 unitsToConsume,
      uint256 actualBurnRate,
      uint256 fuelAmount
    ) = getCurrentFuelConsumptionStatus(smartObjectId);

    // Handle case where no fuel is available
    if (fuelAmount == 0 && elapsedTime == 0) {
      _handleNoFuel(smartObjectId);
      return;
    }

    // If no units to consume, just update elapsed time
    if (unitsToConsume == 0) {
      FuelConsumptionState.setElapsedTime(smartObjectId, elapsedTime);
      Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
      return;
    }

    if (unitsToConsume > 0) {
      uint256 previousCycleElapsedTime = FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId);
      if (previousCycleElapsedTime > 0) {
        FuelConsumptionState.setPreviousCycleElapsedTime(smartObjectId, 0);
      }
    }

    // Calculate actual units to consume (limited by available fuel)
    uint256 actualUnitsToConsume = unitsToConsume > fuelAmount ? fuelAmount : unitsToConsume;

    // Update fuel amount
    fuelAmount -= actualUnitsToConsume;
    Fuel.setFuelAmount(smartObjectId, fuelAmount);

    // Calculate new burn timing
    uint256 burnStartTime = FuelConsumptionState.getBurnStartTime(smartObjectId);
    uint256 timeUsedForConsumption = actualUnitsToConsume * actualBurnRate;
    uint256 newBurnStartTime = burnStartTime + timeUsedForConsumption;

    // Handle state updates based on remaining fuel
    if (fuelAmount == 0) {
      _handleLastUnitConsumption(smartObjectId, elapsedTime, actualBurnRate, newBurnStartTime);
    } else {
      // Continue burning with updated times
      FuelConsumptionState.set(smartObjectId, newBurnStartTime, true, 0, elapsedTime);
    }

    Fuel.setLastUpdatedAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev Internal function to handle no fuel condition
   * @param smartObjectId The ID of the smart object
   */
  function _handleNoFuel(uint256 smartObjectId) internal {
    FuelConsumptionState.set(smartObjectId, 0, false, 0, 0);
    _handleOutOfFuel(smartObjectId);
  }

  /**
   * @dev Internal function to handle last unit consumption
   * @param smartObjectId The ID of the smart object
   * @param elapsedTime Current elapsed time
   * @param actualBurnRate Current burn rate
   * @param newBurnStartTime New burn start time
   */
  function _handleLastUnitConsumption(
    uint256 smartObjectId,
    uint256 elapsedTime,
    uint256 actualBurnRate,
    uint256 newBurnStartTime
  ) internal {
    if (elapsedTime >= actualBurnRate || elapsedTime == 0) {
      // Last unit is fully consumed
      FuelConsumptionState.set(smartObjectId, 0, false, 0, 0);
      _handleOutOfFuel(smartObjectId);
    } else {
      // Last unit is still being consumed
      FuelConsumptionState.set(smartObjectId, newBurnStartTime, true, 0, elapsedTime);
    }
  }
}
