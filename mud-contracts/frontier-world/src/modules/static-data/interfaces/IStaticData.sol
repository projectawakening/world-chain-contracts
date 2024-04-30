// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { StaticDataGlobalTableData } from "../../../codegen/tables/StaticDataGlobalTable.sol";

/**
 * @title Interface for Static Data
 * @author CCP Games
 * @notice must match the corresponding StaticData System
 */
interface IStaticData {
  function setBaseURI(ResourceId systemId, string memory baseURI) external;

  function setName(ResourceId systemId, string memory name) external;

  function setSymbol(ResourceId systemId, string memory symbol) external;

  function setMetadata(ResourceId systemId, StaticDataGlobalTableData memory data) external;

  function setCid(uint256 entityId, string memory cid) external;
}
