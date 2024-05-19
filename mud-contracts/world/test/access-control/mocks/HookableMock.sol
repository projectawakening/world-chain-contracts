// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { HOOKABLE_MOCK_SYSTEM_ID } from "./mockconstants.sol";

contract HookableMock is EveSystem {
  /**
   * @dev Conforming to the hookable standard means you should always include the `entityId` of the hook target as the
   *   first parameter.
   * Any parameter values from the original target function calldata will get passed to hooks automatically in abi.encodePacked format
   */
  function target(uint256 entityId) public hookable(entityId, _systemId()) returns (bool) {
    return true;
  }

  // // example hookdata
  // struct HookData {
  //   uint256[] hookIds; // include this param to check in your hook logic if your hook should use the bytes hookdata field
  //   string test;
  //   // pass custom parameters to one(or more) hooks as they execute
  // }
  // // abi.encode a struct and create a bytes field in your target function to pass user based input data to hook logic
  // HookData testdata = HookData(1, "TEST");
  // bytes hookdata = abi.encode(testData);

  // function targetWithBytes(uint256 entityId, bytes hookdata) public hookable(entityId, systemId()) {
  //   return;
  // }

  function _systemId() internal pure returns (ResourceId) {
    return HOOKABLE_MOCK_SYSTEM_ID;
  }
}
