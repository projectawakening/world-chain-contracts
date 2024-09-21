// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

interface IAccessSystem {
  function setAccessListByRole(bytes32 accessRoleId, address[] memory accessList) external;

  function setAccessListPerSystemByRole(
    ResourceId systemId,
    bytes32 accessRoleId,
    address[] memory accessList
  ) external;

  function setAccessEnforcement(bytes32 target, bool isEnforced) external;
}
