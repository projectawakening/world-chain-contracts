// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

struct RolesByContext {
  bytes32[] initialMsgSender;
  bytes32[] mudMsgSender;
  bytes32[] txOrigin;
}

enum EnforcementLevel {
  NULL,
  TRANSIENT_ONLY,
  MUD_ONLY,
  ORIGIN_ONLY,
  TRANSIENT_AND_MUD,
  TRANSIENT_AND_ORIGIN,
  MUD_AND_ORIGIN,
  TRANSIENT_AND_MUD_AND_ORIGIN
}