// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { StaticDataGlobalTableData } from "../../../codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";

import { SmartObjectData } from "../types.sol";

interface ISmartDeployable {
  function registerDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity
  ) external;

  function destroyDeployable(uint256 entityId) external;

  function bringOnline(uint256 entityId) external;

  function bringOffline(uint256 entityId) external;

  function anchor(uint256 entityId, LocationTableData memory location) external;

  function unanchor(uint256 entityId) external;

  function globalPause() external;

  function globalResume() external;

  function setFuelConsumptionPerMinute(uint256 entityId, uint256 fuelConsumptionPerMinute) external;

  function setFuelMaxCapacity(uint256 entityId, uint256 amount) external;

  function depositFuel(uint256 entityId, uint256 unitAmount) external;

  function withdrawFuel(uint256 entityId, uint256 unitAmount) external;

  function updateFuel(uint256 entityId) external;

  function currentFuelAmount(uint256 entityId) external view returns (uint256 amount);

  function registerDeployableToken(address tokenAddress) external;
}
