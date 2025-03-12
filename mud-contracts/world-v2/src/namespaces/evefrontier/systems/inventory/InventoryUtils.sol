//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @title Utils used by inventory systems
 */
library InventoryUtils {
  function getAdminAccessRole(uint256 smartObjectId) public pure returns (bytes32) {
    return keccak256(abi.encode("INVENTORY_ADMIN_ACCESS", smartObjectId));
  }

  function getEphemeralToInventoryTransferAccessRole(uint256 smartObjectId) public pure returns (bytes32) {
    return keccak256(abi.encode("INVENTORY_DEPOSIT_ACCESS", smartObjectId));
  }

  function getInventoryToEphemeralTransferAccessRole(uint256 smartObjectId) public pure returns (bytes32) {
    return keccak256(abi.encode("INVENTORY_WITHDRAW_ACCESS", smartObjectId));
  }
}
