// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/entity-record/Utils.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

contract EntityRecordTest is MudTest {
  using Utils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  EntityRecordLib.World entityRecord;

  function setUp() public override {
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    entityRecord = EntityRecordLib.World(world, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address entityRecordSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.entityRecordSystemId());
    ResourceId entityRecordSystemId = SystemRegistry.get(entityRecordSystem);
    assertEq(entityRecordSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testCreateEntityRecord(uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) public {
    vm.assume(entityId != 0);
    EntityRecordTableData memory data = EntityRecordTableData({
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      recordExists: true
    });

    entityRecord.createEntityRecord(entityId, itemId, typeId, volume);
    EntityRecordTableData memory tableData = EntityRecordTable.get(entityId);

    assertEq(data.itemId, tableData.itemId);
    assertEq(data.typeId, tableData.typeId);
    assertEq(data.volume, tableData.volume);
  }

  function testCreateEntityRecordOffchain(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(name).length != 0);
    vm.assume(bytes(dappURL).length != 0);
    vm.assume(bytes(description).length != 0);
    EntityRecordOffchainTableData memory data = EntityRecordOffchainTableData({
      name: name,
      dappURL: dappURL,
      description: description
    });

    entityRecord.createEntityRecordOffchain(entityId, name, dappURL, description);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(entityId);

    assertEq(data.name, tableData.name);
    assertEq(data.dappURL, tableData.dappURL);
    assertEq(data.description, tableData.description);
  }

  function testSetEntityRecordOffchain(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(name).length != 0);
    vm.assume(bytes(dappURL).length != 0);
    vm.assume(bytes(description).length != 0);
    EntityRecordOffchainTableData memory data = EntityRecordOffchainTableData({
      name: name,
      dappURL: dappURL,
      description: description
    });

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setEntityMetadata(entityId, name, dappURL, description);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(entityId);

    assertEq(data.name, tableData.name);
    assertEq(data.dappURL, tableData.dappURL);
    assertEq(data.description, tableData.description);
  }

  function testSetEntityRecordName(uint256 entityId, string memory name) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(name).length != 0);

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setName(entityId, name);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(entityId);

    assertEq(name, tableData.name);
  }

  function testSetEntityRecordDappURL(uint256 entityId, string memory dappURL) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(dappURL).length != 0);

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setDappURL(entityId, dappURL);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(entityId);

    assertEq(dappURL, tableData.dappURL);
  }

  function testSetEntityRecordDescription(uint256 entityId, string memory description) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(description).length != 0);

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setDescription(entityId, description);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(entityId);

    assertEq(description, tableData.description);
  }
}
