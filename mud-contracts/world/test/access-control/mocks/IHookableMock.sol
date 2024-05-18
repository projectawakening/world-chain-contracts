// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Interface definition for HookableMock.
 */
 interface IHookableMock {
  /**
  *
   * Implements the  `hookable()` modifier, see {EveSystem} and {HookCore} for more details.
   *
   */
  function target(uint256 entityId) external returns (bool);
}