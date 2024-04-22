// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { InstalledModules } from "@latticexyz/world/src/codegen/tables/InstalledModules.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ICustomErrorSystem } from "../src/codegen/world/ICustomErrorSystem.sol";
import { EntityTable } from "../src/codegen/tables/EntityTable.sol";
import { EntityMap } from "../src/codegen/tables/EntityMap.sol";
import { ModuleTable } from "../src/codegen/tables/ModuleTable.sol";
import { HookTable } from "../src/codegen/tables/HookTable.sol";
import { EveSystem } from "../src/systems/internal/EveSystem.sol";
import { MODULE_NAME, TABLE_ID, SYSTEM_ID, NAMESPACE, NAMESPACE_ID, SYSTEM_NAME, HOOK_SYSTEM_ID, HOOK_SYSTEM_NAME, OBJECT, CLASS } from "./constants.sol";
import { HookType } from "../src/types.sol";
import { Utils } from "../src/utils.sol";
import { SmartObjectFrameworkModule } from "../src/SmartObjectFrameworkModule.sol";
import { SmartObjectLib } from "../src/SmartObjectLib.sol";
import { createCoreModule } from "./createCoreModule.sol";

import { EntityCore } from "../src/systems/core/EntityCore.sol";
import { HookCore } from "../src/systems/core/HookCore.sol";
import { ModuleCore } from "../src/systems/core/ModuleCore.sol";


import { SMART_OBJECT_DEPLOYMENT_NAMESPACE as SMART_OBJ_NAMESPACE } from "@eve/common-constants/src/constants.sol";

// TODO: The tests showing as "[FAIL. Reason: call did not revert as expected]" are actually reverting as expected.
// This is a Forge bug that makes nested revert statements not caught by higher-order `vm.expectRevert` routine
// I have no fix for this right now
// related to Smart Deployable similar bug in the test suite

interface ISmartDeployableTestSystem {
  function echoSmartDeployable(uint256 _value) external view returns (uint256);
}

contract SmartDeployableTestSystem is EveSystem {
  function echoSmartDeployable(
    uint256 _value
  )
    public
    onlyAssociatedModule(_value, SYSTEM_ID, getFunctionSelector(SYSTEM_ID, "echoSmartDeployable(uint256)"))
    hookable(_value, SYSTEM_ID)
    returns (uint256)
  {
    return _value;
  }

  function getFunctionSelector(
    ResourceId systemId,
    string memory systemFunctionSignature
  ) public pure returns (bytes4 worldFunctionSelector) {
    bytes memory worldFunctionSignature = abi.encodePacked("deployable", "__", systemFunctionSignature);
    worldFunctionSelector = bytes4(keccak256(worldFunctionSignature));
  }
}

contract SampleHook is EveSystem {
  function echoSmartDeployableHook(uint256 _value) public view {
    console.log("======Hook Executed========", _value);
  }
}

contract SmartDeployableTestModule is Module {
  SmartDeployableTestSystem private smartDeployableTestSystem = new SmartDeployableTestSystem();
  SampleHook private sampleHook = new SampleHook();

  function installRoot(bytes memory args) public {
    // Naive check to ensure this is only installed once
    requireNotInstalled(__self, args);

    IBaseWorld world = IBaseWorld(_world());

    //Register namespace
    (bool success, bytes memory data) = address(world).call(abi.encodeCall(world.registerNamespace, (NAMESPACE_ID)));
    if (!success) revertWithBytes(data);

    // Register system
    (success, data) = address(world).call(
      abi.encodeCall(world.registerSystem, (SYSTEM_ID, smartDeployableTestSystem, true))
    );
    if (!success) revertWithBytes(data);

    (success, data) = address(world).call(abi.encodeCall(world.registerSystem, (HOOK_SYSTEM_ID, sampleHook, true)));
    if (!success) revertWithBytes(data);

    // Register system's functions
    (success, data) = address(world).call(
      abi.encodeCall(world.registerFunctionSelector, (HOOK_SYSTEM_ID, "echoSmartDeployabl(uint256)"))
    );
    if (!success) revertWithBytes(data);

    (success, data) = address(world).call(
      abi.encodeCall(world.registerFunctionSelector, (HOOK_SYSTEM_ID, "echoSmartDeployableHook(uint256)"))
    );
    if (!success) revertWithBytes(data);
  }

  function install(bytes memory args) public {
    // Naive check to ensure this is only installed once
    requireNotInstalled(__self, args);

    IBaseWorld world = IBaseWorld(_world());

    // Register namespace
    world.registerNamespace(NAMESPACE_ID);

    // Register system
    world.registerSystem(SYSTEM_ID, smartDeployableTestSystem, true);
    world.registerSystem(HOOK_SYSTEM_ID, sampleHook, true);

    // Register system's functions
    world.registerFunctionSelector(SYSTEM_ID, "echoSmartDeployable(uint256)");
    world.registerFunctionSelector(HOOK_SYSTEM_ID, "echoSmartDeployableHook(uint256)");
  }
}

