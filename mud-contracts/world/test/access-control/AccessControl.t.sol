// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

// MUD World and world helpers imports
import { World } from "@latticexyz/world/src/World.sol";
import { IWorldErrors } from "@latticexyz/world/src/IWorldErrors.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance  } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceAccess } from "@latticexyz/world/src/codegen/tables/ResourceAccess.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";

import { createCoreModule } from "../CreateCoreModule.sol";

// SOF imports
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { HookType } from "@eveworld/smart-object-framework/src/types.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { Utils as SOFUtils } from "@eveworld/smart-object-framework/src/utils.sol";
import { HookTable, HookTargetBefore, EntityAssociation } from "@eveworld/smart-object-framework/src/codegen/index.sol";

import { Utils } from "../../src/modules/entity-record/Utils.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

// SD & dependency imports
import { GlobalDeployableState, DeployableState, DeployableTokenTable, DeployableFuelBalance } from "../../src/codegen/index.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { ISmartDeployable } from "../../src/modules/smart-deployable/interfaces/ISmartDeployable.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

//SSU & dependency imports
import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { Inventory } from "../../src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "../../src/modules/inventory/systems/EphemeralInventory.sol";
import { InventoryInteract } from "../../src/modules/inventory/systems/InventoryInteract.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { IInventoryInteract } from "../../src/modules/inventory/interfaces/IInventoryInteract.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { IInventory } from "../../src/modules/inventory/interfaces/IInventory.sol";
import { IEphemeralInventory } from "../../src/modules/inventory/interfaces/IEphemeralInventory.sol";
import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { SmartStorageUnitModule } from "../../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";


// Access Control
import { IAccessControlErrors } from "../../src/modules/access-control/interfaces/IAccessControlErrors.sol";
import { IAccessControl } from "../../src/modules/access-control/interfaces/IAccessControl.sol";
import { AccessControl } from "../../src/modules/access-control/systems/AccessControl.sol";

import { AccessRole, AccessEnforcement } from "../../src/codegen/index.sol";
import { MockForwarder } from "./MockForwarder.sol";

import { ADMIN, APPROVED, EVE_WORLD_NAMESPACE, ACCESS_ROLE_TABLE_NAME, ACCESS_ENFORCEMENT_TABLE_NAME, ACCESS_CONTROL_SYSTEM_NAME } from "../../src/modules/access-control/constants.sol";

