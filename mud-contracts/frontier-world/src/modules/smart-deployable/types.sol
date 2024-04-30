// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// Import user types
// State: {NULL, UNANCHORED, ANCHORED, ONLINE, DESTROYED}
// defined in `mud.config.ts`
import { State } from "../../codegen/common.sol";

/**
 * @notice Holds the data for a smart object
 * @dev SmartObjectData structure
 */
struct SmartObjectData {
  address owner;
  string tokenURI;
}
