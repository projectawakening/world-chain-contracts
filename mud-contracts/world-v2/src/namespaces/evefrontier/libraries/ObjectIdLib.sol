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
   * @param typeId The type ID of the object
   * @param itemId The item ID of the object
   * @param isSingleton Whether the object is a singleton
   * @return The calculated object ID
   */
  function calculateObjectId(
    bytes32 tenantId,
    uint256 typeId,
    uint256 itemId,
    bool isSingleton
  ) public pure returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of tenantId and typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }

  /**
   * @notice Calculate a singleton object ID
   * @param tenantId The tenant ID for the calculation
   * @param itemId The item ID of the object
   * @return The calculated singleton object ID
   */
  function calculateSingletonId(bytes32 tenantId, uint256 itemId) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
  }

  /**
   * @notice Calculate a non-singleton object ID
   * @param tenantId The tenant ID for the calculation
   * @param typeId The type ID of the object
   * @return The calculated non-singleton object ID
   */
  function calculateNonSingletonId(bytes32 tenantId, uint256 typeId) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
  }
}
