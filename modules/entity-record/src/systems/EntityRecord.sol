// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eve/smart-object-framework/src/SmartObjectLib.sol";

import { Utils } from "../utils.sol";

contract EntityRecord is EveSystem {
  using Utils for bytes14;

  function createEntityRecord(string memory name) public returns (bytes32 key) {
    key = keccak256(abi.encode(block.prevrandao, _msgSender()));
    CharactersTable.set(_namespace().charactersTableTableId(), key, CharactersTableData({name: name, createdAt: block.timestamp}));
  }
}