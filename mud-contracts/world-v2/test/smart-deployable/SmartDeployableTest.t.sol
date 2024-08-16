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
import { State } from "../../src/codegen/common.sol";
import { GlobalDeployableState, DeployableState, DeployableTokenTable } from "../../src/codegen/index.sol";
import { ISmartDeployableSystem } from "../../src/codegen/world/ISmartDeployableSystem.sol";
import { SmartDeployableSystem } from "../../src/systems/smart-deployable/SmartDeployableSystem.sol";
import { GlobalDeployableStateData } from "../../src/codegen/tables/GlobalDeployableState.sol";
import { DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";

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

  function testSetGlobalDeployableState(
    uint256 updatedBlockNumber,
    bool isPaused,
    uint256 lastGlobalOffline,
    uint256 lastGlobalOnline
  ) public {
    bytes4 functionSelector = ISmartDeployableSystem.eveworld__setGlobalDeployableState.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(
        SmartDeployableSystem.setGlobalDeployableState,
        (updatedBlockNumber, isPaused, lastGlobalOffline, lastGlobalOnline)
      )
    );

    GlobalDeployableStateData memory globalDeployableState = GlobalDeployableState.get(updatedBlockNumber);

    assertEq(isPaused, globalDeployableState.isPaused);
    assertEq(lastGlobalOffline, globalDeployableState.lastGlobalOffline);
    assertEq(lastGlobalOnline, globalDeployableState.lastGlobalOnline);
  }

  function testSetIsPausedGlobalState(uint256 updatedBlockNumber, bool isPaused) public {
    bytes4 functionSelector = ISmartDeployableSystem.eveworld__setIsPausedGlobalState.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(SmartDeployableSystem.setIsPausedGlobalState, (updatedBlockNumber, isPaused)));

    GlobalDeployableStateData memory globalDeployableState = GlobalDeployableState.get(updatedBlockNumber);

    assertEq(isPaused, globalDeployableState.isPaused);
  }

  function testSetLastGlobalOffline(uint256 updatedBlockNumber, uint256 lastGlobalOffline) public {
    bytes4 functionSelector = ISmartDeployableSystem.eveworld__setLastGlobalOffline.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(SmartDeployableSystem.setLastGlobalOffline, (updatedBlockNumber, lastGlobalOffline))
    );

    GlobalDeployableStateData memory globalDeployableState = GlobalDeployableState.get(updatedBlockNumber);

    assertEq(lastGlobalOffline, globalDeployableState.lastGlobalOffline);
  }

  function testSetLastGlobalOnline(uint256 updatedBlockNumber, uint256 lastGlobalOnline) public {
    bytes4 functionSelector = ISmartDeployableSystem.eveworld__setLastGlobalOnline.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(SmartDeployableSystem.setLastGlobalOnline, (updatedBlockNumber, lastGlobalOnline))
    );

    GlobalDeployableStateData memory globalDeployableState = GlobalDeployableState.get(updatedBlockNumber);

    assertEq(lastGlobalOnline, globalDeployableState.lastGlobalOnline);
  }
}
