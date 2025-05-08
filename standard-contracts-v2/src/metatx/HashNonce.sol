// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Provides a hash-based nonce system for addresses.
 */
contract HashNonce {
  /**
   * @dev The nonce for the `account` is already used
   */
  error InvalidAccountNonce(address account, uint256 currentNonce);

  mapping(address => mapping(uint256 => bool)) private _nonces;

  /**
   * @dev Returns the current nonce hash for an address.
   */
  function isNonceUsed(address owner, uint256 data) public view virtual returns (bool) {
    return _nonces[owner][data];
  }

  /**
   * @dev Consumes a new nonce hash for an address.
   */
  function _useNonce(address owner, uint256 data) internal {
    if (_nonces[owner][data] == true) {
      revert InvalidAccountNonce(owner, data);
    }
    _nonces[owner][data] = true;
  }
}