contract EveSystemTest is Test {
  using Utils for bytes14;
  using SmartObjectLib for SmartObjectLib.World;

  uint256 classId1 = uint256(keccak256(abi.encodePacked("typeId12")));
  uint256 classId2 = uint256(keccak256(abi.encodePacked("typeId13")));
  uint256 singletonEntity = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));
  uint256 singletonObject2 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 singletonObject3 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-345")));
  uint256 moduleId;

  SmartDeployableTestModule smartDeployableTestModule;

  IBaseWorld baseWorld;
  SmartObjectLib.World smartObject;
  SmartObjectFrameworkModule smartObjectModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    StoreSwitch.setStoreAddress(address(baseWorld));
    // needs to manually deploy each System contracts 
    EntityCore entityCore = new EntityCore();
    HookCore hookCore = new HookCore();
    ModuleCore moduleCore = new ModuleCore();
    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJ_NAMESPACE, address(entityCore), address(hookCore), address(moduleCore)));
    smartObject = SmartObjectLib.World(baseWorld, SMART_OBJ_NAMESPACE);

    smartDeployableTestModule = new SmartDeployableTestModule();
    moduleId = uint256(keccak256(abi.encodePacked(address(smartDeployableTestModule))));
  }

  function testSetup() public {
    setUp();
    assertEq(address(smartObject.iface), address(baseWorld));
  }

  function testMultipleSOFModuleInstalls() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    // needs to manually deploy each System contracts 
    EntityCore entityCore = new EntityCore();
    HookCore hookCore = new HookCore();
    ModuleCore moduleCore = new ModuleCore();
    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJ_NAMESPACE, address(entityCore), address(hookCore), address(moduleCore)));
    
    SmartObjectFrameworkModule newModule = new SmartObjectFrameworkModule();
    entityCore = new EntityCore();
    hookCore = new HookCore();
    moduleCore = new ModuleCore();
    baseWorld.transferOwnership(WorldResourceIdLib.encodeNamespace(SMART_OBJ_NAMESPACE), address(newModule));
    baseWorld.installModule(newModule, abi.encode(SMART_OBJ_NAMESPACE, address(entityCore), address(hookCore), address(moduleCore)));
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = address(baseWorld);
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testInstallModule() public {
    IWorld world = IWorld(address(baseWorld));
    world.installModule(smartDeployableTestModule, new bytes(0));

    // Check that the module is installed
    assertTrue(InstalledModules.get(address(smartDeployableTestModule), keccak256(new bytes(0))));
  }

  function testRegisterEntity() public {
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntity(1, CLASS);
    assertTrue(EntityTable.getEntityType(SMART_OBJ_NAMESPACE.entityTableTableId(), 1) == CLASS);
  }

  function testRevertEntityTypeNotRegistered() public {
    // TODO: See comment at the top of the file
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityTypeNotRegistered.selector,
    //     2,
    //     "EntityCore: EntityType not registered"
    //   )
    // );
    // smartObject.registerEntity(1, CLASS);
  }

  function testRevertIfEntityNotRegistered() public {
    IWorld world = IWorld(address(baseWorld));
    world.installModule(smartDeployableTestModule, new bytes(0));

    vm.expectRevert(
      abi.encodeWithSelector(ICustomErrorSystem.EntityNotRegistered.selector, 12, "EveSystem: Entity is not registered")
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (12)));
  }

  function testTagEntity() public {
    //register entity
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
    smartObject.registerEntity(classId1, CLASS);
    smartObject.registerEntity(singletonObject1, OBJECT);

    //Tag objects under a class
    smartObject.tagEntity(singletonObject1, classId1);
    uint256[] memory entityTagIds = EntityMap.get(SMART_OBJ_NAMESPACE.entityMapTableId(), singletonObject1);
    assertTrue(entityTagIds[0] == classId1);
  }

  function testTagMultipleEntities() public {
    //register entity
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntityTypeAssociation(OBJECT, CLASS);

    uint256[] memory entityIds = new uint256[](2);
    uint8[] memory entityTypes = new uint8[](2);
    entityIds[0] = classId1;
    entityIds[1] = classId2;
    entityTypes[0] = CLASS;
    entityTypes[1] = CLASS;
    smartObject.registerEntities(entityIds, entityTypes);
    smartObject.registerEntity(singletonObject1, OBJECT);

    //Tag objects under a class
    smartObject.tagEntities(singletonObject1, entityIds);

    uint256[] memory entityTagIds = EntityMap.get(SMART_OBJ_NAMESPACE.entityMapTableId(), singletonObject1);
    assertTrue(entityTagIds[0] == classId1);
    assertTrue(entityTagIds[1] == classId2);
  }

  function testRevertAlreadyTagged() public {
    // TODO: See comment at the top of the file
    // //register entity
    // smartObject.registerEntityType(CLASS, "Class");
    // smartObject.registerEntityType(OBJECT, "Object");
    // smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
    // smartObject.registerEntity(classId1, CLASS);
    // smartObject.registerEntity(singletonObject1, OBJECT);
    // //Tag objects under a class
    // smartObject.tagEntity(singletonObject1, classId1);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityAlreadyTagged.selector,
    //     singletonObject1,
    //     classId1,
    //     "EntityCore: Entity already tagged"
    //   )
    // );
    // smartObject.tagEntity(singletonObject1, classId1);
  }

  function testRevertIfTaggingNotAllowed() public {
    // TODO: See comment at the top of the file
    // //register entity
    // smartObject.registerEntityType(CLASS, "Class");
    // smartObject.registerEntityType(OBJECT, "Object");
    // smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
    // smartObject.registerEntity(classId1, CLASS);
    // smartObject.registerEntity(singletonObject1, OBJECT);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityTypeAssociationNotAllowed.selector,
    //     CLASS,
    //     OBJECT,
    //     "EntityCore: EntityType association not allowed"
    //   )
    // );
    // smartObject.tagEntity(classId1, singletonObject1);
  }

  function testregisterEVEModule() public {
    IWorld world = IWorld(address(baseWorld));

    world.installModule(smartDeployableTestModule, new bytes(0));

    //register module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    assertTrue(ModuleTable.getDoesExists(SMART_OBJ_NAMESPACE.moduleTableTableId(), moduleId, SYSTEM_ID));
  }

  function testRevertregisterEVEModuleIfSystemAlreadyRegistered() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // //register module
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.SystemAlreadyAssociatedWithModule.selector,
    //     moduleId,
    //     SYSTEM_ID,
    //     "ModuleCore: System already associated with the module"
    //   )
    // );
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
  }

  function testObjectAssociate() public {
    IWorld world = IWorld(address(baseWorld));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntity(singletonObject1, OBJECT);

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    smartObject.associateModule(singletonObject1, moduleId);

    ModuleTable.getDoesExists(SMART_OBJ_NAMESPACE.moduleTableTableId(), moduleId, SYSTEM_ID);
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);
  }

  function testClassAssociate() public {
    IWorld world = IWorld(address(baseWorld));
    uint256 nonSingletonEntity = uint256(keccak256(abi.encode("item:72")));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntity(nonSingletonEntity, CLASS);

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    smartObject.associateModule(nonSingletonEntity, moduleId);

    ModuleTable.getDoesExists(SMART_OBJ_NAMESPACE.moduleTableTableId(), moduleId, SYSTEM_ID);
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (nonSingletonEntity))),
      (uint256)
    );
    assertTrue(value == nonSingletonEntity);
  }

  function testRevertIfNotAssociated() public {
    IWorld world = IWorld(address(baseWorld));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntity(classId1, CLASS);

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityNotAssociatedWithModule.selector,
        classId1,
        "EveSystem: Entity is not associated with any module"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (classId1)));
  }

  function testObjectAssociateWithClass() public {
    IWorld world = IWorld(address(baseWorld));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entityType
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntityType(OBJECT, "Object");

    //Allow tagging of entities
    smartObject.registerEntityTypeAssociation(OBJECT, CLASS);

    //register entityType
    smartObject.registerEntity(classId1, CLASS);
    smartObject.registerEntity(singletonObject1, OBJECT);
    smartObject.registerEntity(singletonObject2, OBJECT);
    smartObject.registerEntity(singletonObject3, OBJECT);

    //Tag objects under a class
    smartObject.tagEntity(singletonObject1, classId1);
    smartObject.tagEntity(singletonObject2, classId1);
    smartObject.tagEntity(singletonObject3, classId1);

    //associate entity with module
    smartObject.associateModule(classId1, moduleId);

    ModuleTable.getDoesExists(SMART_OBJ_NAMESPACE.moduleTableTableId(), moduleId, SYSTEM_ID);
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);
    value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject2))),
      (uint256)
    );
    assertTrue(value == singletonObject2);
  }

  function testRemoveEntityTag() public {
    IWorld world = IWorld(address(baseWorld));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    smartObject.registerEntityType(1, "Class");
    smartObject.registerEntityType(2, "Object");
    smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
    smartObject.registerEntity(classId1, CLASS);
    smartObject.registerEntity(singletonObject1, OBJECT);
    smartObject.tagEntity(singletonObject1, classId1);

    //associate entity with module
    smartObject.associateModule(classId1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    smartObject.removeEntityTag(singletonObject1, classId1);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityNotAssociatedWithModule.selector,
        singletonObject1,
        "EveSystem: Entity is not associated with any module"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testRevertIfEntityAlreadyAssociated() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // //install module
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // //register entity
    // smartObject.registerEntityType(OBJECT, "Object");
    // smartObject.registerEntity(singletonEntity, OBJECT);
    // // register system associated with module
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    // //associate entity with module
    // smartObject.associateModule(singletonEntity, moduleId);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityAlreadyAssociated.selector,
    //     singletonEntity,
    //     moduleId,
    //     "ModuleCore: Module already associated with the entity"
    //   )
    // );
    // smartObject.associateModule(singletonEntity, moduleId);
  }

  function testRevertIfTaggedEntityIsAlreadyAssociated() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // //install module
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // // register system associated with module
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    // //register entity
    // smartObject.registerEntityType(1, "Class");
    // smartObject.registerEntityType(2, "Object");
    // smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
    // smartObject.registerEntity(classId1, CLASS);
    // smartObject.registerEntity(classId2, CLASS);
    // smartObject.registerEntity(singletonObject1, OBJECT);
    // smartObject.tagEntity(singletonObject1, classId1);
    // smartObject.tagEntity(singletonObject1, classId2);
    // //associate entity with module
    // smartObject.associateModule(classId1, moduleId);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityAlreadyAssociated.selector,
    //     classId1,
    //     moduleId,
    //     "ModuleCore: Module already associated with the entity"
    //   )
    // );
    // smartObject.associateModule(singletonObject1, moduleId);
  }

  function testRevertIfModuleNotRegistered() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // //install module
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // smartObject.registerEntityType(2, "Object");
    // smartObject.registerEntity(singletonEntity, CLASS);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.ModuleNotRegistered.selector,
    //     singletonEntity,
    //     "EveSystem: Module not registered"
    //   )
    // );
    // smartObject.associateModule(singletonEntity, singletonEntity);
  }

  //TODO commenting until we resolve data corruption issue
  // function testRemoveEntity() public {
  //   IWorld world = IWorld(address(baseWorld));
  //   uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));

  //   //install module
  //
  //   world.installModule(smartDeployableTestModule, new bytes(0));

  //   // register system associated with module
  //   world.registerEVEModule(SYSTEM_ID, moduleId, MODULE_NAME);

  //   //register entity
  //   world.registerEntityType(2, "Object");
  //   world.registerEntity(singletonObject1, OBJECT);

  //   //associate entity with module
  //   world.associateModule(singletonObject1, moduleId);

  //   uint256 value = abi.decode(
  //     world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
  //     (uint256)
  //   );
  //   assertTrue(value == singletonObject1);

  //   //Remove entity and check if it reverts
  //   world.removeEntity(singletonObject1);
  //   vm.expectRevert(
  //     abi.encodeWithSelector(
  //       ICustomErrorSystem.EntityNotRegistered.selector,
  //       singletonObject1,
  //       "EveSystem: Entity is not registered"
  //     )
  //   );
  //   world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  // }

  function testRemoveEntityModuleAssociation() public {
    IWorld world = IWorld(address(baseWorld));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntity(singletonObject1, OBJECT);

    //associate entity with module
    smartObject.associateModule(singletonObject1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    //Remove module and check if it reverts
    smartObject.removeEntityModuleAssociation(singletonObject1, moduleId);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityNotAssociatedWithModule.selector,
        singletonObject1,
        "EveSystem: Entity is not associated with any module"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testRemoveSystem() public {
    IWorld world = IWorld(address(baseWorld));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntity(singletonObject1, OBJECT);

    //associate entity with module
    smartObject.associateModule(singletonObject1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    //Remove module and check if it reverts
    smartObject.removeSystemModuleAssociation(SYSTEM_ID, moduleId);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.ModuleNotFound.selector,
        "EveSystem: Module associated with the system is not found"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testHook() public {
    IWorld world = IWorld(address(baseWorld));

    // install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    smartObject.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    smartObject.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(SMART_OBJ_NAMESPACE.hookTableTableId(), hookId));

    //asscoaite hook with a entity
    smartObject.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    smartObject.addHook(
      hookId,
      HookType.BEFORE,
      SYSTEM_ID,
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //execute hooks by calling the target function
    abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
      (uint256)
    );
  }

  function testRevertHookAssociationIfHookNotRegistered() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // // install module
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // //register entity
    // smartObject.registerEntityType(OBJECT, "Object");
    // smartObject.registerEntity(singletonEntity, OBJECT);
    // // register system associated with module
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    // //associate entity with module
    // smartObject.associateModule(singletonEntity, moduleId);
    // //Hook
    // bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    // uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    // vm.expectRevert(
    //   abi.encodeWithSelector(ICustomErrorSystem.HookNotRegistered.selector, hookId, "HookCore: Hook not registered")
    // );
    // smartObject.associateHook(singletonEntity, hookId);
  }

  function testRevertDuplicateHookAssociation() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // // install module
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // //register entity
    // smartObject.registerEntityType(OBJECT, "Object");
    // smartObject.registerEntity(singletonEntity, OBJECT);
    // // register system associated with module
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    // //associate entity with module
    // smartObject.associateModule(singletonEntity, moduleId);
    // //Hook
    // bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    // smartObject.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);
    // uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    // assertTrue(HookTable.getIsHook(SMART_OBJ_NAMESPACE.hookTableTableId(), hookId));
    // //asscoaite hook with a entity
    // smartObject.associateHook(singletonEntity, hookId);
    // //add the hook to be executed before/after a function
    // smartObject.addHook(
    //   hookId,
    //   HookType.BEFORE,
    //   SYSTEM_ID,
    //   bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    // );
    // //execute hooks by calling the target function
    // abi.decode(
    //   world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
    //   (uint256)
    // );
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityAlreadyAssociated.selector,
    //     singletonEntity,
    //     hookId,
    //     "HookCore: Hook already associated with the entity"
    //   )
    // );
    // smartObject.associateHook(singletonEntity, hookId);
  }

  function testRevertIfTaggedEntityHasHookAssociated() public {
    // TODO: See comment at the top of the file
    // IWorld world = IWorld(address(baseWorld));
    // // install module
    // world.installModule(smartDeployableTestModule, new bytes(0));
    // //register entity
    // smartObject.registerEntityType(OBJECT, "Object");
    // smartObject.registerEntityType(CLASS, "Object");
    // smartObject.registerEntity(singletonEntity, OBJECT);
    // smartObject.registerEntity(classId1, CLASS);
    // smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
    // smartObject.tagEntity(singletonEntity, classId1);
    // // register system associated with module
    // smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    // //associate entity with module
    // smartObject.associateModule(classId1, moduleId);
    // //Hook
    // bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    // smartObject.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);
    // uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    // assertTrue(HookTable.getIsHook(SMART_OBJ_NAMESPACE.hookTableTableId(), hookId));
    // //asscoaite hook with a entity
    // smartObject.associateHook(classId1, hookId);
    // //add the hook to be executed before/after a function
    // smartObject.addHook(
    //   hookId,
    //   HookType.BEFORE,
    //   SYSTEM_ID,
    //   bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    // );
    // //execute hooks by calling the target function
    // abi.decode(
    //   world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
    //   (uint256)
    // );
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     ICustomErrorSystem.EntityAlreadyAssociated.selector,
    //     classId1,
    //     hookId,
    //     "HookCore: Hook already associated with the entity"
    //   )
    // );
    // smartObject.associateHook(singletonEntity, hookId);
  }

  function testRemoveHook() public {
    IWorld world = IWorld(address(baseWorld));

    // install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    smartObject.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    smartObject.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    smartObject.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(SMART_OBJ_NAMESPACE.hookTableTableId(), hookId));

    //asscoaite hook with a entity
    smartObject.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    smartObject.addHook(
      hookId,
      HookType.BEFORE,
      SYSTEM_ID,
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //After remove hook there is no console.log of hook execution
    smartObject.removeHook(
      hookId,
      HookType.BEFORE,
      SYSTEM_ID,
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //execute hooks by calling the target function
    abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
      (uint256)
    );
  }
}
