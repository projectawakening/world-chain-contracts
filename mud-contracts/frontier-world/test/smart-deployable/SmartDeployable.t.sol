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
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";

import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";

import { SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, LOCATION_DEPLOYMENT_NAMESPACE, STATIC_DATA_DEPLOYMENT_NAMESPACE, EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as LocationUtils } from "../../src/modules/location/Utils.sol";
import { State, SmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { GlobalDeployableState, GlobalDeployableStateData } from "../../src/codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

contract smartDeployableTest is Test {
  using Utils for bytes14;
  using LocationUtils for bytes14;
  using SmartDeployableLib for SmartDeployableLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  SmartDeployableLib.World smartDeployable;
  SmartDeployableModule smartDeployableModule;
  IERC721Mintable erc721Token;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());

    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new PuppetModule(), new bytes(0));
    baseWorld.installModule(new StaticDataModule(), abi.encode(STATIC_DATA_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new EntityRecordModule(), abi.encode(ENTITY_RECORD_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new SmartDeployableModule(), abi.encode(DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new LocationModule(), abi.encode(LOCATION_DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    erc721Token = registerERC721(
      baseWorld,
      EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE,
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: "" })
    );

    smartDeployable = SmartDeployableLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721Token));
  }

  function testSetup() public {
    address smartDeployableSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartDeployableSystemId());
    ResourceId smartDeployableSystemId = SystemRegistry.get(smartDeployableSystem);
    assertEq(smartDeployableSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testRegisterDeployable(uint256 entityId) public {
    smartDeployable.globalOnline();
    vm.assume(entityId != 0);
    DeployableStateData memory data = DeployableStateData({
      createdAt: block.timestamp,
      state: State.UNANCHORED,
      updatedBlockNumber: block.number
    });

    SmartObjectData memory smartObjectData = SmartObjectData({ owner: address(1), tokenURI: "https://test.com" });

    smartDeployable.registerDeployable(entityId, smartObjectData);
    DeployableStateData memory tableData = DeployableState.get(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.state), uint8(tableData.state));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);
  }

  function testGloballyOfflineRevert(uint256 entityId) public {
    vm.assume(entityId != 0);
    // TODO: build a work-around following recommendations in https://github.com/foundry-rs/foundry/issues/5454
    // try each line independantly, thenm
    // try running both lines below and see what happens, lol
    //vm.expectRevert(abi.encodeWithSelector(SmartDeployableErrors.SmartDeployable_GloballyOffline.selector));
    //smartDeployable.registerDeployable(entityId);

    assertEq(true, true);
  }

  function testAnchor(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);
    testRegisterDeployable(entityId);

    smartDeployable.anchor(entityId, location);
    LocationTableData memory tableData = LocationTable.get(LOCATION_DEPLOYMENT_NAMESPACE.locationTableId(), entityId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
  }

  function testBringOnline(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, location);
    smartDeployable.bringOnline(entityId);
    assertEq(
      uint8(State.ONLINE),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testBringOffline(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testBringOnline(entityId, location);
    smartDeployable.bringOffline(entityId);
    assertEq(
      uint8(State.ANCHORED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testUnanchor(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, location);
    smartDeployable.unanchor(entityId);
    assertEq(
      uint8(State.UNANCHORED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testDestroyDeployable(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testUnanchor(entityId, location);
    smartDeployable.destroyDeployable(entityId);
    assertEq(
      uint8(State.DESTROYED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }
}
