// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { STATIC_DATA_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/static-data/Utils.sol";
import { StaticDataLib } from "../../src/modules/static-data/StaticDataLib.sol";
import { StaticDataGlobalTable, StaticDataTable } from "../../src/codegen/index.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";

contract StaticDataTest is MudTest {
  using Utils for bytes14;
  using StaticDataLib for StaticDataLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  StaticDataLib.World staticData;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    staticData = StaticDataLib.World(world, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address staticDataSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.staticDataSystemId());
    ResourceId staticDataSystemId = SystemRegistry.get(staticDataSystem);
    assertEq(staticDataSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testSetBaseURI(ResourceId systemId, string memory newURI) public {
    vm.assume(ResourceId.unwrap(systemId) != bytes32(0));
    vm.assume(bytes(newURI).length != 0);

    staticData.setBaseURI(systemId, newURI);
    assertEq(StaticDataGlobalTable.getBaseURI(systemId), newURI);
  }

  function testSetName(ResourceId systemId, string memory newName) public {
    vm.assume(ResourceId.unwrap(systemId) != bytes32(0));
    vm.assume(bytes(newName).length != 0);

    staticData.setName(systemId, newName);
    assertEq(StaticDataGlobalTable.getName(systemId), newName);
  }

  function testSetSymbol(ResourceId systemId, string memory newSymbol) public {
    vm.assume(ResourceId.unwrap(systemId) != bytes32(0));
    vm.assume(bytes(newSymbol).length != 0);

    staticData.setSymbol(systemId, newSymbol);
    assertEq(StaticDataGlobalTable.getSymbol(systemId), newSymbol);
  }

  function testSetMetadata(
    ResourceId systemId,
    string memory newURI,
    string memory newName,
    string memory newSymbol
  ) public {
    vm.assume(ResourceId.unwrap(systemId) != bytes32(0));
    vm.assume(bytes(newURI).length != 0);
    vm.assume(bytes(newName).length != 0);
    vm.assume(bytes(newSymbol).length != 0);

    staticData.setMetadata(systemId, StaticDataGlobalTableData({ name: newName, symbol: newSymbol, baseURI: newURI }));

    assertEq(StaticDataGlobalTable.getBaseURI(systemId), newURI);
    assertEq(StaticDataGlobalTable.getName(systemId), newName);
    assertEq(StaticDataGlobalTable.getSymbol(systemId), newSymbol);
  }

  function testSetCID(uint256 entityId, string memory newCid) public {
    vm.assume(entityId != 0);
    vm.assume(bytes(newCid).length != 0);

    staticData.setCid(entityId, newCid);
    assertEq(StaticDataTable.getCid(entityId), newCid);
  }

  function testOnlyAdminCanSetBaseURI() public {
    //TODO : Add test case for only admin can set the baseURI after RBAC
  }

  function testOnlyAdminCanSetMetadata() public {
    //TODO : Add test case for only admin can set the metadata after RBAC
  }

  function testOnlyAdminCanSetName() public {
    //TODO : Add test case for only admin can set the name after RBAC
  }

  function testOnlyAdminCanSetSymbol() public {
    //TODO : Add test case for only admin can set the symbol after RBAC
  }

  function testOnlyAdminCanSetCID() public {
    //TODO : Add test case for only admin can set the CID after RBAC
  }
}
