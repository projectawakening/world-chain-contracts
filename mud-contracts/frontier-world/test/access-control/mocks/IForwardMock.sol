// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Interface definition for ForwardMock.
 */
 interface IForwardMock {
  function callTarget(uint256 entityId) external returns (bool);
}