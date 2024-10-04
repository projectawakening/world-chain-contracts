// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { StaticDataGlobalTableData } from "../../../codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordOffchainTableData } from "../../../codegen/tables/EntityRecordOffchainTable.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";
import { EntityRecordData } from "../types.sol";

interface ISmartCharacterSystem {
  function createCharacter(
    uint256 characterId,
    address characterAddress,
    uint256 corpId,
    EntityRecordData memory entityRecord,
    EntityRecordOffchainTableData memory entityRecordOffchain,
    string memory tokenCid
  ) external;

  function registerERC721Token(address tokenAddress) external;

  function setCharClassId(uint256 classId) external;

  function updateCorpId(uint256 characterId, uint256 corpId) external;
}
