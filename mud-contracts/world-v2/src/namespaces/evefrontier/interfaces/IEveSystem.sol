// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

/**
 * @title IEveSystem
 * @author CCP Games
 * @notice Interface for the EveSystem contract that defines all public functions
 */
interface IEveSystem {
  /**
   * @notice Register a smart character class with the given type ID
   * @param typeId The type ID for the smart character class
   */
  function registerSmartCharacterClass(uint256 typeId) external;

  /**
   * @notice Register a smart storage unit class with the given type ID
   * @param typeId The type ID for the smart storage unit class
   */
  function registerSmartStorageUnitClass(uint256 typeId) external;

  /**
   * @notice Register a smart turret class with the given type ID
   * @param typeId The type ID for the smart turret class
   */
  function registerSmartTurretClass(uint256 typeId) external;

  /**
   * @notice Register a smart gate class with the given type ID
   * @param typeId The type ID for the smart gate class
   */
  function registerSmartGateClass(uint256 typeId) external;

  /**
   * @notice Configure access for EntityRecordSystem
   */
  function configureEntityRecordAccess() external;

  /**
   * @notice Configure access for StaticDataSystem
   */
  function configureStaticDataAccess() external;

  /**
   * @notice Configure access for SmartAssemblySystem
   */
  function configureSmartAssemblyAccess() external;

  /**
   * @notice Configure access for SmartCharacterSystem
   */
  function configureSmartCharacterAccess() external;

  /**
   * @notice Configure access for LocationSystem
   */
  function configureLocationAccess() external;

  /**
   * @notice Configure access for FuelSystem
   */
  function configureFuelAccess() external;

  /**
   * @notice Configure access for DeployableSystem
   */
  function configureDeployableAccess() external;

  /**
   * @notice Configure access for InventorySystem
   */
  function configureInventoryAccess() external;

  /**
   * @notice Configure access for EphemeralInventorySystem
   */
  function configureEphemeralInventoryAccess() external;

  /**
   * @notice Configure access for InventoryInteractSystem
   */
  function configureInventoryInteractAccess() external;

  /**
   * @notice Configure access for SmartStorageUnitSystem
   */
  function configureSmartStorageUnitAccess() external;

  /**
   * @notice Configure access for SmartTurretSystem
   */
  function configureSmartTurretAccess() external;

  /**
   * @notice Configure access for SmartGateSystem
   */
  function configureSmartGateAccess() external;
}
