// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { EntityRecord } from "../../src/codegen/index.sol";
import { IEntityRecordSystem } from "../../src/codegen/world/IEntityRecordSystem.sol";
import { EntityRecordSystem } from "../../src/systems/entity-record/EntityRecordSystem.sol";
import { EntityRecord, EntityRecordData } from "../../src/codegen/tables/EntityRecord.sol";
import { EntityRecordMetadata, EntityRecordMetadataData } from "../../src/codegen/tables/EntityRecordMetadata.sol";
import { EntityRecordData as EntityRecordInput, EntityMetadata } from "../../src/systems/entity-record/types.sol";

import { EntityRecordUtils } from "../../src/systems/entity-record/EntityRecordUtils.sol";

contract EntityRecordTest is MudTest {
  IBaseWorld world;
  using EntityRecordUtils for bytes14;

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

  function testEntityRecord(uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.assume(entityId != 0);

    ResourceId systemId = EntityRecordUtils.entityRecordSystemId();
    EntityRecordInput memory entityRecordInput = EntityRecordInput({
      entityId: entityId,
      typeId: typeId,
      itemId: itemId,
      volume: volume
    });

    world.call(systemId, abi.encodeCall(EntityRecordSystem.createEntityRecord, (entityRecordInput)));

    EntityRecordData memory entityRecord = EntityRecord.get(entityId);

    assertEq(itemId, entityRecord.itemId);
    assertEq(typeId, entityRecord.typeId);
    assertEq(volume, entityRecord.volume);
  }

  function testEntityRecordMetadata(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public {
    vm.assume(entityId != 0);
    ResourceId systemId = EntityRecordUtils.entityRecordSystemId();
    EntityMetadata memory entityMetadata = EntityMetadata({
      entityId: entityId,
      name: name,
      dappURL: dappURL,
      description: description
    });
    world.call(systemId, abi.encodeCall(EntityRecordSystem.createEntityRecordMetadata, (entityMetadata)));

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(entityId);

    assertEq(name, entityRecordMetaData.name);
    assertEq(dappURL, entityRecordMetaData.dappURL);
    assertEq(description, entityRecordMetaData.description);
  }

  function testSetName(uint256 entityId, string memory name) public {
    vm.assume(entityId != 0);
    ResourceId systemId = EntityRecordUtils.entityRecordSystemId();
    world.call(systemId, abi.encodeCall(EntityRecordSystem.setName, (entityId, name)));

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(entityId);

    assertEq(name, entityRecordMetaData.name);
  }
}
