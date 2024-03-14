// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant SMART_CHARACTER_MODULE_NAME = "SmartCharModule";
bytes14 constant SMART_CHARACTER_MODULE_NAMESPACE= "SmartCharModul";

// TODO: this needs to match with the namespace used during `world.installModule(smartObjectModule, abi.encode("namespace"))`
// and/or match the `namespace` field in mud.config.ts, depending how you deploy the Smart Object Framework 
// (e.g. through `mud deploy` or inside a post-deployment Forge script) 
// it's a bit of an inconvenience, but refactoring the namespace used to access the right tables in EveSystem dynamically would
// require to read some form of storage, and that makes up for a lot of read operations and it's costly
// so it's best to just hard-code this for now
bytes14 constant SMART_CHRACTER_DEPLOYMENT_NAMESPACE = "SmartChar_v0";

ResourceId constant SMART_CHARACTER_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, SMART_CHARACTER_MODULE_NAMESPACE))
);

bytes16 constant CHARACTERS_TABLE_NAME = "SmartCharTable";

bytes16 constant SMART_CHARACTER_SYSTEM_NAME = "SmartCharSystem";