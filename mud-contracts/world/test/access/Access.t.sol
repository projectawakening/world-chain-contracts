// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";

// SOF imports
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { Utils as SOFUtils } from "@eveworld/smart-object-framework/src/utils.sol";

// SD & dependency imports
import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { ISmartDeployableSystem } from "../../src/modules/smart-deployable/interfaces/ISmartDeployableSystem.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

//SSU & dependency imports
import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { IInventorySystem } from "../../src/modules/inventory/interfaces/IInventorySystem.sol";
import { IEphemeralInventorySystem } from "../../src/modules/inventory/interfaces/IEphemeralInventorySystem.sol";
import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";

import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";

// Access Control
import { IAccessSystemErrors } from "../../src/modules/access/interfaces/IAccessSystemErrors.sol";
import { IAccessSystem } from "../../src/modules/access/interfaces/IAccessSystem.sol";

import { AccessRole, AccessRolePerSys, AccessEnforcement } from "../../src/codegen/index.sol";
import { MockForwarder } from "./MockForwarder.sol";

import { ADMIN, APPROVED, EVE_WORLD_NAMESPACE as FRONTIER_WORLD_DEPLOYMENT_NAMESPACE, ACCESS_ROLE_TABLE_NAME, ACCESS_ROLE_PER_SYSTEM_TABLE_NAME, ACCESS_ENFORCEMENT_TABLE_NAME, ACCESS_SYSTEM_NAME } from "../../src/modules/access/constants.sol";
import { ENTITY_SYSTEM_NAME, MODULE_SYSTEM_NAME, HOOK_SYSTEM_NAME } from "@eveworld/smart-object-framework/src/constants.sol";
import { EntityMap, EntityTable, EntityType, EntityTypeAssociation, HookTargetBefore, HookTargetAfter, ModuleSystemLookup } from "@eveworld/smart-object-framework/src/codegen/index.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";

