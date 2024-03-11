// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { SmartStorageUnits, SmartStorageUnitsData } from "../codegen/index.sol";

contract SmartStorageUnit is System {
  function create_smart_storage_unit(string memory name, string memory description) public returns (bytes32 key) {
    key = keccak256(abi.encode(block.prevrandao, _msgSender(), description));

    SmartStorageUnits.set(
      key,
      SmartStorageUnitsData({ name: name, description: description, createdAt: block.timestamp })
    );
  }
}
