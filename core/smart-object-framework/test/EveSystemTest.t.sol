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
import { ModuleTable } from "../src/codegen/tables/ModuleTable.sol";
import { HookTable } from "../src/codegen/tables/HookTable.sol";
import { EveSystem } from "../src/systems/internal/EveSystem.sol";
import { MODULE_NAME, TABLE_ID, SYSTEM_ID, NAMESPACE, SYSTEM_NAME, HOOK_MODULE_NAME, HOOK_SYSTEM_ID, HOOK_SYSTEM_NAME } from "./constants.sol";
import { EntityType, HookType } from "../src/types.sol";

interface ISmartDeployableTestSystem {
  function echoSmartDeployable(uint256 _value) external view returns (uint256);
}

contract SmartDeployableTestSystem is EveSystem {
  function echoSmartDeployable(
    uint256 _value
  )
    public
    onlyAssociatedModule(_value, SYSTEM_ID, getFunctionSelector(SYSTEM_ID, "echoSmartDeployable(uint256)"))
    hookable(_value, ResourceId.unwrap(SYSTEM_ID), abi.encode(_value))
    returns (uint256)
  {
    return _value;
  }

  function getFunctionSelector(
    ResourceId systemId,
    string memory systemFunctionSignature
  ) public pure returns (bytes4 worldFunctionSelector) {
    bytes memory worldFunctionSignature = abi.encodePacked("deployable", "_", "system", "_", systemFunctionSignature);
    worldFunctionSelector = bytes4(keccak256(worldFunctionSignature));
  }
}

contract SampleHook is EveSystem {
  function echoSmartDeployableHook(uint256 _value) public {
    console.log("======Hook Executed========", _value);
  }
}

