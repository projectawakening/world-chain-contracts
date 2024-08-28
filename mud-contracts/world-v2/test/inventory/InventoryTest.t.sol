// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";

import { IInventoryErrors } from "../../src/systems/inventory/IInventoryErrors.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { EntityRecordSystem } from "../../src/systems/entity-record/EntityRecordSystem.sol";

import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { EntityRecordUtils } from "../../src/systems/entity-record/EntityRecordUtils.sol";
import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";

contract InventoryTest is MudTest {
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;

  IBaseWorld world;

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
}