contract AccessTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartDeployableUtils for bytes14;
  using InventoryUtils for bytes14;
  using SOFUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using EntityRecordLib for EntityRecordLib.World;

  // account variables
  // default foundry anvil mnemonic
  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);
  uint256 charliePK = vm.deriveKey(mnemonic, 3);

  address deployer = vm.addr(deployerPK);
  address alice = vm.addr(alicePK);
  address bob = vm.addr(bobPK);
  address charlie = vm.addr(charliePK);

  IWorldWithEntryContext world;

  // SOF variables
  SmartObjectLib.World SOFInterface;
  uint8 constant CLASS = 2;
  uint256 sdClassId = uint256(keccak256("SD_CLASS"));
  uint256 ssuClassId = uint256(keccak256("SSU_CLASS"));
  uint256 scClassId = uint256(keccak256("SMART_CHARACTER_CLASS"));

  // Deployable variables
  EntityRecordLib.World EntityRecordInterface;
  SmartDeployableLib.World SDInterface;
  bytes14 constant ERC721_DEPLOYABLE_NAMESPACE = bytes14("erc721deploybl");
  address erc721SmartDeployableToken;

  // SSU variables
  SmartStorageUnitLib.World SSUInterface;
  ResourceId SMART_STORAGE_UNIT_SYSTEM_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: bytes16("SmartStorageUnit")
    });

  uint256 ssuId = uint256(keccak256("SSU_DUMMY"));

  // inventory variables
  InventoryLib.World InventoryInterface;
  address interact;

  uint256 inventoryItemId = 12345;
  uint256 itemId = 0;
  uint256 typeId = 3;
  uint256 volume = 10;

  // Access Control Variables
  MockForwarder mockForwarder;
  ResourceId ACCESS_SYSTEM_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: ACCESS_SYSTEM_NAME
    });

  ResourceId MOCK_FORWARDER_SYSTEM_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: bytes16("MockForwarder")
    });

  ResourceId ACCESS_ROLE_TABLE_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_TABLE,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: ACCESS_ROLE_TABLE_NAME
    });

  ResourceId ACCESS_ROLE_PER_SYSTEM_TABLE_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_TABLE,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: ACCESS_ROLE_PER_SYSTEM_TABLE_NAME
    });

  ResourceId ACCESS_ENFORCEMENT_TABLE_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_TABLE,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: ACCESS_ENFORCEMENT_TABLE_NAME
    });

  function setUp() public override {
    vm.startPrank(deployer);

    // START: DEPLOY AND REGISTER FOR EVE WORLD
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);
    // DEPLOY AND REGISTER FOR MOCK FORWARDER
    // deploy MockForwarder System
    mockForwarder = new MockForwarder();
    // register MockForwarder System
    world.registerSystem(MOCK_FORWARDER_SYSTEM_ID, System(mockForwarder), true);
    // END: DEPLOY AND REGISTER FOR EVE WORLD

    // START: WORLD CONFIGURATION
    SOFInterface = SmartObjectLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    SDInterface = SmartDeployableLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    SSUInterface = SmartStorageUnitLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    EntityRecordInterface = EntityRecordLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    InventoryInterface = InventoryLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);

    // SOF setup
    // register the SD CLASS ID as a CLASS entity
    SOFInterface.registerEntity(sdClassId, CLASS);

    // register the SSU CLASS ID as a CLASS entity
    SOFInterface.registerEntity(ssuClassId, CLASS);

    //register SMART CHARACTER CLASS ID as a CLASS entity
    SOFInterface.registerEntity(scClassId, CLASS);

    // SD setup
    // active SDs
    SDInterface.globalResume();

    // SSU setup
    erc721SmartDeployableToken = ERC721Registry.get(
      ERC721_REGISTRY_TABLE_ID,
      WorldResourceIdLib.encodeNamespace(ERC721_DEPLOYABLE_NAMESPACE)
    );
    // set ssu classId in the config
    SSUInterface.setSSUClassId(ssuClassId);

    // create a test SSU Object (internally registers SSU ID as Object and tags it to SSU CLASS ID)
    SSUInterface.createAndAnchorSmartStorageUnit(
      ssuId,
      EntityRecordData({ typeId: 7888, itemId: 111, volume: 10 }),
      SmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionIntervalInSeconds,
      1000000 * 1e18, //fuelMaxCapacity,
      100000000, // storageCapacity,
      100000000000 // ephemeralStorageCapacity
    );

    // put SSU in a state to accept Items
    SDInterface.depositFuel(ssuId, 200000);

    SDInterface.bringOnline(ssuId);

    EntityRecordInterface.createEntityRecord(inventoryItemId, itemId, typeId, volume);

    interact = Systems.getSystem(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventoryInteractSystemId());
    // END: WORLD CONFIGURATION

    // GRANT ACCESS
    world.grantAccess(ACCESS_ROLE_TABLE_ID, deployer);
    world.grantAccess(ACCESS_ROLE_TABLE_ID, alice);
    // not bob so we have an account to test against
    world.grantAccess(ACCESS_ROLE_TABLE_ID, charlie);

    world.grantAccess(ACCESS_ROLE_PER_SYSTEM_TABLE_ID, deployer);
    world.grantAccess(ACCESS_ROLE_PER_SYSTEM_TABLE_ID, alice);
    // not bob so we have an account to test against
    world.grantAccess(ACCESS_ROLE_PER_SYSTEM_TABLE_ID, charlie);

    world.grantAccess(ACCESS_ENFORCEMENT_TABLE_ID, deployer);
    world.grantAccess(ACCESS_ENFORCEMENT_TABLE_ID, alice);
    // not bob so we have an account to test against
    world.grantAccess(ACCESS_ENFORCEMENT_TABLE_ID, charlie);
    vm.stopPrank();
  }

  function testSetup() public {
    // TODO - test Access system registered into EVE World correctly
  }

  function testSetAccessListByRole() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = alice;

    // failure, not granted
    vm.expectRevert(IAccessSystemErrors.AccessSystem_AccessConfigDenied.selector);
    vm.prank(bob);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));

    // success, granted
    vm.startPrank(deployer);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    vm.stopPrank();

    // verify table updates
    address[] memory storedAdminAccessList = AccessRole.get(ADMIN);
    assertEq(storedAdminAccessList[0], alice);
  }

  function testSetAccessListPerSystemByRole() public {
    address[] memory approvedAccessList = new address[](1);
    approvedAccessList[0] = interact;
    // failure, not granted
    vm.expectRevert(IAccessSystemErrors.AccessSystem_AccessConfigDenied.selector);
    vm.prank(bob);
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(), APPROVED, approvedAccessList)
      )
    );

    // success, granted
    vm.startPrank(deployer);
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    vm.stopPrank();

    // verify table updates
    address[] memory storedApprovedAccessList = AccessRolePerSys.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
      APPROVED
    );
    assertEq(storedApprovedAccessList[0], interact);
  }

  function testSetAccessEnforcement() public {
    bytes32 target = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.setInventoryCapacity.selector
      )
    );
    // failure, not granted
    vm.expectRevert(IAccessSystemErrors.AccessSystem_AccessConfigDenied.selector);
    vm.prank(bob);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));

    // success, granted
    vm.startPrank(deployer);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));
    vm.stopPrank();

    // verify table updates
    bool isEnforced = AccessEnforcement.get(target);
    assertEq(isEnforced, true);
  }

  function testModifiedFunctionEnforcement() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    vm.startPrank(deployer, alice);
    // success, not enforced
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    bytes32 target = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.setInventoryCapacity.selector
      )
    );
    // expected rejection, enforced
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, bytes32(ADMIN))
    );
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    // success, not enforced
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, false)));
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();
  }

  function testOnlyAdmin() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.setInventoryCapacity.selector
      )
    );
    // success, ADMIN pass
    vm.startPrank(deployer, deployer);
    // set admin
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));
    // successful call from ADMIN tx.origin
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();

    // reject, not ADMIN
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, bytes32(ADMIN))
    );
    vm.startPrank(deployer, alice); // alice is not ADMIN
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();
  }

  function testOnlyAdminOrObjectOwner() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target1 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
        ISmartDeployableSystem.bringOffline.selector
      )
    );
    bytes32 target2 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
        ISmartDeployableSystem.bringOnline.selector
      )
    );
    vm.startPrank(alice, deployer);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target1, true)));
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target2, true)));

    // success, OWNER and ADMIN pass
    SDInterface.bringOffline(ssuId);
    vm.stopPrank();

    // success, OWNER only pass
    vm.prank(alice, alice);
    SDInterface.bringOnline(ssuId);
  }

  function testOnlyAdminOrObjectOwner2() public {
    // new initialization with charlie who is not ADMIN nor OWNER, this is needed fro initMsgSender testing since parnk don't reliably update transient storage values in the same test
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target1 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
        ISmartDeployableSystem.bringOnline.selector
      )
    );
    vm.startPrank(charlie, charlie);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target1, true)));

    // reject, not ADMIN nor OWNER
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, charlie, bytes32(ADMIN))
    );
    SDInterface.bringOnline(ssuId);
    vm.stopPrank();
  }

  function testOnlyAdminOrObjectOwner3() public {
    // new initialization with charlie as msg.sender who is not ADMIN nor OWNER, this is needed fro initMsgSender testing since parnk don't reliably update transient storage values in the same test
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target1 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
        ISmartDeployableSystem.bringOffline.selector
      )
    );
    vm.startPrank(charlie, deployer);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target1, true)));

    // success, ADMIN only pass
    SDInterface.bringOffline(ssuId);
    vm.stopPrank();
  }

  function testNoAccess() public {
    ResourceId ERC721_SYSTEM_ID = WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: ERC721_DEPLOYABLE_NAMESPACE,
      name: bytes16("ERC721System")
    });
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target = keccak256(abi.encodePacked(ERC721_SYSTEM_ID, IERC721.transferFrom.selector));
    vm.startPrank(charlie, deployer);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));

    // reject, is ADMIN
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(0), bytes32(0))
    );
    IERC721(erc721SmartDeployableToken).transferFrom(deployer, alice, ssuId);
    vm.stopPrank();
  }

  function testNoAccess2() public {
    ResourceId ERC721_SYSTEM_ID = WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: ERC721_DEPLOYABLE_NAMESPACE,
      name: bytes16("ERC721System")
    });
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target = keccak256(abi.encodePacked(ERC721_SYSTEM_ID, IERC721.transferFrom.selector));
    vm.startPrank(deployer, charlie);
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));

    // reject, is OWNER
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(0), bytes32(0))
    );
    IERC721(erc721SmartDeployableToken).transferFrom(deployer, alice, ssuId);
    vm.stopPrank();
  }

  function testNoAccess3() public {
    ResourceId ERC721_SYSTEM_ID = WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: ERC721_DEPLOYABLE_NAMESPACE,
      name: bytes16("ERC721System")
    });
    address[] memory approvedAccessList = new address[](1);
    approvedAccessList[0] = address(mockForwarder);
    bytes32 target = keccak256(abi.encodePacked(ERC721_SYSTEM_ID, IERC721.transferFrom.selector));
    vm.startPrank(charlie, charlie);
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(IAccessSystem.setAccessListPerSystemByRole, (ERC721_SYSTEM_ID, APPROVED, approvedAccessList))
    );
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, true)));

    // reject, is APPROVED
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(0), bytes32(0))
    );
    world.call(MOCK_FORWARDER_SYSTEM_ID, abi.encodeCall(MockForwarder.callERC721, (deployer, alice, ssuId)));
    vm.stopPrank();
  }

  function testOnlyAdminOrApproved() public {
    InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      quantity: 3
    });

    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      quantity: 1
    });
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    address[] memory approvedAccessList = new address[](1);
    approvedAccessList[0] = interact;
    bytes32 target1 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
        IEphemeralInventorySystem.depositToEphemeralInventory.selector
      )
    );
    bytes32 target2 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
        IEphemeralInventorySystem.withdrawFromEphemeralInventory.selector
      )
    );

    // ENV INV OWNER AND ADMIN
    vm.startPrank(alice, deployer);
    // no permissions enforced.. populate items and test flows with free calls
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    // set ADMIN account
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permissions (deposit)
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target1, true)));
    // enforce permissions (withdrawal)
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target2, true)));

    // success, is ADMIN, is EPH INV OWNER, is not APPROVED (direct call)
    // deposit
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    // withdraw
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    vm.stopPrank();

    // EPH INV OWNER ONLY
    vm.startPrank(alice, alice);
    // reject, is not ADMIN, is EPH INV OWNER, and is not APPROVED (direct call)
    // deposit
    vm.expectRevert(abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, ADMIN)); // expect ADMIN fail revert because this is a direct call
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    // withdraw
    vm.expectRevert(abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, ADMIN));
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);

    // set APPROVED account (only InventoryInteract)
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    // make forwarded call
    // success, is not ADMIN, is EPH INV OWNER, is APPROVED (forwarded call from InventoryInteract)
    // this implies both EphemeralInventory.withdrawalFromEphemeralInventory and Inventory.depostiToInventory pass under APPROVED conditions
    InventoryInterface.ephemeralToInventoryTransfer(ssuId, outItems);

    vm.expectRevert( // revert with the APPROVED fail error because this was a cross system call form the Mock Forawrder (who has not been added to the APPROVED list for our systems)
        abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(mockForwarder), APPROVED)
      );
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.openEphemeralToInventoryTransfer, (ssuId, alice, outItems))
    );
    vm.stopPrank();
  }

  /**
   * CONFIGURATION TESTS - the following are verbatim configuration code from the correlary access-config /script respectively
   */
}
