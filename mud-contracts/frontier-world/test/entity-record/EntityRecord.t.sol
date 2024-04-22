// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";

import { Utils } from "../../src/modules/entity-record/Utils.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

contract EntityRecordTest is Test {
  using Utils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  EntityRecordLib.World entityRecord;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new EntityRecordModule(), abi.encode(DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    entityRecord = EntityRecordLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
  }

  function testSOFDeploymentCost() public {
        baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    //baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE));
  }

  function testSetup() public {
    address entityRecordSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.entityRecordSystemId());
    ResourceId entityRecordSystemId = SystemRegistry.get(entityRecordSystem);
    assertEq(entityRecordSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testCreateEntityRecord(uint256 entityId, uint256 itemId, uint8 typeId, uint256 volume) public {
    vm.assume(entityId != 0);
    EntityRecordTableData memory data = EntityRecordTableData({ itemId: itemId, typeId: typeId, volume: volume });

    entityRecord.createEntityRecord(entityId, itemId, typeId, volume);
    EntityRecordTableData memory tableData = EntityRecordTable.get(
      DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      entityId
    );

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
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(
      DEPLOYMENT_NAMESPACE.entityRecordOffchainTableId(),
      entityId
    );

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
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(
      DEPLOYMENT_NAMESPACE.entityRecordOffchainTableId(),
      entityId
    );

    assertEq(data.name, tableData.name);
    assertEq(data.dappURL, tableData.dappURL);
    assertEq(data.description, tableData.description);
  }

  function testSetEntityRecordName(
    uint256 entityId,
    string memory name
  ) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(name).length != 0);

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setName(entityId, name);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(
      DEPLOYMENT_NAMESPACE.entityRecordOffchainTableId(),
      entityId
    );

    assertEq(name, tableData.name);
  }

  function testSetEntityRecordDappURL(
    uint256 entityId,
    string memory dappURL
  ) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(dappURL).length != 0);

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setDappURL(entityId, dappURL);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(
      DEPLOYMENT_NAMESPACE.entityRecordOffchainTableId(),
      entityId
    );

    assertEq(dappURL, tableData.dappURL);
  }

  function testSetEntityRecordDescription(
    uint256 entityId,
    string memory description
  ) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(description).length != 0);

    testCreateEntityRecordOffchain(entityId, "name", "dappURL.com", "descriptive description");

    entityRecord.setDescription(entityId, description);
    EntityRecordOffchainTableData memory tableData = EntityRecordOffchainTable.get(
      DEPLOYMENT_NAMESPACE.entityRecordOffchainTableId(),
      entityId
    );

    assertEq(description, tableData.description);
  }
}
