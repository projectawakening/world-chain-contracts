// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IWorld } from "./codegen/world/IWorld.sol";

interface IWorldWithEntryContext is IWorld {
  function initialMsgSender() external view returns (address);
}
