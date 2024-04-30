// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { State } from "./types.sol";

interface SmartDeployableErrors {
  error SmartDeployable_IncorrectState(uint256 entityId, State requiredState, State currentState);
  error SmartDeployable_GloballyOffline();
  error SmartDeployableERC721AlreadyInitialized();
}
