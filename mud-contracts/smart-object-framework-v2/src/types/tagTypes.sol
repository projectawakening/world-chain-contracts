// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @dev Constants used to work with Tag types.
 */

/**
 * @dev Identifies that a Tag is associated to a MUD System (for Class/Object scope enforcement).
 * NOTE: these leading bytes match the ResourceId leading bytes for a System, this is to shrink any needed conversion logic
 */
bytes2 constant TAG_SYSTEM = "sy";
