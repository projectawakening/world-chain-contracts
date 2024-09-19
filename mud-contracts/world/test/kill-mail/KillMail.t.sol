// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { Utils } from "../../src/modules/kill-mail/Utils.sol";
import { KillMailLib } from "../../src/modules/kill-mail/KillMailLib.sol";
import { KillMailModule } from "../../src/modules/kill-mail/KillMailModule.sol";
import { KILL_MAIL_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "../../src/modules/kill-mail/constants.sol";
import { KillMailLossType } from "../../src/codegen/common.sol";
import { KillMailTable, KillMailTableData } from "../../src/codegen/tables/KillMailTable.sol";

import "forge-std/Test.sol";

contract KillMailTest is Test {
  using Utils for bytes14;
  using KillMailLib for KillMailLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  KillMailLib.World killMail;

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    StoreSwitch.setStoreAddress(address(world));

    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );

    _installModule(new KillMailModule(), DEPLOYMENT_NAMESPACE);

    killMail = KillMailLib.World(world, DEPLOYMENT_NAMESPACE);
  }

  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this)) {
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    }

    world.installModule(module, abi.encode(namespace));
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

    KillMailTableData memory storedKillMailTableData = KillMailTable.get(
      DEPLOYMENT_NAMESPACE.killMailTableId(),
      killMailId
    );

    assertEq(killMailTableData.killerCharacterId, storedKillMailTableData.killerCharacterId);
    assertEq(killMailTableData.victimCharacterId, storedKillMailTableData.victimCharacterId);
    assertEq(killMailTableData.killTimestamp, storedKillMailTableData.killTimestamp);
  }
}
