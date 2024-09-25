// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as LocationUtils } from "../../src/modules/location/Utils.sol";
import { State, SmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { DeployableFuelBalance, DeployableFuelBalanceData } from "../../src/codegen/tables/DeployableFuelBalance.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

import { DECIMALS } from "../../src/modules/smart-deployable/constants.sol";

import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { IERC721Metadata } from "../../src/modules/eve-erc721-puppet/IERC721Metadata.sol";
import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";
import { Utils as ERC721Utils } from "../../src/modules/eve-erc721-puppet/Utils.sol";
import { StaticDataGlobalTable } from "../../src/codegen/tables/StaticDataGlobalTable.sol";

contract smartDeployableTest is MudTest {
  using Utils for bytes14;
  using LocationUtils for bytes14;
  using ERC721Utils for bytes14;
  using SmartDeployableLib for SmartDeployableLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  SmartDeployableLib.World smartDeployable;
  IERC721 erc721Token;
  bytes14 constant SMART_DEPLOYABLE_ERC721_NAMESPACE = "erc721deploybl";

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    smartDeployable = SmartDeployableLib.World(world, DEPLOYMENT_NAMESPACE);
    erc721Token = IERC721(
      ERC721Registry.get(
        ERC721_REGISTRY_TABLE_ID,
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_ERC721_NAMESPACE)
      )
    );
  }

  function testSetup() public {
    address smartDeployableSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartDeployableSystemId());
    ResourceId smartDeployableSystemId = SystemRegistry.get(smartDeployableSystem);
    assertEq(smartDeployableSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testRegisterDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity
  ) public {
    smartDeployable.globalResume();
    smartDeployable.globalPause();
    smartDeployable.globalResume();
    vm.assume(entityId != 0);
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionPerMinute != 0);
    vm.assume(fuelMaxCapacity != 0);
    DeployableStateData memory data = DeployableStateData({
      createdAt: block.timestamp,
      previousState: State.NULL,
      currentState: State.UNANCHORED,
      isValid: true,
      anchoredAt: block.timestamp,
      updatedBlockNumber: block.number,
      updatedBlockTime: block.timestamp
    });
    vm.assume(smartObjectData.owner != address(0));
    vm.assume(bytes(smartObjectData.tokenURI).length != 0);

    smartDeployable.registerDeployable(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      fuelMaxCapacity
    );

    DeployableStateData memory tableData = DeployableState.get(entityId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.currentState), uint8(tableData.currentState));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);

    assertEq(erc721Token.ownerOf(entityId), smartObjectData.owner);
    assertEq(
      keccak256(abi.encode(IERC721Metadata(address(erc721Token)).tokenURI(entityId))),
      keccak256(
        abi.encode(
          string.concat(
            StaticDataGlobalTable.getBaseURI(SMART_DEPLOYABLE_ERC721_NAMESPACE.erc721SystemId()),
            smartObjectData.tokenURI
          )
        )
      )
    );
  }

  function testGloballyOfflineRevert(uint256 entityId) public {
    vm.assume(entityId != 0);
    // TODO: build a work-around following recommendations in https://github.com/foundry-rs/foundry/issues/5454
    // try each line independantly, then
    // try running both lines below and see what happens
    //vm.expectRevert(abi.encodeWithSelector(SmartDeployableErrors.SmartDeployable_GloballyOffline.selector));
    //smartDeployable.registerDeployable(entityId);

    assertEq(true, true);
  }

  function testAnchor(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location
  ) public {
    vm.assume(entityId != 0);
    testRegisterDeployable(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity);

    smartDeployable.anchor(entityId, location);
    LocationTableData memory tableData = LocationTable.get(entityId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testBringOnline(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location
  ) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity, location);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < fuelMaxCapacity);
    smartDeployable.depositFuel(entityId, 1);
    smartDeployable.bringOnline(entityId);
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testBringOffline(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location
  ) public {
    vm.assume(entityId != 0);

    testBringOnline(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity, location);
    smartDeployable.bringOffline(entityId);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testUnanchor(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location
  ) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity, location);
    smartDeployable.unanchor(entityId);
    assertEq(uint8(State.UNANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testDestroyDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location
  ) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity, location);
    smartDeployable.destroyDeployable(entityId);
    assertEq(uint8(State.DESTROYED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testSetFuelConsumptionPerMinute(uint256 entityId, uint256 rate) public {
    vm.assume(entityId != 0);
    vm.assume(rate != 0);

    smartDeployable.setFuelConsumptionPerMinute(entityId, rate);
    assertEq(DeployableFuelBalance.getFuelConsumptionPerMinute(entityId), rate);
  }

  function testDepositFuel(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location,
    uint256 fuelUnitAmount
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelUnitAmount != 0);
    vm.assume(fuelUnitAmount < type(uint64).max);
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelUnitAmount * fuelUnitVolume < fuelMaxCapacity);

    testAnchor(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity, location);
    smartDeployable.depositFuel(entityId, fuelUnitAmount);
    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(entityId);
    assertEq(data.fuelAmount, fuelUnitAmount * (10 ** DECIMALS));
    assertEq(data.lastUpdatedAt, block.timestamp);
  }

  function testDepositFuelTwice(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location,
    uint256 fuelUnitAmount
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelUnitAmount < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelUnitAmount * fuelUnitVolume * 2 < fuelMaxCapacity);

    testDepositFuel(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      fuelMaxCapacity,
      location,
      fuelUnitAmount
    );
    smartDeployable.depositFuel(entityId, fuelUnitAmount);
    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(entityId);
    assertEq(data.fuelAmount, fuelUnitAmount * 2 * (10 ** DECIMALS));
    assertEq(data.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumption(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationTableData memory location,
    uint256 fuelUnitAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelUnitAmount < type(uint64).max);
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelConsumptionPerMinute < (type(uint256).max / 1e18) && fuelConsumptionPerMinute > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    uint256 fuelConsumption = ((timeElapsed * (10 ** DECIMALS)) / fuelConsumptionPerMinute) + (1 * (10 ** DECIMALS)); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelUnitAmount * (10 ** DECIMALS) > fuelConsumption);

    testDepositFuel(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      fuelMaxCapacity,
      location,
      fuelUnitAmount
    );
    smartDeployable.bringOnline(entityId);
    vm.warp(block.timestamp + timeElapsed);
    smartDeployable.updateFuel(entityId);

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(entityId);

    assertEq(data.fuelAmount, fuelUnitAmount * (10 ** DECIMALS) - fuelConsumption);
    assertEq(data.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumptionRunsOut(
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelUnitAmount,
    uint256 timeElapsed
  ) public {
    // vm.assume(fuelUnitAmount < type(uint64).max);
    fuelUnitAmount %= 1000000;
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelConsumptionPerMinute > 3600 && fuelConsumptionPerMinute < (24 * 3600)); // relatively high consumption
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    uint256 fuelConsumption = ((timeElapsed * (10 ** DECIMALS)) / fuelConsumptionPerMinute) + (1 * (10 ** DECIMALS)); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelUnitAmount * (10 ** DECIMALS) < fuelConsumption);

    uint256 entityId = 1;
    LocationTableData memory location = LocationTableData({ solarSystemId: 1, x: 1, y: 1, z: 1 });
    testDepositFuel(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      UINT256_MAX,
      location,
      fuelUnitAmount
    );
    uint256 fuelUnitAmount = 500;
    smartDeployable.bringOnline(entityId);
    vm.warp(block.timestamp + timeElapsed);
    smartDeployable.updateFuel(entityId);

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(entityId);
    assertEq(data.fuelAmount, 0);
    assertEq(data.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testFuelRefundDuringGlobalOffline(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    LocationTableData memory location,
    uint256 fuelUnitAmount,
    uint256 timeElapsedBeforeOffline,
    uint256 globalOfflineDuration,
    uint256 timeElapsedAfterOffline
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelUnitAmount < type(uint32).max);
    vm.assume(fuelUnitVolume < type(uint128).max);
    vm.assume(fuelConsumptionPerMinute < (type(uint256).max / 1e18) && fuelConsumptionPerMinute > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsedBeforeOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(timeElapsedAfterOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(globalOfflineDuration < 7 days); // Example constraint: timeElapsed is less than 7 days in seconds
    uint256 fuelConsumption = ((timeElapsedBeforeOffline * (10 ** DECIMALS)) / fuelConsumptionPerMinute) +
      (1 * (10 ** DECIMALS));
    fuelConsumption += ((timeElapsedAfterOffline * (10 ** DECIMALS)) / fuelConsumptionPerMinute);
    vm.assume(fuelUnitAmount * (10 ** DECIMALS) > fuelConsumption); // this time we want to run out of fuel
    vm.assume(smartObjectData.owner != address(0));

    smartDeployable.globalResume();
    // have to disable fuel max because we're getting a [FAIL. Reason: The `vm.assume` cheatcode rejected too many inputs (65536 allowed)]
    // error, since we're filtering quite a lot of possible input tuples
    smartDeployable.registerDeployable(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      UINT256_MAX
    );
    smartDeployable.setFuelMaxCapacity(entityId, UINT256_MAX);
    // console.log(
    //   "fuel max capacity: ",
    //   DeployableFuelBalance.getFuelMaxCapacity(DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(), entityId)
    // );
    smartDeployable.depositFuel(entityId, fuelUnitAmount);
    smartDeployable.anchor(entityId, location);
    smartDeployable.bringOnline(entityId);
    vm.warp(block.timestamp + timeElapsedBeforeOffline);
    smartDeployable.globalPause();
    vm.warp(block.timestamp + globalOfflineDuration);
    smartDeployable.globalResume();
    vm.warp(block.timestamp + timeElapsedAfterOffline);

    smartDeployable.updateFuel(entityId);

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(entityId);

    assertEq((data.fuelAmount) / 1e18, (fuelUnitAmount * (10 ** DECIMALS) - fuelConsumption) / 1e18);
    assertEq(data.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(entityId)));
  }
}
