// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { Utils } from "../../src/modules/kill-mail/Utils.sol";
import { KillMailLib } from "../../src/modules/kill-mail/KillMailLib.sol";
import { KILL_MAIL_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "../../src/modules/kill-mail/constants.sol";
import { KillMailLossType } from "../../src/codegen/common.sol";
import { KillMailTable, KillMailTableData } from "../../src/codegen/tables/KillMailTable.sol";

contract KillMailTest is MudTest {
  using Utils for bytes14;
  using KillMailLib for KillMailLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  KillMailLib.World killMail;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    killMail = KillMailLib.World(world, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address killMailSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.killMailSystemId());
    ResourceId killMailSystemId = SystemRegistry.get(killMailSystem);
    assertEq(killMailSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testRegisterKill(
    uint256 killMailId,
    uint256 killerCharacterId,
    uint256 victimCharacterId,
    uint256 solarSystemId,
    uint256 killTimestamp
  ) public {
    vm.assume(killMailId != 0);

    KillMailLossType lossType = KillMailLossType.SHIP;

    KillMailTableData memory killMailTableData = KillMailTableData({
      killerCharacterId: killerCharacterId,
      victimCharacterId: victimCharacterId,
      lossType: lossType,
      solarSystemId: solarSystemId,
      killTimestamp: killTimestamp
    });

    killMail.reportKill(killMailId, killMailTableData);

    KillMailTableData memory storedKillMailTableData = KillMailTable.get(killMailId);

    assertEq(killMailTableData.killerCharacterId, storedKillMailTableData.killerCharacterId);
    assertEq(killMailTableData.victimCharacterId, storedKillMailTableData.victimCharacterId);
    assertEq(killMailTableData.killTimestamp, storedKillMailTableData.killTimestamp);
  }
}
