// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @title Id type definition and related utilities
 * @author CCP Games (inspired by the Lattice teams's ResourceId type definition)
 * @dev An Id is a bytes32 data structure that consists of a
 * shared type and a unique identifier
 */
type Id is bytes32;

using IdInstance for Id global;


/// @dev Number of bits reserved for the type in the ID.
uint256 constant TYPE_BITS = 2 * 8; // 2 bytes * 8 bits per byte

/**
 * @title IdLib Library
 * @author CCP Games (inspired by the Lattice team's ResourceId.sol and accompanying libraries)
 * @dev Provides functions to encode data into an Id
 */
library IdLib {
  /**
   * @notice Encodes given type and identifier into an Id.
   * @param typeId The shared type to be encoded. Must be 2 bytes.
   * @param identifier The unique identifier to be encoded. Must be 30 bytes.
   * @return An Id containing the encoded type and identifier.
   */
  function encode(bytes2 typeId, bytes30 identifier) internal pure returns (Id) {
    return Id.wrap(bytes32(typeId) | (bytes32(identifier) >> TYPE_BITS));
  }
}

/**
 * @title IdInstance Library
 * @author CCP Games (inspired by the Lattice team's ResourceIdInstance)
 * @dev Provides functions to extract data from an Id.
 */
library IdInstance {
  /**
   * @notice Extracts the shared type from a given Id.
   * @param id The Id from which the type should be extracted.
   * @return The extracted 2-byte type.
   */
  function getType(Id id) internal pure returns (bytes2) {
    return bytes2(Id.unwrap(id));
  }

  /**
   * @notice Get the unique indentifier bytes from an Id.
   * @param id The Id.
   * @return the extracted 30-bytes unique identifier.
   */
  function getIdentifier(Id id) internal pure returns (bytes30) {
    return bytes30(Id.unwrap(id) << (TYPE_BITS));
  }
}