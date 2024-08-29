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
import { IStaticDataSystem } from "../../src/codegen/world/IStaticDataSystem.sol";
import { StaticData, StaticDataMetadata } from "../../src/namespaces/eveworld/codegen/index.sol";
import { StaticDataSystem } from "../../src/namespaces/eveworld/systems/static-data/StaticDataSystem.sol";

import { Utils as StaticDataUtils } from "../../src/namespaces/eveworld/systems/static-data/Utils.sol";

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

    string memory baseuri = StaticDataMetadata.get();
    assertEq(baseURI, baseuri);
  }

  function testSetCid(uint256 entityId, string memory cid) public {
    vm.assume(entityId != 0);
    ResourceId systemId = StaticDataUtils.staticDataSystemId();
    world.call(systemId, abi.encodeCall(StaticDataSystem.setCid, (entityId, cid)));

    string memory storedCid = StaticData.get(entityId);

    assertEq(cid, storedCid);
  }
}
