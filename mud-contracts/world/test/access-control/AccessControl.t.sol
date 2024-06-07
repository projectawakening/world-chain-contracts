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
import { IInventory } from "../../src/modules/inventory/interfaces/IInventory.sol";
import { IEphemeralInventory } from "../../src/modules/inventory/interfaces/IEphemeralInventory.sol";
import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { SmartStorageUnitModule } from "../../src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";

// Access Control
import { IAccessControlErrors } from "../../src/modules/access-control/interfaces/IAccessControlErrors.sol";
import { IAccessControl } from "../../src/modules/access-control/interfaces/IAccessControl.sol";
import { AccessControl } from "../../src/modules/access-control/systems/AccessControl.sol";

import { AccessRole, AccessRoleTableId, AccessEnforcement, AccessEnforcementTableId } from "../../src/codegen/index.sol";

import { ADMIN, APPROVED, EVE_WORLD_NAMESPACE, ACCESS_ROLE_TABLE_NAME, ACCESS_CONTROL_SYSTEM_NAME } from "../../src/modules/access-control/constants.sol";

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

  address deployer = vm.addr(deployerPK);
  address alice = vm.addr(alicePK);
  address bob = vm.addr(bobPK);

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
  uint256 itemId = 12;
  uint256 typeId = 3;
  uint256 volume = 10;

  // Access Control Variables
  AccessControl accessControl;
  ResourceId ACCESS_CONTROL_SYSTEM_ID = WorldResourceIdLib.encode({
    typeId: RESOURCE_SYSTEM,
    namespace: EVE_WORLD_NAMESPACE,
    name: bytes16("AccessControl")
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
    AccessRole.register();
    AccessEnforcement.register();
    // deploy AccessControl System 
    accessControl = new AccessControl();
    // register AccessControl Systems - to root
    world.registerSystem(ACCESS_CONTROL_SYSTEM_ID, System(accessControl), true);

     // END: DEPLOY AND REGISTER FOR EVE WORLD

    // START: WORLD CONFIGURATION
    SOFInterface = SmartObjectLib.World(world, EVE_WORLD_NAMESPACE);
    SDInterface = SmartDeployableLib.World(world, EVE_WORLD_NAMESPACE);
    SSUInterface = SmartStorageUnitLib.World(world, EVE_WORLD_NAMESPACE);

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
    vm.startPrank(alice);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));

    // success, granted
    world.grantAccess(AccessRoleTableId, alice);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (ADMIN, adminAccessList)));
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessListByRole, (APPROVED, approvedAccessList)));
    vm.stopPrank();

    // verify table updates
    address[] memory storedAdminAccessList = AccessRole.get(ADMIN);
    assertEq(storedAdminAccessList[0], alice);
    address[] memory storedApprovedAccessList = AccessRole.get(APPROVED);
    assertEq(storedApprovedAccessList[0], address(interact));

  }

  function testSetAccessEnforcement() public {
    bytes32 target = keccak256(abi.encodePacked(EVE_WORLD_NAMESPACE.inventorySystemId(), IInventory.setInventoryCapacity.selector));
    // failure, not granted
    vm.expectRevert(
      IAccessControlErrors.AccessControl_AccessConfigAccessDenied.selector
    );
    vm.startPrank(alice);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));

    // success, granted
    world.grantAccess(AccessRoleTableId, alice);
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));
    vm.stopPrank();

    // verify table updates
    bool isEnforced = AccessEnforcement.get(target);
    assertEq(isEnforced, true);
  }

  function testModifiedFunctionEnforcement() public {
    address[] memory adminAccessList = new address[](1);
    adminAccessList[0] = deployer;
    world.grantAccess(AccessRoleTableId, alice);
    vm.startPrank(alice, alice);
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
    world.call(ACCESS_CONTROL_SYSTEM_ID, abi.encodeCall(IAccessControl.setAccessEnforcement, (target, true)));
    InventoryInterface.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();
  }

  function testOnlyAdmin() public {
    // success, ADMIN pass
    // reject, not ADMIN 
  }

function testOnlyAdminOrObjectOwner() public {
    // success, ADMIN pass
    // success, OWNER pass
    // reject, not ADMIN nor OWNER
  }

  function testNoAccess() public {
    // reject, is ADMIN
    // reject, is OWNER
    // reject, is APPROVED
  }


  function testOnlyAdminWithEphInvOwnerOrApproved() public {
    // success, is ADMIN, is EPH INV OWNER, is not APPROVED
    // success, is not ADMIN, is EPH INV OWNER, is APPROVED
    // success, is ADMIN, is not EPH INV OWNER, is APPROVED
    // reject, is not ADMIN, is EPH INV OWNER, is not APPROVED
    // reject, is ADMIN, is not EPH INV OWNER, is not APPROVED
  }

  function testOnlyAdminWithObjectOwnerOrApproved() public {
    // success, is ADMIN, is OWNER, is not APPROVED
    // success, is not ADMIN, is OWNER, is APPROVED
    // success, is ADMIN, is not OWNER, is APPROVED
    // reject, is not ADMIN, is OWNER, is not APPROVED
    // reject, is ADMIN, is not OWNER, is not APPROVED
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
