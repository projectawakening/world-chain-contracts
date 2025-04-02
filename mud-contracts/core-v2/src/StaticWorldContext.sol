// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";

/**
 * @title StaticWorldContextProviderLib - Utility functions to staticcall contracts with context values appended to calldata.
 * @author CCP Games dev team
 * @notice This library provides functions to make calls or delegatecalls to other contracts,
 * appending the context values (like msg.sender and msg.value) to the calldata for WorldContextConsumer to consume.
 */
library StaticWorldContextProviderLib {
  /**
   * @notice Appends context values to the given calldata.
   * @param callData The original calldata.
   * @param msgSender The address of the transaction sender.
   * @param msgValue The amount of ether sent with the original transaction.
   * @return The new calldata with context values appended.
   */
  function appendContext(
    bytes memory callData,
    address msgSender,
    uint256 msgValue
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(callData, msgSender, msgValue);
  }

  /**
   * @notice Makes a staticcall to the target contract with context values appended to the calldata.
   * @param msgSender The address of the transaction sender.
   * @param target The address of the contract to call.
   * @param callData The calldata for the call.
   * @return success A boolean indicating whether the call was successful or not.
   * @return data The abi encoded return data from the call.
   */
  function staticCallWithContext(
    address msgSender,
    address target,
    bytes memory callData
  ) internal view returns (bool success, bytes memory data) {
    (success, data) = target.staticcall(
      appendContext({ callData: callData, msgSender: msgSender, msgValue: 0 }) // msgValue always 0 for staticcall
    );
  }

  /**
   * @notice Makes a staticcall to the target contract with context values appended to the calldata.
   * @dev Revert in the case of failure.
   * @param msgSender The address of the transaction sender.
   * @param target The address of the contract to call.
   * @param callData The calldata for the call.
   * @return data The abi encoded return data from the call.
   */
  function staticCallWithContextOrRevert(
    address msgSender,
    address target,
    bytes memory callData
  ) internal view returns (bytes memory data) {
    (bool success, bytes memory _data) = staticCallWithContext({
      msgSender: msgSender,
      target: target,
      callData: callData
    });
    if (!success) revertWithBytes(_data);
    return _data;
  }
}
