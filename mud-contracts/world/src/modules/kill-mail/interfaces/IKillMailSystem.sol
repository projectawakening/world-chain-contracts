// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { KillMailLossType } from "../../../codegen/common.sol";
import { KillMailTableData } from "../../../codegen/tables/KillMailTable.sol";

interface IKillMailSystem {
  function reportKill(uint256 killMailId, KillMailTableData memory killMailTableData) external;
}
