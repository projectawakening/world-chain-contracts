// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { IHookableMock } from "./IHookableMock.sol";
import { HOOKABLE_MOCK_SYSTEM_ID } from "./mockconstants.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";


contract ForwardMock is EveSystem {
  function callTarget(uint256 entityId) public returns (bool) {
    // console.log("EXECUTED");
    bytes memory data = world().call(
      HOOKABLE_MOCK_SYSTEM_ID,
      abi.encodeCall(IHookableMock.target,
        (entityId)
      )
    );
    if (abi.decode(data, (bool)))
    return true;
  }
}