contract AccessControlTest is Test {
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

  IBaseWorld world;

  // SOF variables
  SmartObjectLib.World SOFInterface;
  uint8 constant OBJECT = 1;
  string constant OBJECT_STRING = "OBJECT";
  uint8 constant CLASS = 2;
  string constant CLASS_STRING = "CLASS";
  uint256 sdClassId = uint256(keccak256("SD_CLASS"));
  uint256 ssuClassId = uint256(keccak256("SSU_CLASS"));
  uint256 scClassId = uint256(keccak256("SMART_CHARACTER_CLASS"));

  // Deployable variables
  EntityRecordLib.World EntityRecordInterface;
  SmartDeployableLib.World SDInterface;
  bytes14 constant ERC721_DEPLOYABLE_NAMESPACE = "SDERC721Token";
  IERC721Mintable erc721DeployableToken;

  // SSU variables
  SmartStorageUnitLib.World SSUInterface;
  ResourceId SMART_STORAGE_UNIT_SYSTEM_ID = WorldResourceIdLib.encode({
    typeId: RESOURCE_SYSTEM,
    namespace: EVE_WORLD_NAMESPACE,
    name: bytes16("SmartStorageUnit")
  });

  uint256 ssuId = uint256(keccak256("SSU_DUMMY"));

  // inventory variables
  InventoryLib.World InventoryInterface;
  Inventory inventory;
  InventoryInteract interact;
  EphemeralInventory ephemeral;

  uint256 inventoryItemId = 12345;
  uint256 itemId = 0;
  uint256 typeId = 3;
  uint256 volume = 10;

  // Access Control Variables
  AccessControl accessControl;
  MockForwarder mockForwarder;
  ResourceId ACCESS_CONTROL_SYSTEM_ID = WorldResourceIdLib.encode({
    typeId: RESOURCE_SYSTEM,
    namespace: EVE_WORLD_NAMESPACE,
    name: ACCESS_CONTROL_SYSTEM_NAME
  });

  ResourceId MOCK_FORWARDER_SYSTEM_ID = WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: EVE_WORLD_NAMESPACE,
      name: bytes16("MockForwarder")
    });

  ResourceId ACCESS_ROLE_TABLE_ID = WorldResourceIdLib.encode({
    typeId: RESOURCE_TABLE,
    namespace: EVE_WORLD_NAMESPACE,
    name: ACCESS_ROLE_TABLE_NAME
  });

  ResourceId ACCESS_ENFORCEMENT_TABLE_ID = WorldResourceIdLib.encode({
    typeId: RESOURCE_TABLE,
    namespace: EVE_WORLD_NAMESPACE,
    name: ACCESS_ENFORCEMENT_TABLE_NAME
  });

  function setUp() public {
    // START: DEPLOY AND REGISTER FOR EVE WORLD
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    StoreSwitch.setStoreAddress(address(world));

    // SMART OBJECT FRAMEWORK DEPLOY AND REGISTER
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(EVE_WORLD_NAMESPACE, address(new EntityCore()), address(new HookCore()), address(new ModuleCore()))
    );

    // SMART DEPLOYABLE DEPLOY AND REGISTER
    _sdDependenciesDeploy(world);
  
    GlobalDeployableState.register(EVE_WORLD_NAMESPACE.globalStateTableId());
    DeployableState.register(EVE_WORLD_NAMESPACE.deployableStateTableId());
    DeployableTokenTable.register(EVE_WORLD_NAMESPACE.deployableTokenTableId());
    DeployableFuelBalance.register(EVE_WORLD_NAMESPACE.deployableFuelBalanceTableId());
    SmartDeployable deployable = new SmartDeployable();
    world.registerSystem(EVE_WORLD_NAMESPACE.smartDeployableSystemId(), System(deployable), true);
 
    // SMART STORAGE UNIT DEPLOY AND REGISTER
    _ssuDependenciesDeploy(world);

    SmartStorageUnitModule SSUMod = new SmartStorageUnitModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE), address(SSUMod));
    world.installModule(SSUMod, abi.encode(EVE_WORLD_NAMESPACE));
    
    // DEPLOY AND REGISTER FOR ACCESS CONTROL
    AccessRole.register(ACCESS_ROLE_TABLE_ID);
    AccessEnforcement.register(ACCESS_ENFORCEMENT_TABLE_ID);
    // deploy AccessControl System 
    accessControl = new AccessControl();
    // register AccessControl System
    world.registerSystem(ACCESS_CONTROL_SYSTEM_ID, System(accessControl), true);

    // deploy MockForwarder System 
   mockForwarder  = new MockForwarder();
    // register MockForwarder System
    world.registerSystem(MOCK_FORWARDER_SYSTEM_ID, System(mockForwarder), true);

     // END: DEPLOY AND REGISTER FOR EVE WORLD

    // START: WORLD CONFIGURATION
    SOFInterface = SmartObjectLib.World(world, EVE_WORLD_NAMESPACE);
    SDInterface = SmartDeployableLib.World(world, EVE_WORLD_NAMESPACE);
    SSUInterface = SmartStorageUnitLib.World(world, EVE_WORLD_NAMESPACE);
    EntityRecordInterface = EntityRecordLib.World(world, EVE_WORLD_NAMESPACE);
    InventoryInterface = InventoryLib.World(world, EVE_WORLD_NAMESPACE);

    // SOF setup
    // create class and object types
    SOFInterface.registerEntityType(CLASS, bytes32(bytes(CLASS_STRING)));
    SOFInterface.registerEntityType(OBJECT, bytes32(bytes(OBJECT_STRING)));
    // allow object to class tagging
    SOFInterface.registerEntityTypeAssociation(OBJECT, CLASS);

    // register the SD CLASS ID as a CLASS entity
    SOFInterface.registerEntity(sdClassId, CLASS);
    // register the SSU CLASS ID as a CLASS entity
    SOFInterface.registerEntity(ssuClassId, CLASS);

    //register SMART CHARACTER CLASS ID as a CLASS entity
    SOFInterface.registerEntity(scClassId, CLASS);

    // SD setup
    // register an ERC721 for SDs
    SDInterface.registerDeployableToken(address(erc721DeployableToken));
    // active SDs
    SDInterface.globalResume();

    // SSU setup
    // set ssu classId in the config
    SSUInterface.setSSUClassId(ssuClassId);

    // create a test SSU Object (internally registers SSU ID as Object and tags it to SSU CLASS ID)
    SSUInterface.createAndAnchorSmartStorageUnit(
      ssuId,
      EntityRecordData({ typeId: 7888, itemId: 111, volume: 10 }),
      SmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionPerMinute,
      1000000 * 1e18, //fuelMaxCapacity,
      100000000, // storageCapacity,
      100000000000 // ephemeralStorageCapacity
    );

    // put SSU in a state to accept Items
    SDInterface.depositFuel(ssuId, 200000);
    SDInterface.bringOnline(ssuId);

    EntityRecordInterface.createEntityRecord(inventoryItemId, itemId, typeId, volume);
    // END: WORLD CONFIGURATION
    
    world.grantAccess(ACCESS_ROLE_TABLE_ID, deployer);
    world.grantAccess(ACCESS_ROLE_TABLE_ID, alice);
    // not bob so we have an account to test against 
    world.grantAccess(ACCESS_ROLE_TABLE_ID, charlie);
  }

  function testSetup() public {
      // TODO - test Accesscontrol system registered into EVE World correctly
  }

  function testSetAccessListByRole() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = alice;
    address[] memory approvedAccessList = new address[](1);
    approvedAccessList[0] = address(interact);
    // failure, not granted
    vm.expectRevert(
      IAccessControlErrors.AccessControl_AccessConfigAccessDenied.selector
    );
    vm.prank(bob);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // success, granted
    vm.startPrank(deployer);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    vm.stopPrank();

    // verify table updates
    address[] memory storedAdminAccessList = AccessRole.get(ACCESS_ROLE_TABLE_ID, ADMIN);
    assertEq(storedAdminAccessList[0], alice);
    address[] memory storedApprovedAccessList = AccessRole.get(ACCESS_ROLE_TABLE_ID, APPROVED);
    assertEq(storedApprovedAccessList[0], address(interact));

  }

  function testSetAccessEnforcement() public {
    bytes32 target = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.setInventoryCapacity.selector));
    // failure, not granted
    vm.expectRevert(
      IAccessControlErrors.AccessControl_AccessConfigAccessDenied.selector
    );
    vm.prank(bob);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));

    // success, granted
    vm.startPrank(deployer);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));
    vm.stopPrank();

    // verify table updates
    bool isEnforced = AccessEnforcement.get(ACCESS_ENFORCEMENT_TABLE_ID, target);
    assertEq(isEnforced, true);
  }

  function testModifiedFunctionEnforcement() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    vm.startPrank(deployer, alice);
    // success, not enforced
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    bytes32 target = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.setInventoryCapacity.selector));
    // expected rejection, enforced
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, alice, bytes32(ADMIN))
    );
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    // success, not enforced
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, false)));
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();
  }

  function testOnlyAdmin() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.setInventoryCapacity.selector));
    // success, ADMIN pass
    vm.startPrank(deployer, deployer);
    // set admin
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));
    // successful call from ADMIN tx.origin
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();

    // reject, not ADMIN
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, alice, bytes32(ADMIN))
    );
    vm.startPrank(deployer, alice); // alice is not ADMIN
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();
    
  }

