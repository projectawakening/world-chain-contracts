// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant LOCATION_MODULE_NAME = "LocationModule";
bytes14 constant LOCATION_MODULE_NAMESPACE = "LocationModule";

ResourceId constant LOCATION_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, LOCATION_MODULE_NAMESPACE))
);

bytes16 constant LOCATION_TABLE_NAME = "LocationTable";

bytes16 constant LOCATION_SYSTEM_NAME = "Location";
