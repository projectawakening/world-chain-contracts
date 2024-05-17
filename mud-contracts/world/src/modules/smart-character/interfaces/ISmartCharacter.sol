// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { StaticDataGlobalTableData } from "../../../codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordOffchainTableData } from "../../../codegen/tables/EntityRecordOffchainTable.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";

interface ISmartCharacter {
  function createCharacter(
    uint256 characterId,
    address characterAddress,
    EntityRecordTableData memory entityRecord,
    EntityRecordOffchainTableData memory entityRecordOffchain,
    string memory tokenCid
  ) external;

  function registerERC721Token(address tokenAddress) external;
}
