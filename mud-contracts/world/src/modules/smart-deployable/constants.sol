// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

uint256 constant DECIMALS = 18;
uint256 constant ONE_UNIT_IN_WEI = 1 * (10 ** DECIMALS);

bytes16 constant SMART_DEPLOYABLE_MODULE_NAME = "SmartDeployableM";
bytes14 constant SMART_DEPLOYABLE_MODULE_NAMESPACE = "SmartDeployabl";

bytes16 constant GLOBAL_STATE_TABLE_NAME = "GlobalDeployable";
bytes16 constant DEPLOYABLE_STATE_TABLE_NAME = "DeployableState";
bytes16 constant DEPLOYABLE_TOKEN_TABLE_NAME = "DeployableTokenT";
bytes16 constant FUEL_BALANCE_TABLE_NAME = "FuelBalanceTable";
bytes16 constant SMART_ASSEMBLY_TABLE_NAME = "SmartAssemblyTab";
