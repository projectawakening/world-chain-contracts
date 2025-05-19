//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

bytes14 constant DEPLOYMENT_NAMESPACE = "evefrontier";
string constant SMART_STORAGE_UNIT = "SSU";
string constant SMART_TURRET = "ST";
string constant SMART_GATE = "SG";
string constant NETWORK_NODE = "NWN";

uint256 constant DECIMALS = 18;
uint256 constant ONE_UNIT_IN_WEI = 1 * (10 ** DECIMALS);

uint256 constant MIN_FUEL_EFFICIENCY = 10;
uint256 constant MAX_FUEL_EFFICIENCY = 100;

uint256 constant PERCENTAGE_DIVISOR = 100;

uint256 constant MIN_FUEL_BURN_RATE = 60;
