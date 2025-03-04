// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { StaticData } from "../../src/namespaces/evefrontier/codegen/tables/StaticData.sol";
import { StaticDataMetadata } from "../../src/namespaces/evefrontier/codegen/tables/StaticDataMetadata.sol";
import { StaticDataSystemLib, staticDataSystem } from "../../src/namespaces/evefrontier/codegen/systems/StaticDataSystemLib.sol";

contract StaticDataTest is MudTest {
  uint256 testClassId = uint256(bytes32("TEST"));
  uint256 smartObjectId = 1234;

  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));

  function setUp() public virtual override {
    super.setUp();
    vm.startPrank(deployer);
    ResourceId[] memory systemIds = new ResourceId[](1);
    systemIds[0] = staticDataSystem.toResourceId();
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

  function testSetBaseURI(string memory baseURI) public {
    vm.startPrank(deployer);
    staticDataSystem.setBaseURI(baseURI);

    string memory baseuri = StaticDataMetadata.get();
    assertEq(baseURI, baseuri);
    vm.stopPrank();
  }

  function testSetCid(string memory cid) public {
    vm.startPrank(deployer);
    entitySystem.instantiate(testClassId, smartObjectId, deployer);
    staticDataSystem.setCid(smartObjectId, cid);

    string memory storedCid = StaticData.get(smartObjectId);
    assertEq(cid, storedCid);
    vm.stopPrank();
  }
}
