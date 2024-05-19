// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

struct RootRoleData {
  bytes32 nameBytes32;
  address rootAcct;
  bytes32 roleId;
}

enum EnforcementLevel {
  NULL,
  TRANSIENT,
  ORIGIN,
  TRANSIENT_AND_ORIGIN
}
