// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title ObjectIdLib
 * @notice A library for calculating object identifiers in Eve Frontier
 * @dev Provides deterministic ID generation for both singleton and non-singleton objects
 */
library ObjectIdLib {
  /**
   * @notice Calculate an object ID based on type, item, and singleton status
   * @param tenantId The tenant ID for the calculation
   * @return The calculated object ID
   */
  function calculateObjectId(bytes32 tenantId, uint256 objectId) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tenantId, objectId)));
  }
}
