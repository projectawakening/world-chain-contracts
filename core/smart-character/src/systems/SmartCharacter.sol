// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { CharactersTable, CharactersTableData } from "../codegen/index.sol";
import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";

import { Utils } from "../utils.sol";

contract SmartCharacter is EveSystem {
  using Utils for bytes14;

  function createCharacter(string memory name) public returns (bytes32 key) {
    key = keccak256(abi.encode(block.prevrandao, _msgSender()));
    CharactersTable.set(_namespace().charactersTableTableId(), key, CharactersTableData({name: name, createdAt: block.timestamp}));
  }

}
