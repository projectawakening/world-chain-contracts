// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant ENTITY_RECORD_MODULE_NAME = "EntityRecordModu";
bytes14 constant ENTITY_RECORD_MODULE_NAMESPACE = "EntityRecordMo";

ResourceId constant ENTITY_RECORD_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, ENTITY_RECORD_MODULE_NAMESPACE))
);

bytes16 constant ENTITY_RECORD_TABLE_NAME = "EntityRecordTabl";
bytes16 constant ENTITY_RECORD_OFFCHAIN_TABLE_NAME = "EntityOffchainTa";
