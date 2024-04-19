// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

/**
 * @title IEntityRecord system
 */
interface IEntityRecord {
  function createEntityRecord(uint256 entityId, uint256 itemId, uint8 typeId, uint256 volume) external;

  function createEntityRecordOffchain(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) external;

  function setEntityMetadata(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) external;

  function setName(
    uint256 entityId,
    string memory name
  ) external;

  function setDappURL(
    uint256 entityId,
    string memory dappURL
  ) external;

  function setDescription(
    uint256 entityId,
    string memory description
  ) external;
}
