// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { EntityRecord } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { EntityRecord, EntityRecordData } from "../../src/namespaces/evefrontier/codegen/tables/EntityRecord.sol";
import { EntityRecordMetadata, EntityRecordMetadataData } from "../../src/namespaces/evefrontier/codegen/tables/EntityRecordMetadata.sol";
import { EntityRecordData as EntityRecordInput, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";

contract EntityRecordTest is MudTest {
  uint256 smartObjectId = 1234;
  string name = "name";
  string dappURL = "dappURL";
  string description = "description";
  uint256 testClassId = uint256(bytes32("TEST"));

  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));

  function setUp() public virtual override {
    super.setUp();
    vm.startPrank(deployer);
    ResourceId[] memory systemIds = new ResourceId[](1);
    systemIds[0] = entityRecordSystem.toResourceId();
    entitySystem.registerClass(testClassId, systemIds);
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

  function testEntityRecord(uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.startPrank(deployer);
    entitySystem.instantiate(testClassId, smartObjectId, deployer);
    EntityRecordInput memory entityRecordInput = EntityRecordInput({ typeId: typeId, itemId: itemId, volume: volume });

    entityRecordSystem.createEntityRecord(smartObjectId, entityRecordInput);
    EntityRecordData memory entityRecord = EntityRecord.get(smartObjectId);

    assertEq(itemId, entityRecord.itemId);
    assertEq(typeId, entityRecord.typeId);
    assertEq(volume, entityRecord.volume);
    vm.stopPrank();
  }

  function testEntityRecordMetadata() public {
    vm.startPrank(deployer);
    entitySystem.instantiate(testClassId, smartObjectId, deployer);
    EntityMetadata memory entityMetadata = EntityMetadata({ name: name, dappURL: dappURL, description: description });

    entityRecordSystem.createEntityRecordMetadata(smartObjectId, entityMetadata);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(name, entityRecordMetaData.name);
    assertEq(dappURL, entityRecordMetaData.dappURL);
    assertEq(description, entityRecordMetaData.description);
    vm.stopPrank();
  }

  function testSetName() public {
    vm.startPrank(deployer);
    entitySystem.instantiate(testClassId, smartObjectId, deployer);
    entityRecordSystem.setName(smartObjectId, name);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartObjectId);

    assertEq(name, entityRecordMetaData.name);
    vm.stopPrank();
  }
}
