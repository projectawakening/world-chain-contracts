// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { Characters, CharactersData } from "../codegen/index.sol";

contract SmartCharacter is System {

  function createCharacter(string memory name, string memory description) public returns (bytes32 key) {
    key = keccak256(abi.encode(block.prevrandao, _msgSender(), description));
    Characters.set(key, CharactersData({name: name, description: description, createdAt: block.timestamp}));
  }


}