contract SmartDeployableTestModule is Module {
  SmartDeployableTestSystem private smartDeployableTestSystem = new SmartDeployableTestSystem();
  SampleHook private sampleHook = new SampleHook();

  function getName() public pure returns (bytes16) {
    return MODULE_NAME;
  }

  function installRoot(bytes memory args) public {
    // Naive check to ensure this is only installed once
    // TODO: only revert if there's nothing to do
    requireNotInstalled(getName(), args);

    // Register system
    IBaseWorld world = IBaseWorld(_world());
    (bool success, bytes memory data) = address(world).delegatecall(
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
    // TODO: only revert if there's nothing to do
    requireNotInstalled(getName(), args);

    IBaseWorld world = IBaseWorld(_world());

    // Register table
    // smartDeployableTestSystem.register(TABLE_ID);

    // Register system
    world.registerSystem(SYSTEM_ID, smartDeployableTestSystem, true);
    world.registerSystem(HOOK_SYSTEM_ID, sampleHook, true);

    // Register system's functions
    world.registerFunctionSelector(SYSTEM_ID, "echoSmartDeployable(uint256)");
    world.registerFunctionSelector(HOOK_SYSTEM_ID, "echoSmartDeployableHook(uint256)");
  }
}

contract EveSystemTest is MudTest {
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
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    // Check that the module is installed
    assertTrue(InstalledModules.get(smartDeployableTestModule.getName(), keccak256(new bytes(0))) != address(0));
  }

  function testRegisterEntity() public {
    IWorld world = IWorld(worldAddress);
    world.registerEntity(1, EntityType.Class);
    assertTrue(EntityTable.getEntityType(1) == uint256(EntityType.Class));
  }

  function testRevertIfEntityNotRegistered() public {
    IWorld world = IWorld(worldAddress);
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    vm.expectRevert(
      abi.encodeWithSelector(ICustomErrorSystem.EntityNotRegistered.selector, 12, "EveSystem: Entity is not registered")
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (12)));
  }

  function testObjectAssociate() public {
    IWorld world = IWorld(worldAddress);
    uint256 singletonEntity = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntity(singletonEntity, EntityType.Object);

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    bool systemExists = ModuleTable.getDoesExists(moduleId, ResourceId.unwrap(SYSTEM_ID));
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
      (uint256)
    );
    assertTrue(value == singletonEntity);
  }

  function testClassAssociate() public {
    IWorld world = IWorld(worldAddress);
    uint256 nonSingletonEntity = uint256(keccak256(abi.encode("item:72")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntity(nonSingletonEntity, EntityType.Class);

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //associate entity with module
    world.associateModule(nonSingletonEntity, moduleId);

    bool systemExists = ModuleTable.getDoesExists(moduleId, ResourceId.unwrap(SYSTEM_ID));
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (nonSingletonEntity))),
      (uint256)
    );
    assertTrue(value == nonSingletonEntity);
  }

  function testRevertIfNotAssociated() public {
    IWorld world = IWorld(worldAddress);
    uint256 entity = uint256(keccak256(abi.encodePacked("typeId12")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntity(entity, EntityType.Class);

    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityNotAssociatedWithModule.selector,
        entity,
        "EveSystem: Entity is not associated with any module"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (entity)));
  }

  function testObjectAssociateWithClass() public {
    IWorld world = IWorld(worldAddress);
    uint256 classId = uint256(keccak256(abi.encodePacked("typeId12")));
    uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));
    uint256 singletonObject2 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
    uint256 singletonObject3 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-345")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //register entity
    world.registerEntity(classId, EntityType.Class);
    world.registerEntity(singletonObject1, EntityType.Object);
    world.registerEntity(singletonObject2, EntityType.Object);
    world.registerEntity(singletonObject3, EntityType.Object);

    //Tag objects under a class
    world.tagEntity(singletonObject1, classId);
    world.tagEntity(singletonObject2, classId);
    world.tagEntity(singletonObject3, classId);

    //associate entity with module
    world.associateModule(classId, moduleId);

    bool systemExists = ModuleTable.getDoesExists(moduleId, ResourceId.unwrap(SYSTEM_ID));
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

  function testRemoveClassTag() public {
    IWorld world = IWorld(worldAddress);
    uint256 classId = uint256(keccak256(abi.encodePacked("typeId12")));
    uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //register entity
    world.registerEntity(classId, EntityType.Class);
    world.registerEntity(singletonObject1, EntityType.Object);
    world.tagEntity(singletonObject1, classId);

    //associate entity with module
    world.associateModule(classId, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    world.removeClassTag(singletonObject1);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityNotAssociatedWithModule.selector,
        singletonObject1,
        "EveSystem: Entity is not associated with any module"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testRemoveEntity() public {
    IWorld world = IWorld(worldAddress);
    uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //register entity
    world.registerEntity(singletonObject1, EntityType.Object);

    //associate entity with module
    world.associateModule(singletonObject1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    //Remove entity and check if it reverts
    world.removeEntity(singletonObject1);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.EntityNotRegistered.selector,
        singletonObject1,
        "EveSystem: Entity is not registered"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testRemoveModule() public {
    IWorld world = IWorld(worldAddress);
    uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //register entity
    world.registerEntity(singletonObject1, EntityType.Object);

    //associate entity with module
    world.associateModule(singletonObject1, moduleId);

    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1))),
      (uint256)
    );
    assertTrue(value == singletonObject1);

    //Remove module and check if it reverts
    world.removeModule(singletonObject1, moduleId);
    vm.expectRevert(
      abi.encodeWithSelector(
        ICustomErrorSystem.ModuleNotFound.selector,
        "EveSystem: Module associated with the system is not found"
      )
    );
    world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonObject1)));
  }

  function testRemoveSystem() public {
    IWorld world = IWorld(worldAddress);
    uint256 singletonObject1 = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-12345")));

    //install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //register entity
    world.registerEntity(singletonObject1, EntityType.Object);

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
    uint256 singletonEntity = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));

    // install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntity(singletonEntity, EntityType.Object);

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    world.registerHook(NAMESPACE, HOOK_SYSTEM_NAME, functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(hookId));

    //asscoaite hook with a entity
    world.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    world.addHook(
      hookId,
      HookType.BEFORE,
      ResourceId.unwrap(SYSTEM_ID),
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //execute hooks by calling the target function
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
      (uint256)
    );
  }

  function testRemoveHook() public {
    IWorld world = IWorld(worldAddress);
    uint256 singletonEntity = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));

    // install module
    SmartDeployableTestModule smartDeployableTestModule = new SmartDeployableTestModule();
    world.installModule(smartDeployableTestModule, new bytes(0));

    //register entity
    world.registerEntity(singletonEntity, EntityType.Object);

    // register system associated with module
    uint256 moduleId = uint256(keccak256(abi.encodePacked(MODULE_NAME)));
    world.registerModule(SYSTEM_ID, moduleId, MODULE_NAME);

    //associate entity with module
    world.associateModule(singletonEntity, moduleId);

    //Hook
    bytes4 functionId = bytes4(keccak256(abi.encodePacked("echoSmartDeployableHook(uint256)")));
    world.registerHook(NAMESPACE, HOOK_SYSTEM_NAME, functionId);

    uint256 hookId = uint256(keccak256(abi.encodePacked(ResourceId.unwrap(HOOK_SYSTEM_ID), functionId)));
    assertTrue(HookTable.getIsHook(hookId));

    //asscoaite hook with a entity
    world.associateHook(singletonEntity, hookId);

    //add the hook to be executed before/after a function
    world.addHook(
      hookId,
      HookType.BEFORE,
      ResourceId.unwrap(SYSTEM_ID),
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //After remove hook there is no console.log of hook execution
    world.removeHook(
      hookId,
      HookType.BEFORE,
      ResourceId.unwrap(SYSTEM_ID),
      bytes4(keccak256(abi.encodePacked("echoSmartDeployable(uint256)")))
    );

    //execute hooks by calling the target function
    uint256 value = abi.decode(
      world.call(SYSTEM_ID, abi.encodeCall(SmartDeployableTestSystem.echoSmartDeployable, (singletonEntity))),
      (uint256)
    );
  }
}
