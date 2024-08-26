// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

// System Names - must be unique per Namespace, must match one of the System names provided to the mud.config.ts file
// standard convention is to use the first 16 characters of the System contract name
bytes16 constant ACCESS_SYSTEM_NAME = "AccessSystem";

// Table Names - must be unique per Namespace, must match one of the Table names provided to the mud.config.ts file
bytes16 constant ACCESS_ROLE_TABLE_NAME = "AccessRole";
bytes16 constant ACCESS_ENFORCEMENT_TABLE_NAME = "AccessEnforcemen";

// the namespace of the core, SOF, EVE World and modules
bytes14 constant EVE_WORLD_NAMESPACE = "eveworld";

// AccessRole constants
bytes32 constant ADMIN = bytes32("ADMIN_ACCESS_ROLE");
bytes32 constant APPROVED = bytes32("APPROVED_ACCESS_ROLE");
