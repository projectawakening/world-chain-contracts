// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

struct TransientContext {
  ResourceId systemId;
  bytes4 functionId;
  address msgSender;
  uint256 msgValue;
}
