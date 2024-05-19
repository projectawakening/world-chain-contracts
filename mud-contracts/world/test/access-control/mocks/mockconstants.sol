// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { HAS_ROLE_TABLE_NAME, ACCESS_CONFIG_TABLE_NAME } from "../../../src/modules/access-control/constants.sol";

bytes16 constant MODULE_MOCK_NAME = "ModuleMockModule";
bytes14 constant MODULE_MOCK_NAMESPACE = "ModuleMockName";

bytes16 constant FORWARD_MOCK_SYSTEM_NAME = "ForwardMockSyste";
ResourceId constant FORWARD_MOCK_SYSTEM_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_SYSTEM, WORLD_NAMESPACE, FORWARD_MOCK_SYSTEM_NAME))
);

bytes16 constant HOOKABLE_MOCK_SYSTEM_NAME = "HookableMockSyst";
ResourceId constant HOOKABLE_MOCK_SYSTEM_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_SYSTEM, WORLD_NAMESPACE, HOOKABLE_MOCK_SYSTEM_NAME))
);

bytes16 constant ACCESS_RULE_MOCK_SYSTEM_NAME = "AccessRuleMock";
ResourceId constant ACCESS_RULE_MOCK_SYSTEM_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_SYSTEM, WORLD_NAMESPACE, ACCESS_RULE_MOCK_SYSTEM_NAME))
);

ResourceId constant HAS_ROLE_TABLE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_TABLE, WORLD_NAMESPACE, HAS_ROLE_TABLE_NAME))
);

ResourceId constant ACCESS_CONFIG_TABLE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_TABLE, WORLD_NAMESPACE, ACCESS_CONFIG_TABLE_NAME))
);
