// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { State } from "./types.sol";

interface SmartDeployableErrors {
  error SmartDeployable_IncorrectState(uint256 entityId, State currentState);
  error SmartDeployable_NoFuel(uint256 entityId);
  error SmartDeployable_StateTransitionPaused();
  error SmartDeployable_TooMuchFuelDeposited(uint256 entityId, uint256 amountDeposited);
  error SmartDeployableERC721AlreadyInitialized();
  error SmartDeployable_InvalidFuelConsumptionInterval(uint256 entityId);
  error SmartDeployable_InvalidObjectOwner(string message, address smartObjectOwner, uint256 smartObjectId);
}
