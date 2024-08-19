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
import { StaticDataMetadata } from "../../src/codegen/tables/StaticDataMetadata.sol";

import { Utils as StaticDataUtils } from "../../src/systems/static-data/Utils.sol";

contract StaticDataTest is MudTest {
  IBaseWorld world;
  using StaticDataUtils for bytes14;

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



  function testSetBaseURI(string memory baseURI) public {
    ResourceId systemId = StaticDataUtils.staticDataSystemId();
    world.call(systemId, abi.encodeCall(StaticDataSystem.setBaseURI, (baseURI)));

    assertEq(cid, storedCid);
  }

  function testStaticDataMetadata(bytes32 classId, string memory name, string memory baseURI) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__createStaticDataMetadata.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.createStaticDataMetadata, (classId, name, baseURI)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(classId);

    assertEq(name, metadata.name);
    assertEq(baseURI, metadata.baseURI);
  }

  function testSetCid(uint256 entityId, string memory cid) public {
    vm.assume(entityId != 0);
    ResourceId systemId = StaticDataUtils.staticDataSystemId();
    world.call(systemId, abi.encodeCall(StaticDataSystem.setCid, (entityId, cid)));

    string memory storedCid = StaticData.get(entityId);

    assertEq(cid, storedCid);
  }

  function testSetName(bytes32 classId, string memory name) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__setName.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.setName, (classId, name)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(classId);

    assertEq(name, metadata.name);
  }

  function testSetBaseURI(bytes32 classId, string memory baseURI) public {
    bytes4 functionSelector = IStaticDataSystem.eveworld__setBaseURI.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(StaticDataSystem.setBaseURI, (classId, baseURI)));

    StaticDataMetadataData memory metadata = StaticDataMetadata.get(classId);

    assertEq(baseURI, metadata.baseURI);
  }
}
