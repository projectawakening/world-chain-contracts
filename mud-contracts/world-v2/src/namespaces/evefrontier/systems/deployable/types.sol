// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// Import user types
// State: {NULL, UNANCHORED, ANCHORED, ONLINE, DESTROYED}
// defined in `mud.config.ts`
import { State } from "../../../../codegen/common.sol";
import { LocationData } from "../../codegen/tables/Location.sol";
import { EntityRecordParams } from "../entity-record/types.sol";

struct CreateAndAnchorParams {
  uint256 smartObjectId;
  string assemblyType;
  EntityRecordParams entityRecordParams;
  address owner;
  LocationData locationData;
}
