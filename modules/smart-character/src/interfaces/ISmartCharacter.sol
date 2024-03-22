// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { EntityRecordTableData } from "@eve/entity-record/src/codegen/tables/EntityRecordTable.sol";
import { SmartObjectData } from "../types.sol";

import { StaticDataGlobalTableData } from "@eve/static-data/src/codegen/tables/StaticDataGlobalTable.sol";
import { IERC721Mintable } from "@eve/eve-erc721-puppet/src/IERC721Mintable.sol";

interface ISmartCharacter {
  function createCharacter(
    uint256 characterId,
    EntityRecordTableData memory entityRecord,
    string memory tokenURI
  ) external;

  function registerERC721Token(address tokenAddress) external;
}