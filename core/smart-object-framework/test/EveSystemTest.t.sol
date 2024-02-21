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
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IEntityCore } from "../src/codegen/world/IEntityCore.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { ICustomErrorSystem } from "../src/codegen/world/ICustomErrorSystem.sol";
import { EntityTable } from "../src/codegen/tables/EntityTable.sol";
import { EntityMapTable } from "../src/codegen/tables/EntityMapTable.sol";
import { ModuleTable } from "../src/codegen/tables/ModuleTable.sol";
import { HookTable } from "../src/codegen/tables/HookTable.sol";
import { EveSystem } from "../src/systems/internal/EveSystem.sol";
import { MODULE_NAME, TABLE_ID, SYSTEM_ID, NAMESPACE, NAMESPACE_ID, SYSTEM_NAME, HOOK_SYSTEM_ID, HOOK_SYSTEM_NAME, OBJECT, CLASS } from "./constants.sol";
import { HookType } from "../src/types.sol";
import { Utils } from "../src/utils.sol";

interface ISmartDeployableTestSystem {
  function echoSmartDeployable(uint256 _value) external view returns (uint256);
}

contract SmartDeployableTestSystem is EveSystem {
  function echoSmartDeployable(
    uint256 _value
  )
    public
    onlyAssociatedModule(_value, SYSTEM_ID, getFunctionSelector(SYSTEM_ID, "echoSmartDeployable(uint256)"))
    hookable(_value, SYSTEM_ID, abi.encode(_value))
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
    (bool success, bytes memory data) = address(world).delegatecall(
      abi.encodeCall(world.registerNamespace, (NAMESPACE_ID))
    );
    if (!success) revertWithBytes(data);

    // Register system
    (success, data) = address(world).delegatecall(
      abi.encodeCall(world.registerSystem, (SYSTEM_ID, smartDeployableTestSystem, true))
    );
    if (!success) revertWithBytes(data);

    (success, data) = address(world).delegatecall(
      abi.encodeCall(world.registerSystem, (HOOK_SYSTEM_ID, sampleHook, true))
    );
    if (!success) revertWithBytes(data);

    // Register system's functions
    (success, data) = address(world).delegatecall(
      abi.encodeCall(world.registerFunctionSelector, (HOOK_SYSTEM_ID, "echoSmartDeployabl(uint256)"))
    );
    if (!success) revertWithBytes(data);

    (success, data) = address(world).delegatecall(
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

contract EveSystemTest is MudTest {
  uint256 classId1 = uint256(keccak256(abi.encodePacked("typeId12")));
  uint256 classId2 = uint256(keccak256(abi.encodePacked("typeId13")));
  uint256 singletonEntity = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));
  uint256 singletonObject2 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
  uint256 singletonObject3 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-345")));
  uint256 moduleId = uint256(keccak256(abi.encodePacked(address(smartDeployableTestModule))));

  SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testInstallModule() public {
    IWorld world = IWorld(worldAddress);
    world.installModule(smartDeployableTestModule, new bytes(0));

    // Check that the module is installed
    assertTrue(InstalledModules.get(address(smartDeployableTestModule), keccak256(new bytes(0))));
  }

  function testRegisterEntity() public {
    IWorld world = IWorld(worldAddress);
    world.registerEntityType(CLASS, "Class");
    world.registerEntity(1, CLASS);
    assertTrue(EntityTable.getEntityType(1) == CLASS);
  }

  function testRevertEntityTypeNotRegistered() public {
    IWorld world = IWorld(worldAddress);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityTypeNotRegistered.selector,
        2,
        "EntityCore: EntityType not registered"
      )
    );
    world.registerEntity(1, CLASS);
  }

  function testRevertIfEntityNotRegistered() public {
    IWorld world = IWorld(worldAddress);
    world.installModule(smartDeployableTestModule, new bytes(0));

    vm.expectRevert(
      abi.encodeWithSelector(ICustomErrorSystem.EntityNotRegistered.selector, 12, "EveSystem: Entity is not registered")
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (12)));
  }

  function testTagEntity() public {
    IWorld world = IWorld(worldAddress);
  
    //register entity
    world.registerEntityType(CLASS, "Class");
    world.registerEntityType(OBJECT, "Object");
    world.registerEntityTypeAssociation(OBJECT, CLASS);
    world.registerEntity(classId1, CLASS);
    world.registerEntity(singletonObject1, OBJECT);

    //Tag objects under a class
    world.tagEntity(singletonObject1, classId1);
    uint256[] memory entityTagIds = EntityMapTable.get(singletonObject1);
    assertTrue(entityTagIds[0] == classId1);
  }

  function testTagMultipleEntities() public {
    IWorld world = IWorld(worldAddress);
    
    //register entity
    world.registerEntityType(CLASS, "Class");
    world.registerEntityType(OBJECT, "Object");
    world.registerEntityTypeAssociation(OBJECT, CLASS);

    uint256[] memory entityIds = new uint256[](2);
    uint8[] memory entityTypes = new uint8[](2);
    entityIds[0] = classId1;
    entityIds[1] = classId2;
    entityTypes[0] = CLASS;
    entityTypes[1] = CLASS;
    world.registerEntity(entityIds, entityTypes);
    world.registerEntity(singletonObject1, OBJECT);

    //Tag objects under a class
    world.tagEntity(singletonObject1, entityIds);

    uint256[] memory entityTagIds = EntityMapTable.get(singletonObject1);
    assertTrue(entityTagIds[0] == classId1);
    assertTrue(entityTagIds[1] == classId2);
  }

  function testRevertAlreadyTagged() public {
    IWorld world = IWorld(worldAddress);
  
    //register entity
    world.registerEntityType(CLASS, "Class");
    world.registerEntityType(OBJECT, "Object");
    world.registerEntityTypeAssociation(OBJECT, CLASS);
    world.registerEntity(classId1, CLASS);
    world.registerEntity(singletonObject1, OBJECT);

    //Tag objects under a class
    world.tagEntity(singletonObject1, classId1);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityAlreadyTagged.selector,
        singletonObject1,
        classId1,
        "EntityCore: Entity already tagged"
      )
    );
    world.tagEntity(singletonObject1, classId1);
  }

  function testRevertIfTaggingNotAllowed() public {
    IWorld world = IWorld(worldAddress);
  
    //register entity
    world.registerEntityType(CLASS, "Class");
    world.registerEntityType(OBJECT, "Object");
    world.registerEntityTypeAssociation(OBJECT, CLASS);
    world.registerEntity(classId1, CLASS);
    world.registerEntity(singletonObject1, OBJECT);

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityTypeAssociationNotAllowed.selector,
        CLASS,
        OBJECT,
        "EntityCore: EntityType association not allowed"
      )
    );
    world.tagEntity(classId1, singletonObject1);
  }

  function testregisterEVEModule() public {
    IWorld world = IWorld(worldAddress);
    
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    assertTrue(ModuleTable.getDoesExists(moduleId, SYSTEM_ID));
  }

  function testRevertregisterEVEModuleIfSystemAlreadyRegistered() public {
    IWorld world = IWorld(worldAddress);
    
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.SystemAlreadyAssociatedWithModule.selector,
        moduleId,
        SYSTEM_ID,
        "ModuleCore: System already associated with the module"
      )
    );
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);
  }

  function testObjectAssociate() public {
    IWorld world = IWorld(worldAddress);

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonObject1, OBJECT);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(singletonObject1, moduleId);

    ModuleTable.getDoesExists(moduleId, SYSTEM_ID);
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);
  }

  function testClassAssociate() public {
    IWorld world = IWorld(worldAddress);
    uint256 nonSingletonEntity = uint256(keccak256(abi.encode("item:72")));

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(CLASS, "Class");
    world.registerEntity(nonSingletonEntity, CLASS);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(nonSingletonEntity, moduleId);

    ModuleTable.getDoesExists(moduleId, SYSTEM_ID);
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (nonSingletonEntity))),
      (uint256)
    );
    assertTrue(value == nonSingletonEntity);
  }

  function testRevertIfNotAssociated() public {
    IWorld world = IWorld(worldAddress);

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(CLASS, "Class");
    world.registerEntity(classId1, CLASS);

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
    IWorld world = IWorld(worldAddress);
    
    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entityType
    world.registerEntityType(CLASS, "Class");
    world.registerEntityType(OBJECT, "Object");

    //Allow tagging of entities
    world.registerEntityTypeAssociation(OBJECT, CLASS);

    //register entityType
    world.registerEntity(classId1, CLASS);
    world.registerEntity(singletonObject1, OBJECT);
    world.registerEntity(singletonObject2, OBJECT);
    world.registerEntity(singletonObject3, OBJECT);

    //Tag objects under a class
    world.tagEntity(singletonObject1, classId1);
    world.tagEntity(singletonObject2, classId1);
    world.tagEntity(singletonObject3, classId1);

    //associate entity with module
    world.associateModule(classId1, moduleId);

    ModuleTable.getDoesExists(moduleId, SYSTEM_ID);
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
    IWorld world = IWorld(worldAddress);
  
    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    world.registerEntityType(1, "Class");
    world.registerEntityType(2, "Object");
    world.registerEntityTypeAssociation(OBJECT, CLASS);
    world.registerEntity(classId1, CLASS);
    world.registerEntity(singletonObject1, OBJECT);
    world.tagEntity(singletonObject1, classId1);

    //associate entity with module
    world.associateModule(classId1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    world.removeEntityTag(singletonObject1, classId1);
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
    IWorld world = IWorld(worldAddress);

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityAlreadyAssociated.selector,
        singletonEntity,
        moduleId,
        "ModuleCore: Module already associated with the entity"
      )
    );
    world.associateModule(singletonEntity, moduleId);
  }

  function testRevertIfTaggedEntityIsAlreadyAssociated() public {
    IWorld world = IWorld(worldAddress);

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    world.registerEntityType(1, "Class");
    world.registerEntityType(2, "Object");
    world.registerEntityTypeAssociation(OBJECT, CLASS);
    world.registerEntity(classId1, CLASS);
    world.registerEntity(classId2, CLASS);

    world.registerEntity(singletonObject1, OBJECT);
    world.tagEntity(singletonObject1, classId1);
    world.tagEntity(singletonObject1, classId2);

    //associate entity with module
    world.associateModule(classId1, moduleId);

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityAlreadyAssociated.selector,
        classId1,
        moduleId,
        "ModuleCore: Module already associated with the entity"
      )
    );
    world.associateModule(singletonObject1, moduleId);
  }

  function testRevertIfModuleNotRegistered() public {
    IWorld world = IWorld(worldAddress);

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    world.registerEntityType(2, "Object");
    world.registerEntity(singletonEntity, CLASS);

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.ModuleNotRegistered.selector,
        singletonEntity,
        "EveSystem: Module not registered"
      )
    );
    world.associateModule(singletonEntity, singletonEntity);
  }

  //TODO commenting until we resolve data corruption issue
  // function testRemoveEntity() public {
  //   IWorld world = IWorld(worldAddress);
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
    IWorld world = IWorld(worldAddress);
    
    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonObject1, OBJECT);

    //associate entity with module
    world.associateModule(singletonObject1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    //Remove module and check if it reverts
    world.removeEntityModuleAssociation(singletonObject1, moduleId);
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
    IWorld world = IWorld(worldAddress);

    //install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonObject1, OBJECT);

    //associate entity with module
    world.associateModule(singletonObject1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    //Remove module and check if it reverts
    world.removeSystemModuleAssociation(SYSTEM_ID, moduleId);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.ModuleNotFound.selector,
        "EveSystem: Module associated with the system is not found"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testHook() public {
    IWorld world = IWorld(worldAddress);

    // install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    world.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(hookId));

    //asscoaite hook with a entity
    world.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    world.addHook(
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
    IWorld world = IWorld(worldAddress);

    // install module
    
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));

    vm.expectRevert(
      abi.encodeWithSelector(ICustomErrorSystem.HookNotRegistered.selector, hookId, "HookCore: Hook not registered")
    );
    world.associateHook(singletonEntity, hookId);
  }

  function testRevertDuplicateHookAssociation() public {
    IWorld world = IWorld(worldAddress);

    // install module
    
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    world.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(hookId));

    //asscoaite hook with a entity
    world.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    world.addHook(
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

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityAlreadyAssociated.selector,
        singletonEntity,
        hookId,
        "HookCore: Hook already associated with the entity"
      )
    );
    world.associateHook(singletonEntity, hookId);
  }

  function testRevertIfTaggedEntityHasHookAssociated() public {
    IWorld world = IWorld(worldAddress);

    // install module
    
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntityType(CLASS, "Object");
    world.registerEntity(singletonEntity, OBJECT);
    world.registerEntity(classId1, CLASS);

    world.registerEntityTypeAssociation(OBJECT, CLASS);
    world.tagEntity(singletonEntity, classId1);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(classId1, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    world.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(hookId));

    //asscoaite hook with a entity
    world.associateHook(classId1, hookId);

    //add the hook to be executed before/after a function
    world.addHook(
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

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityAlreadyAssociated.selector,
        classId1,
        hookId,
        "HookCore: Hook already associated with the entity"
      )
    );
    world.associateHook(singletonEntity, hookId);
  }

  function testRemoveHook() public {
    IWorld world = IWorld(worldAddress);

    // install module
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntityType(OBJECT, "Object");
    world.registerEntity(singletonEntity, OBJECT);

    // register system associated with module
    world.registerEVEModule(moduleId, MODULE_NAME, SYSTEM_ID);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    world.registerHook(Utils.getSystemId(NAMESPACE, HOOK_SYSTEM_NAME), functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(hookId));

    //asscoaite hook with a entity
    world.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    world.addHook(
      hookId,
      HookType.BEFORE,
      SYSTEM_ID,
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //After remove hook there is no console.log of hook execution
    world.removeHook(
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
