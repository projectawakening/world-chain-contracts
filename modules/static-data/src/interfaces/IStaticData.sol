// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

/**
 * @title Interface for Static Data
 * @author CCP Games
 * @notice must match the corresponding StaticData System
 */
interface IStaticData {
  function setBaseURI(ResourceId systemId, string memory baseURI) external;

  function setCid(uint256 entityId, string memory cid) external;
}