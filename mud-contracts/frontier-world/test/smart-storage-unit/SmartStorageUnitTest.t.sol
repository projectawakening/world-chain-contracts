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
import { SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { ERC721Module } from "../../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IERC721Metadata } from "../../src/modules/eve-erc721-puppet/IERC721Metadata.sol";
import { SmartStorageUnitModule } from "../../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";

import { Utils as SmartStorageUnitUtils } from "../../src/modules/smart-storage-unit/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

contract SmartStorageUnitTest is Test {
  using SmartStorageUnitUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  SmartStorageUnitLib.World smartStorageUnit;
  IERC721Mintable erc721Token;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE));

    // install module dependancies
    baseWorld.installModule(new PuppetModule(), new bytes(0));
    baseWorld.installModule(new StaticDataModule(), abi.encode(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new EntityRecordModule(), abi.encode(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new SmartDeployableModule(), abi.encode(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    erc721Token = registerERC721(
      baseWorld,
      SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE,
      StaticDataGlobalTableData({ name: "SmartStorageUnit", symbol: "SSU", baseURI: "" })
    );

    baseWorld.installModule(new SmartStorageUnitModule(), abi.encode(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE));
    smartStorageUnit = SmartStorageUnitLib.World(baseWorld, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address smartStorageUnitSystem = Systems.getSystem(
      SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId()
    );
    ResourceId smartStorageUnitSystemId = SystemRegistry.get(smartStorageUnitSystem);
    assertEq(smartStorageUnitSystemId.getNamespace(), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);
  }
}
