// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

/**
 * @title IEntityRecord system
 */
interface IEntityRecord {
  function createCharacter(string memory name) external returns (bytes32 key);
}