// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { EveSystem } from "../../../src/systems/EveSystem.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";

import { EphemeralInvCapacity } from "../../src/codegen/tables/EphemeralInvCapacity.sol";
import { EphemeralInventorySystem } from "../../src/systems/inventory/EphemeralInventorySystem.sol";
import { EphemeralInv, EphemeralInvData } from "../../src/codegen/tables/EphemeralInv.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../src/codegen/tables/EphemeralInvItem.sol";
import { IInventoryErrors } from "../../src/systems/inventory/IInventoryErrors.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { EntityRecordSystem } from "../../src/systems/entity-record/EntityRecordSystem.sol";

import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { EntityRecordUtils } from "../../src/systems/entity-record/EntityRecordUtils.sol";
import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";

contract VendingMachineTestSystem is EveSystem {
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;

  function interactHandler(uint256 smartObjectId, uint256 quantity) public {
    // NOTE: Store the IN and OUT item details in table by configuring in a seperate function.
  }
}

contract InventoryInteractTest is MudTest {
  IBaseWorld world;
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testInteractHandler() public {}
}
