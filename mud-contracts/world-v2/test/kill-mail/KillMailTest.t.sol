// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIdInstance } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Characters, CharactersByAccount, KillMail, KillMailData } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { KillMailSystem, killMailSystem } from "../../src/namespaces/evefrontier/codegen/systems/KillMailSystemLib.sol";

// Types and parameters
import { KillMailLossType } from "../../src/codegen/common.sol";

contract KillMailTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 killMailId = 12345;

  // alice
  uint256 constant killerCharacterId = 1;
  // bob
  uint256 constant victimCharacterId = 2;

  uint256 constant invalidKillerCharacterId = 3;

  uint256 constant invalidVictimCharacterId = 4;

  KillMailLossType lossType = KillMailLossType.SHIP;
  uint256 constant solarSystemId = 1;
  uint256 constant killTimestamp = 1672531200; // 2023-01-01 00:00:00 UTC

  KillMailData killMailDataParams;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  function setUp() public virtual override {
    vm.pauseGasMetering();
    super.setUp();
    // Deploy a new World
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // Initialize addresses
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));
    alice = vm.addr(vm.deriveKey(mnemonic, 2));
    bob = vm.addr(vm.deriveKey(mnemonic, 3));

    vm.startPrank(deployer);

    // Mock smart character data
    CharactersByAccount.set(alice, 1);
    Characters.set(1, true, 101, block.timestamp);
    CharactersByAccount.set(bob, 2);
    Characters.set(2, true, 202, block.timestamp);

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_reportKill() public {
    vm.startPrank(alice, deployer);
    // Test invalid killer character ID
    killMailDataParams = KillMailData({
      killerCharacterId: invalidKillerCharacterId,
      victimCharacterId: victimCharacterId,
      lossType: lossType,
      solarSystemId: solarSystemId,
      killTimestamp: killTimestamp
    });

    vm.expectRevert(
      abi.encodeWithSelector(KillMailSystem.KillMail_InvalidCharacterId.selector, killMailId, invalidKillerCharacterId)
    );
    killMailSystem.reportKill(killMailId, killMailDataParams);

    // Test invalid victim character ID
    killMailDataParams = KillMailData({
      killerCharacterId: killerCharacterId,
      victimCharacterId: invalidVictimCharacterId,
      lossType: lossType,
      solarSystemId: solarSystemId,
      killTimestamp: killTimestamp
    });

    vm.expectRevert(
      abi.encodeWithSelector(KillMailSystem.KillMail_InvalidCharacterId.selector, killMailId, invalidVictimCharacterId)
    );
    killMailSystem.reportKill(killMailId, killMailDataParams);

    // Verify initial relevant state
    assertEq(KillMail.getKillerCharacterId(killMailId), 0, "killmail data should not exist before reporting");
    assertEq(KillMail.getVictimCharacterId(killMailId), 0, "killmail data should not exist before reporting");
    assertEq(uint8(KillMail.getLossType(killMailId)), 0, "killmail data should not exist before reporting");
    assertEq(KillMail.getSolarSystemId(killMailId), 0, "killmail data should not exist before reporting");
    assertEq(KillMail.getKillTimestamp(killMailId), 0, "killmail data should not exist before reporting");

    // Make successful call
    killMailDataParams = KillMailData({
      killerCharacterId: killerCharacterId,
      victimCharacterId: victimCharacterId,
      lossType: lossType,
      solarSystemId: solarSystemId,
      killTimestamp: killTimestamp
    });

    killMailSystem.reportKill(killMailId, killMailDataParams);

    // Validate correct state changes after execution
    assertEq(KillMail.getKillerCharacterId(killMailId), killerCharacterId, "killer ID should match");
    assertEq(KillMail.getVictimCharacterId(killMailId), victimCharacterId, "victim ID should match");
    assertEq(uint8(KillMail.getLossType(killMailId)), uint8(lossType), "loss type should match");
    assertEq(KillMail.getSolarSystemId(killMailId), solarSystemId, "solar system ID should match");
    assertEq(KillMail.getKillTimestamp(killMailId), killTimestamp, "timestamp should match");

    // Test killmail already exists
    vm.expectRevert(abi.encodeWithSelector(KillMailSystem.KillMail_AlreadyExists.selector, killMailId));
    killMailSystem.reportKill(killMailId, killMailDataParams);

    vm.stopPrank();
  }
}
