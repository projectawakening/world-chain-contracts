// SPDX-License-Identifier: MIT
// cherry-picked from staged changes for next-17 release, unavailable in .16
pragma solidity >=0.8.21;

import { AccessManagementSystem } from "@latticexyz/world/src/modules/core/implementations/AccessManagementSystem.sol";
import { BalanceTransferSystem } from "@latticexyz/world/src/modules/core/implementations/BalanceTransferSystem.sol";
import { BatchCallSystem } from "@latticexyz/world/src/modules/core/implementations/BatchCallSystem.sol";

import { CoreModule } from "@latticexyz/world/src/modules/core/CoreModule.sol";
import { CoreRegistrationSystem } from "@latticexyz/world/src/modules/core/CoreRegistrationSystem.sol";

function createCoreModule() returns (CoreModule) {
  return
    new CoreModule(
      new AccessManagementSystem(),
      new BalanceTransferSystem(),
      new BatchCallSystem(),
      new CoreRegistrationSystem()
    );
}