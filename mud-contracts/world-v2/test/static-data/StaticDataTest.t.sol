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
import { StaticData } from "../../src/codegen/index.sol";
import { IStaticDataSystem } from "../../src/codegen/world/IStaticDataSystem.sol";
import { StaticDataSystem } from "../../src/systems/static-data/StaticDataSystem.sol";
import { StaticData } from "../../src/codegen/tables/StaticData.sol";
import { StaticDataMetadata, StaticDataMetadataData } from "../../src/codegen/tables/StaticDataMetadata.sol";

contract StaticDataTest is MudTest {
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

  function testStaticData(uint256 entityId, string memory cid) public {
    vm.assume(entityId != 0);
    bytes4 functionSelector = IStaticDataSystem.eveworld__createStaticData.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.createStaticData, (entityId, cid)));

    string memory storedCid = StaticData.get(entityId);

    assertEq(cid, storedCid);
  }

  function testStaticDataMetadata(
    ResourceId systemId,
    string memory name,
    string memory symbol,
    string memory baseURI
  ) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__createStaticDataMetadata.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.createStaticDataMetadata, (systemId, name, symbol, baseURI)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(systemId);

    assertEq(name, metadata.name);
    assertEq(symbol, metadata.symbol);
    assertEq(baseURI, metadata.baseURI);
  }

  function testSetCid(uint256 entityId, string memory cid) public {
    vm.assume(entityId != 0);
    bytes4 functionSelector = IStaticDataSystem.eveworld__setCid.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.setCid, (entityId, cid)));

    string memory storedCid = StaticData.get(entityId);

    assertEq(cid, storedCid);
  }

  function testSetName(ResourceId systemId, string memory name) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__setName.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.setName, (systemId, name)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(systemId);

    assertEq(name, metadata.name);
  }

  function testSetSymbol(ResourceId systemId, string memory symbol) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__setSymbol.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.setSymbol, (systemId, symbol)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(systemId);

    assertEq(symbol, metadata.symbol);
  }

  function testSetBaseURI(ResourceId systemId, string memory baseURI) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__setBaseURI.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.setBaseURI, (systemId, baseURI)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(systemId);

    assertEq(baseURI, metadata.baseURI);
  }
}