function testOnlyAdminOrObjectOwner() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployable.bringOffline.selector));
    bytes32 target2 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployable.bringOnline.selector));
    vm.startPrank(alice, deployer);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target2, true)));
    
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
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployable.bringOnline.selector));
    vm.startPrank(charlie, charlie);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    
    // reject, not ADMIN nor OWNER
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, bytes32(ADMIN))
    );
    SDInterface.bringOnline(ssuId);
    vm.stopPrank();
  }

  function testOnlyAdminOrObjectOwner3() public {
    // new initialization with charlie as msg.sender who is not ADMIN nor OWNER, this is needed fro initMsgSender testing since parnk don't reliably update transient storage values in the same test
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployable.bringOffline.selector));
    vm.startPrank(charlie, deployer);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permission
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    
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
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));

    // reject, is ADMIN
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, address(0), bytes32(0))
    );
    IERC721(erc721DeployableToken).transferFrom(deployer, alice, ssuId);
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
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));

    // reject, is OWNER
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, address(0), bytes32(0))
    );
    IERC721(erc721DeployableToken).transferFrom(deployer, alice, ssuId);
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
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));
    
    // reject, is APPROVED
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, address(0), bytes32(0))
    );
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.callERC721, (deployer, alice, ssuId))
    );
    vm.stopPrank();
    
  }

  function testOnlyAdminWithEphInvOwnerOrApproved() public {
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
    approvedAccessList[0] = address(interact);
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.ephemeralInventorySystemId(), IEphemeralInventory.depositToEphemeralInventory.selector));
    bytes32 target2 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.ephemeralInventorySystemId(), IEphemeralInventory.withdrawFromEphemeralInventory.selector));
    
    // ENV INV OWNER AND ADMIN
    vm.startPrank(alice, deployer);
    // no permissions enforced.. populate items and test flows with free calls
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);    
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    // set ADMIN account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permissions (deposit)
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    // enforce permissions (withdrawal) 
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target2, true)));
    
    // success, is ADMIN, is EPH INV OWNER, is not APPROVED (direct call)
    // deposit 
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    // withdraw
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    vm.stopPrank();

    // EPH INV OWNER ONLY
    vm.startPrank(alice, alice);
    // reject, is not ADMIN, is EPH INV OWNER, is not APPROVED (direct call)
    // deposit
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, alice, ADMIN)
    );
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    // withdraw
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, alice, ADMIN)
    );
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);

    // set APPROVED account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    // make forwarded call
    // success, is not ADMIN, is EPH INV OWNER, is APPROVED (forwarded call)
    // this implies withdrawalFromEphemeralInventory passes under APPROVED conditions
    InventoryInterface.ephemeralToInventoryTransfer(ssuId, outItems);
    vm.stopPrank();
  }

  function testOnlyAdminWithEphInvOwnerOrApproved2() public {
    InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      quantity: 5
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
    address[] memory approvedAccessList = new address[](2);
    approvedAccessList[0] = address(interact);
    approvedAccessList[1] = address(mockForwarder);
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.ephemeralInventorySystemId(), IEphemeralInventory.depositToEphemeralInventory.selector));
    bytes32 target2 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.ephemeralInventorySystemId(), IEphemeralInventory.withdrawFromEphemeralInventory.selector));
    
    // ADMIN ONLY
    vm.startPrank(charlie, deployer);
    // no permissions enforced.. populate items and test flows with free calls
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);    
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    // set ADMIN account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // set APPROVED account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    // enforce permissions (both deposit and withdraw)
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target2, true)));
    
    // reject, is ADMIN, is not EPH INV OWNER, is not APPROVED (direct call)
    // deposit
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    // withdraw
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);

    // make forwarded call
    // is ADMIN, is not EPH INV OWNER, is APPROVED (forwarded call)
    // passes permission modifier because is APPROVED (forwarded call), but then fails the harcoded ephInvOwner requirement in InventoryInteract.ephemeralToInventoryTranfser
    vm.expectRevert(
      abi.encodeWithSelector(IInventoryErrors.Inventory_InvalidItemQuantity.selector,
          "InventoryInteract: Not enough items to transfer",
          inventoryItemId,
          1
        )
    );
    InventoryInterface.ephemeralToInventoryTransfer(ssuId, outItems);

    // successful call, implies EphemeralInventory.withdrawFromEphemeralInventory and Inventory.depositToInventory both work under APPROVED forwarder scenario
    // forwarder call succeeds (if inventory interact logic was open itself and protectable as it should have been)
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.openEphemeralToInventoryTransfer, (ssuId, alice, outItems))
    );
    vm.stopPrank();

    // NEITHER ADMIN NOR EPH INV OWNER
    vm.startPrank(charlie, charlie);
    // reject, is not ADMIN, is not EPH INV OWNER, is not APPROVED (direct call)
    // deposit reject
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, ADMIN)
    );
    InventoryInterface.depositToEphemeralInventory(ssuId, alice, inItems);
    // withdrawal reject
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, ADMIN)
    );
    InventoryInterface.withdrawFromEphemeralInventory(ssuId, alice, outItems);

    // make forwarded call
    // fails the harcoded ephInvOwner requirement in InventoryInteract.ephemeralToInventoryTranfser
    vm.expectRevert(
      abi.encodeWithSelector(IInventoryErrors.Inventory_InvalidItemQuantity.selector,
          "InventoryInteract: Not enough items to transfer",
          inventoryItemId,
          1
        )
    );
    InventoryInterface.ephemeralToInventoryTransfer(ssuId, outItems);

    // successful call, implies EphemeralInventory.withdrawFromEphemeralInventory and Inventory.depositToInventory both work under APPROVED forwarder scenario
    // forwarder call succeeds (if inventory interact logic was open itself and protectable as it should have been)
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.openEphemeralToInventoryTransfer, (ssuId, alice, outItems))
    );
    vm.stopPrank();
  }

  function testOnlyAdminWithObjectOwnerOrApproved() public {
    InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: deployer,
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      quantity: 7
    });

    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: deployer,
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      quantity: 1
    });
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    address[] memory approvedAccessList = new address[](1);
    approvedAccessList[0] = address(interact);
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.depositToInventory.selector));
    bytes32 target2 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.withdrawFromInventory.selector));
    
    // INV OWNER AND ADMIN
    vm.startPrank(alice, deployer);
    // no permissions enforced.. populate items and test flows with free calls
    InventoryInterface.depositToInventory(ssuId,inItems);    
    InventoryInterface.withdrawFromInventory(ssuId, outItems);
    // set ADMIN account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // enforce permissions (deposit)
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    // enforce permissions (withdrawal) 
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target2, true)));
    
    // success, is ADMIN, is EPH INV OWNER, is not APPROVED (direct call)
    // deposit 
    InventoryInterface.depositToInventory(ssuId, inItems);
    // withdraw
    InventoryInterface.withdrawFromInventory(ssuId, outItems);
    vm.stopPrank();

    // OWNER ONLY
    vm.startPrank(alice, alice);
    // reject, is not ADMIN, is OWNER, is not APPROVED (direct call)
    // deposit
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, alice, ADMIN)
    );
    InventoryInterface.depositToInventory(ssuId, inItems);
    // withdraw
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, alice, ADMIN)
    );
    InventoryInterface.withdrawFromInventory(ssuId, outItems);

    // set APPROVED account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    // make forwarded call
    // success, is not ADMIN, is OWNER, is APPROVED (forwarded call)
    // this implies Inventory.withdrawalFromInventory and EphemeralInventory.depositToEphmeralInventory pass under APPROVED conditions
    InventoryInterface.inventoryToEphemeralTransfer(ssuId, outItems);
    InventoryInterface.inventoryToEphemeralTransferWithParam(ssuId, alice, outItems);
    vm.stopPrank();
  }

  function testOnlyAdminWithObjectOwnerOrApproved2() public {
   InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem({
      inventoryItemId: inventoryItemId,
      owner: alice,
      itemId: itemId,
      typeId: typeId,
      volume: volume,
      quantity: 9
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
    approvedAccessList[0] = address(interact);
    bytes32 target1 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.depositToInventory.selector));
    bytes32 target2 = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.withdrawFromInventory.selector));
    
    // ADMIN ONLY
    vm.startPrank(charlie, deployer);
    // no permissions enforced.. populate items and test flows with free calls
    InventoryInterface.depositToInventory(ssuId, inItems);    
    InventoryInterface.withdrawFromInventory(ssuId, outItems);
    // set ADMIN account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    // set APPROVED account
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    // enforce permissions (both deposit and withdraw)
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target1, true)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target2, true)));
    
    // reject, is ADMIN, is not SSU OWNER, is not APPROVED (direct call)
    // deposit
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    InventoryInterface.depositToInventory(ssuId, inItems);
    // withdraw
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    InventoryInterface.withdrawFromInventory(ssuId, outItems);

    // make forwarded call
    // is ADMIN, is not SSU OWNER, is APPROVED (forwarded call)
    // successful call, implies Inventory.withdrawFromInventory and EphemeralInventory.depositToEphemeralInventory both work under APPROVED forwarder scenario
    InventoryInterface.inventoryToEphemeralTransfer(ssuId, outItems);
    InventoryInterface.inventoryToEphemeralTransferWithParam(ssuId, alice, outItems);
    vm.stopPrank();

    // NEITHER ADMIN NOR SSU OWNER
    vm.startPrank(charlie, charlie);
    // reject, is not ADMIN, is not SSU OWNER, is not APPROVED (direct call)
    // deposit reject
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, ADMIN)
    );
    InventoryInterface.depositToInventory(ssuId, inItems);
    // withdrawal reject
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlErrors.AccessControl_NoPermission.selector, charlie, ADMIN)
    );
    InventoryInterface.withdrawFromInventory(ssuId, outItems);

    // make forwarded call
    // successful call, implies EphemeralInventory.withdrawFromEphemeralInventory and Inventory.depositToInventory both work under APPROVED forwarder scenario
    InventoryInterface.inventoryToEphemeralTransfer(ssuId, outItems);
    InventoryInterface.inventoryToEphemeralTransferWithParam(ssuId, alice, outItems);
    vm.stopPrank();
  }

  function _sdDependenciesDeploy(IBaseWorld world_) internal {
    // SD StaticData Module deployment
    StaticDataModule StaticDataMod = new StaticDataModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE), address(StaticDataMod));
    world_.installModule(
      StaticDataMod,
      abi.encode(EVE_WORLD_NAMESPACE)
    );

    // SD EntityRecord Module deployment
    EntityRecordModule EntityRecordMod = new EntityRecordModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE), address(EntityRecordMod));
    world_.installModule(
      EntityRecordMod,
      abi.encode(EVE_WORLD_NAMESPACE)
    );

    // SD Location module deployment
    LocationModule LocMod = new LocationModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE), address(LocMod));
    world_.installModule(
      LocMod,
      abi.encode(EVE_WORLD_NAMESPACE)
    );

    // SD ERC721 deployment
    PuppetModule Erc721Mod = new PuppetModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(ERC721_DEPLOYABLE_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(ERC721_DEPLOYABLE_NAMESPACE), address(Erc721Mod));
    world_.installModule(
      Erc721Mod,
      abi.encode(ERC721_DEPLOYABLE_NAMESPACE)
    );

    erc721DeployableToken = registerERC721(
      world_,
      ERC721_DEPLOYABLE_NAMESPACE,
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: "" })
    );
  }

  function _ssuDependenciesDeploy(IBaseWorld world_) internal {

    // SSU Inventory deployment
    inventory = new Inventory();
    ephemeral = new EphemeralInventory();
    interact = new InventoryInteract();
    InventoryModule InvMod = new InventoryModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(EVE_WORLD_NAMESPACE), address(InvMod));
    world_.installModule(
      InvMod,
      abi.encode(
        EVE_WORLD_NAMESPACE,
        address(inventory),
        address(ephemeral),
        address(interact)
      )
    );
  }

}
