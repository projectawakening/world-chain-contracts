// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { EntityRecord, EntityRecordData as EntityRecordTableData } from "../../src/namespaces/evefrontier/codegen/tables/EntityRecord.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

import { SmartAssembly } from "../../src/namespaces/evefrontier/codegen/tables/SmartAssembly.sol";
import { EntityRecordData } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { SmartAssemblySystemLib, smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";

contract SmartAssemblyTest is MudTest {
  uint256 testClassId = uint256(bytes32("TEST"));
  uint256 smartObjectId = 1234;
  string smartAssemblyType = "SSU";

  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));

  function setUp() public virtual override {
    super.setUp();
    vm.startPrank(deployer);
    ResourceId[] memory systemIds = new ResourceId[](2);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    entitySystem.registerClass(testClassId, systemIds);
    entitySystem.instantiate(testClassId, smartObjectId, deployer);
    vm.stopPrank();
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testCreateSmartAssembly(uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.startPrank(deployer);
    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    smartAssemblySystem.createSmartAssembly(smartObjectId, smartAssemblyType, entityRecordInput);

    EntityRecordTableData memory entityRecord = EntityRecord.get(smartObjectId);

    assertEq(itemId, entityRecord.itemId);
    assertEq(typeId, entityRecord.typeId);
    assertEq(volume, entityRecord.volume);

    assertEq(smartAssemblyType, SmartAssembly.getSmartAssemblyType(smartObjectId));
    vm.stopPrank();
  }

  function testUpdateSmartAssemblyType(uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.startPrank(deployer);
    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    smartAssemblySystem.createSmartAssembly(smartObjectId, smartAssemblyType, entityRecordInput);
    smartAssemblySystem.updateSmartAssemblyType(smartObjectId, smartAssemblyType);

    assertEq("SSU", SmartAssembly.getSmartAssemblyType(smartObjectId));
    vm.stopPrank();
  }

  function testRevertEmptyAssemblyType(uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.startPrank(deployer);
    EntityRecordData memory entityRecordInput = EntityRecordData({ typeId: typeId, itemId: itemId, volume: volume });

    vm.expectRevert(
      abi.encodeWithSelector(SmartAssemblySystemLib.SmartAssemblyTypeCannotBeEmpty.selector, smartObjectId)
    );

    smartAssemblySystem.createSmartAssembly(smartObjectId, "", entityRecordInput);
    vm.stopPrank();
  }

  function testRevertAssemblyDoesNotExist(uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSelector(SmartAssemblySystemLib.SmartAssemblyDoesNotExist.selector, smartObjectId));

    smartAssemblySystem.updateSmartAssemblyType(smartObjectId, smartAssemblyType);
    vm.stopPrank();
  }
}
