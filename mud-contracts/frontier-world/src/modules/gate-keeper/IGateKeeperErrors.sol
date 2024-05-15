//SPDX-LicenseIdentifier: MIT
pragma solidity >=0.8.21;

interface IGateKeeperErrors {
  error GateKeeper_WrongItemArrayLength();
  error GateKeeper_WrongDepositType(uint256 expectedItemId, uint256 itemId);
  error GateKeeper_DepositOverTargetLimit();
}
