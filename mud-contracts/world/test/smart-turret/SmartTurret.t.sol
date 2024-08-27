// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { SMART_TURRET_DEPLOYMENT_NAMESPACE, EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE, LOCATION_DEPLOYMENT_NAMESPACE, STATIC_DATA_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { ERC721Module } from "../../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IERC721Metadata } from "../../src/modules/eve-erc721-puppet/IERC721Metadata.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";

import { ISmartTurret } from "../../src/modules/smart-turret/interfaces/ISmartTurret.sol";
import { Utils as SmartTurretUtils } from "../../src/modules/smart-turret/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { SmartTurretModule } from "../../src/modules/smart-turret/SmartTurretModule.sol";
import { SmartTurretLib } from "../../src/modules/smart-turret/SmartTurretLib.sol";
import { Target } from "../../src/modules/smart-turret/types.sol";
import { SmartTurret as SmartTurrertSystem } from "../../src/modules/smart-turret/systems/SmartTurret.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityTable, EntityTableData } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { EntityMap } from "@eveworld/smart-object-framework/src/codegen/tables/EntityMap.sol";
import { Utils as SmartObjectUtils } from "@eveworld/smart-object-framework/src/utils.sol";

contract SmartTurretTestSystem is System {
  function inProximity(
    uint256 smartTurretId,
    uint256 characterId,
    Target[] memory targetQueue,
    uint256 remainingAmmo,
    uint256 hpRatio
  ) public returns (Target[] memory returnTargetQueue) {
    return targetQueue;
  }
}

contract SmartTurret is Test {
  using SmartTurretUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartObjectUtils for bytes14;
  using SmartTurretLib for SmartTurretLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;

  IBaseWorld world;
  SmartTurretLib.World smartTurret;
  SmartDeployableLib.World smartDeployable;
  IERC721Mintable erc721Token;
  SmartObjectLib.World SOFInterface;

  bytes14 constant SMART_TURRET_ERC721 = "ERC721Turret";
  uint256 smartTurretClassId = uint256(keccak256("smartTurretClass"));
  uint256[] smartTurretClassIds;

  SmartTurretTestSystem smartTurretTestSystem = new SmartTurretTestSystem();
  ResourceId smartTurretTesStystemId =
    ResourceId.wrap(
      (bytes32(abi.encodePacked(RESOURCE_SYSTEM, SMART_TURRET_DEPLOYMENT_NAMESPACE, "SmartTurretTestS")))
    );

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    // installing SOF & other modules (SmartTurretModule dependancies)
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );

    SOFInterface = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);

    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new LocationModule(), LOCATION_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    erc721Token = registerERC721(
      world,
      SMART_TURRET_ERC721,
      StaticDataGlobalTableData({ name: "SmartTurret", symbol: "STE", baseURI: "" })
    );

    // install SmartDeployableModule
    SmartDeployableModule deployableModule = new SmartDeployableModule();
    if (
      NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE)) ==
      address(this)
    )
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE),
        address(deployableModule)
      );
    world.installModule(deployableModule, abi.encode(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, new SmartDeployable()));
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721Token));

    // install smartTurretModule
    SmartTurretModule turretModule = new SmartTurretModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(SMART_TURRET_DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(SMART_TURRET_DEPLOYMENT_NAMESPACE),
        address(turretModule)
      );
    world.installModule(turretModule, abi.encode(SMART_TURRET_DEPLOYMENT_NAMESPACE, new SmartTurretModule()));
    smartTurret = SmartTurretLib.World(world, SMART_TURRET_DEPLOYMENT_NAMESPACE);

    // create class and object types
    SOFInterface.registerEntityType(2, "CLASS");
    SOFInterface.registerEntityType(1, "OBJECT");
    // allow object to class tagging
    SOFInterface.registerEntityTypeAssociation(1, 2);

    // initalize the smart Turret class
    SOFInterface.registerEntity(smartTurretClassId, 2);

    // register the smart turret system
    world.registerSystem(smartTurretTesStystemId, smartTurretTestSystem, true);

    //register the function selector
    world.registerFunctionSelector(smartTurretTesStystemId, "inProximity(uint256, uint256,Target[],uint256,uint256)");

    world.registerFunctionSelector(
      SMART_TURRET_DEPLOYMENT_NAMESPACE.smartTurretSystemId(),
      "configureSmartTurret(uint256, ResourceId)"
    );
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function testSetup() public {
    address smartTurretSystem = Systems.getSystem(SMART_TURRET_DEPLOYMENT_NAMESPACE.smartTurretSystemId());
    ResourceId smartTurretSystemId = SystemRegistry.get(smartTurretSystem);
    assertEq(smartTurretSystemId.getNamespace(), SMART_TURRET_DEPLOYMENT_NAMESPACE);
  }

  function testInProximity() public {
    uint256 smartObjectId = 1234;
    Target[] memory targetQueue = new Target[](1);
    targetQueue[0] = Target({ char: "ch", shipType: "sp", weight: 100 });
    uint256 remainingAmmo = 100;
    uint256 hpRatio = 100;
    uint256 characterId = 1234;

    console.logBytes32(ResourceId.unwrap(SMART_TURRET_DEPLOYMENT_NAMESPACE.smartTurretSystemId()));
    console.logBool(ResourceIds.getExists(SMART_TURRET_DEPLOYMENT_NAMESPACE.smartTurretSystemId()));

    // smartTurret.configureSmartTurret(smartObjectId, smartTurretTesStystemId);

    world.call(
      SMART_TURRET_DEPLOYMENT_NAMESPACE.smartTurretSystemId(),
      abi.encodeCall(ISmartTurret.configureSmartTurret, (smartObjectId, smartTurretTesStystemId))
    );

    // Target[] memory returnTargetQueue = smartTurret.inProximity(characterId, targetQueue, remainingAmmo, hpRatio);
    // console.log(returnTargetQueue.length);
    // Target[] memory returnTargetQueue = abi.decode(returnData, (Target[]));
    // console.log(returnTargetQueue[0].hpRatio);
  }
}
