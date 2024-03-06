// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { Characters, CharactersData } from "../codegen/index.sol";

contract SmartCharacterSystem is System {

  function createCharacter(string memory name) public returns (bytes32 key) {
    key = keccak256(abi.encode(block.prevrandao, _msgSender()));
    Characters.set(key, CharactersData({name: name, createdAt: block.timestamp}));
  }

}
