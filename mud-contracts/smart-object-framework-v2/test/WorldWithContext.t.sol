// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { console } from "forge-std/console.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { IWorldCall } from "@latticexyz/world/src/IWorldKernel.sol";
import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { DEPLOYMENT_NAMESPACE } from "../src/namespaces/evefrontier/constants.sol";
import { EntitySystem } from "../src/namespaces/evefrontier/systems/entity-system/EntitySystem.sol";
import { Utils as EntitySystemUtils } from "../src/namespaces/evefrontier/systems/entity-system/Utils.sol";

import { SystemMock } from "./mocks/SystemMock.sol";
import { TransientContext } from "./mocks/types.sol";
import { Classes } from "../src/namespaces/evefrontier/codegen/tables/Classes.sol";

import "../src/namespaces/evefrontier/codegen/index.sol";

import { Id, IdLib } from "../src/libs/Id.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../src/types/entityTypes.sol";
import { TAG_SYSTEM } from "../src/types/tagTypes.sol";

import { SmartObjectFramework } from "../src/inherit/SmartObjectFramework.sol";

contract WorldWithContextTest is MudTest {
  using EntitySystemUtils for bytes14;

  IBaseWorld world;
  SystemMock systemMock;

  bytes14 constant NAMESPACE = "mockspace";
  ResourceId constant NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, NAMESPACE)));
  ResourceId constant MOCK_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, bytes16("SystemMock")))));

  Id classId = IdLib.encode(ENTITY_CLASS, bytes30("TEST_CLASS"));

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPrivateKey;
  uint256 alicePrivateKey;
  address deployer; // World Deployer and root namespace owner
  address alice; // Alice SystemMock deployer and namespace owner

  function setUp() public override {
    deployerPrivateKey = vm.deriveKey(mnemonic, 0);
    alicePrivateKey = vm.deriveKey(mnemonic, 1);

    deployer = vm.addr(deployerPrivateKey);
    alice = vm.addr(alicePrivateKey);

    // START: DEPLOY AND REGISTER A MUD WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IBaseWorld(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    // START: DEPLOY AND REGISTER SystemMock.sol
    vm.startPrank(alice);
    world.registerNamespace(NAMESPACE_ID);
    systemMock = new SystemMock();
    world.registerSystem(MOCK_SYSTEM_ID, System(systemMock), true);
    world.registerFunctionSelector(MOCK_SYSTEM_ID, "primaryCall()");
    vm.stopPrank();

    vm.prank(deployer);
    world.grantAccess(Classes._tableId, address(systemMock));
  }

  function testSetup() public {
    // mock systems are registered on the World
    assertEq(ResourceIds.getExists(MOCK_SYSTEM_ID), true);
  }

  // ensure that calling view functions directly no longer throw staticcall errors
  // NOTE: view calls are not recorded in the World transient context because they don't change state and are not relevant for any chain of internal calls in this regard
  function testViewCall() public {
    // test direct call to a view function
    bytes memory returnData = world.call(MOCK_SYSTEM_ID, abi.encodeCall(SystemMock.viewCall, ()));
    // Decode the returned data from the target system
    bool result = abi.decode(returnData, (bool));
    assertEq(result, true);
  }

  function testTransientContextUsingCall() public {
    vm.prank(alice);
    (, bytes memory returnData) = address(worldAddress).call{ value: 1 ether }(
      abi.encodeCall(IWorldCall.call, (MOCK_SYSTEM_ID, abi.encodeCall(SystemMock.primaryCall, ())))
    );

    (, , , , TransientContext memory transientContext1, TransientContext memory transientContext2) = abi.decode(
      returnData,
      (bytes32, bytes32, bytes32, bytes32, TransientContext, TransientContext)
    );

    assertEq(ResourceId.unwrap(transientContext1.systemId), ResourceId.unwrap(MOCK_SYSTEM_ID)); // primaryCall systemId
    assertEq(ResourceId.unwrap(transientContext2.systemId), ResourceId.unwrap(MOCK_SYSTEM_ID)); // secondaryCall systemId
    assertEq(transientContext1.functionId, SystemMock.primaryCall.selector); // primaryCall function selector
    assertEq(transientContext2.functionId, SystemMock.secondaryCall.selector); // secondaryCall function selector
    assertEq(transientContext1.msgSender, alice); // primaryCall _msgSender()
    assertEq(transientContext2.msgSender, address(systemMock)); // secondaryCall _msgSender()
    assertEq(transientContext1.msgValue, 1 ether); // primaryCall _msgValue()
    assertEq(transientContext2.msgValue, 0); // secondaryCall _msgValue()
  }

  function testTransientContextUsingCallFrom() public {
    // Register an unlimited delegation
    address delegator = deployer;
    address delegatee = alice;
    vm.prank(delegator);
    world.registerDelegation(delegatee, UNLIMITED_DELEGATION, new bytes(0));

    // Call from the delegatee on behalf of the delegator
    vm.prank(delegatee);
    (, bytes memory returnData) = address(worldAddress).call{ value: 1 ether }(
      abi.encodeCall(IWorldCall.callFrom, (delegator, MOCK_SYSTEM_ID, abi.encodeCall(SystemMock.primaryCall, ())))
    );

    (, , , , TransientContext memory transientContext1, TransientContext memory transientContext2) = abi.decode(
      returnData,
      (bytes32, bytes32, bytes32, bytes32, TransientContext, TransientContext)
    );

    assertEq(ResourceId.unwrap(transientContext1.systemId), ResourceId.unwrap(MOCK_SYSTEM_ID)); // primaryCall systemId
    assertEq(ResourceId.unwrap(transientContext2.systemId), ResourceId.unwrap(MOCK_SYSTEM_ID)); // secondaryCall systemId
    assertEq(transientContext1.functionId, SystemMock.primaryCall.selector); // primaryCall function selector
    assertEq(transientContext2.functionId, SystemMock.secondaryCall.selector); // secondaryCall function selector
    assertEq(transientContext1.msgSender, delegator); // primaryCall _msgSender()
    assertEq(transientContext2.msgSender, address(systemMock)); // secondaryCall _msgSender()
    assertEq(transientContext1.msgValue, 1 ether); // primaryCall _msgValue()
    assertEq(transientContext2.msgValue, 0); // secondaryCall _msgValue()
  }

  function testTransientContextUsingFallback() public {
    string memory namespaceString = WorldResourceIdLib.toTrimmedString(NAMESPACE);
    string memory worldFunctionSignature = string.concat(namespaceString, "__", "primaryCall()");
    bytes4 worldFunctionSelector = bytes4(keccak256(bytes(worldFunctionSignature)));
    vm.prank(alice);
    (, bytes memory returnData) = address(worldAddress).call{ value: 1 ether }(
      abi.encodeWithSelector(worldFunctionSelector)
    );
    (, , TransientContext memory transientContext1, TransientContext memory transientContext2) = abi.decode(
      returnData,
      (bytes32, bytes32, TransientContext, TransientContext)
    );

    assertEq(ResourceId.unwrap(transientContext1.systemId), ResourceId.unwrap(MOCK_SYSTEM_ID)); // primaryCall systemId
    assertEq(ResourceId.unwrap(transientContext2.systemId), ResourceId.unwrap(MOCK_SYSTEM_ID)); // secondaryCall systemId
    assertEq(transientContext1.functionId, SystemMock.primaryCall.selector); // primaryCall function selector
    assertEq(transientContext2.functionId, SystemMock.secondaryCall.selector); // secondaryCall function selector
    assertEq(transientContext1.msgSender, alice); // primaryCall _msgSender()
    assertEq(transientContext2.msgSender, address(systemMock)); // secondaryCall _msgSender()
    assertEq(transientContext1.msgValue, 1 ether); // primaryCall _msgValue()
    assertEq(transientContext2.msgValue, 0); // secondaryCall _msgValue()
  }
}
