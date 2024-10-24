// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";

import { EntityRecord, EntityRecordData as EntityRecordTableData } from "../../src/codegen/tables/EntityRecord.sol";
import { SmartAssembly } from "../../src/codegen/index.sol";
import { EntityRecordData } from "../../src/systems/entity-record/types.sol";
import { SmartAssemblyUtils } from "../../src/systems/smart-assembly/SmartAssemblyUtils.sol";
import { SmartAssemblySystem } from "../../src/systems/smart-assembly/SmartAssemblySystem.sol";

contract SmartAssemblyTest is MudTest {
  IBaseWorld world;

  ResourceId systemId = SmartAssemblyUtils.smartAssemblySystemId();

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

  function testCreateSmartAssembly(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 itemId,
    uint256 typeId,
    uint256 volume
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));

    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    world.call(
      systemId,
      abi.encodeCall(SmartAssemblySystem.createSmartAssembly, (smartObjectId, smartAssemblyType, entityRecordInput))
    );

    EntityRecordTableData memory entityRecord = EntityRecord.get(smartObjectId);

    assertEq(itemId, entityRecord.itemId);
    assertEq(typeId, entityRecord.typeId);
    assertEq(volume, entityRecord.volume);

    assertEq(smartAssemblyType, SmartAssembly.getSmartAssemblyType(smartObjectId));
  }

  function testUpdateSmartAssemblyType(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 itemId,
    uint256 typeId,
    uint256 volume
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));

    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    world.call(
      systemId,
      abi.encodeCall(SmartAssemblySystem.createSmartAssembly, (smartObjectId, smartAssemblyType, entityRecordInput))
    );

    smartAssemblyType = "SSU";

    world.call(
      systemId,
      abi.encodeCall(SmartAssemblySystem.updateSmartAssemblyType, (smartObjectId, smartAssemblyType))
    );

    assertEq("SSU", SmartAssembly.getSmartAssemblyType(smartObjectId));
  }

  function testRevertEmptyAssemblyType(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 itemId,
    uint256 typeId,
    uint256 volume
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) == keccak256(abi.encodePacked(""))));

    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    vm.expectRevert(abi.encodeWithSelector(SmartAssemblySystem.SmartAssemblyTypeCannotBeEmpty.selector, smartObjectId));

    world.call(
      systemId,
      abi.encodeCall(SmartAssemblySystem.createSmartAssembly, (smartObjectId, smartAssemblyType, entityRecordInput))
    );
  }

  function testRevertAssemblyDoesNotExist(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    uint256 itemId,
    uint256 typeId,
    uint256 volume
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));

    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    vm.expectRevert(abi.encodeWithSelector(SmartAssemblySystem.SmartAssemblyDoesNotExist.selector, smartObjectId));

    world.call(
      systemId,
      abi.encodeCall(SmartAssemblySystem.updateSmartAssemblyType, (smartObjectId, smartAssemblyType))
    );
  }
}
