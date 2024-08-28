//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ISmartCharacterErrors } from "./smart-character/ISmartCharacterErrors.sol";

/**
 * @title IErrors
 * @notice Interface for the all the errors in the world
 * @dev This is a solution to combine all the errors by inheriting into a single interface and merge with the world abi
 */
interface IErrors is ISmartCharacterErrors {}
