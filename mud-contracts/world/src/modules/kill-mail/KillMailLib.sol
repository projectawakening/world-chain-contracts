// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { KillMailTableData } from "../../codegen/tables/KillMailTable.sol";
import { KillMailLossType } from "../../codegen/common.sol";
import { IKillMailSystem } from "./interfaces/IKillMailSystem.sol";
import { Utils } from "./Utils.sol";

library KillMailLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function reportKill(World memory world, uint256 killMailId, KillMailTableData memory killMailTableData) internal {
    world.iface.call(
      world.namespace.killMailSystemId(),
      abi.encodeCall(IKillMailSystem.reportKill, (killMailId, killMailTableData))
    );
  }
}
