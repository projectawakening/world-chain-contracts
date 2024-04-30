// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant STATIC_DATA_MODULE_NAME = "StaticDataModule";
bytes14 constant STATIC_DATA_MODULE_NAMESPACE = "StaticDataModu";

ResourceId constant STATIC_DATA_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, STATIC_DATA_MODULE_NAMESPACE))
);

bytes16 constant STATIC_DATA_TABLE_NAME = "StaticDataTable";
bytes16 constant STATIC_DATA_GLOBAL_TABLE_NAME = "StaticDataGTable";
