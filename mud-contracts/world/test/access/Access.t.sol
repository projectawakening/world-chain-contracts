// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { console } from "forge-std/console.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";

// SD & dependency imports
import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { ISmartDeployableSystem } from "../../src/modules/smart-deployable/interfaces/ISmartDeployableSystem.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";

//SSU & dependency imports
import { InventoryItem, TransferItem } from "../../src/modules/inventory/types.sol";
import { TransferItem } from "../../src/modules/inventory/types.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { IInventorySystem } from "../../src/modules/inventory/interfaces/IInventorySystem.sol";
import { IEphemeralInventorySystem } from "../../src/modules/inventory/interfaces/IEphemeralInventorySystem.sol";
import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "../../src/modules/smart-storage-unit/types.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { SmartStorageUnitLib } from "../../src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as CharEntityRecordData } from "../../src/modules/smart-character/types.sol";

import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";

// Access Control
import { Utils as AccessUtils } from "../../src/modules/access/Utils.sol";
import { IAccessSystemErrors } from "../../src/modules/access/interfaces/IAccessSystemErrors.sol";
import { IAccessSystem } from "../../src/modules/access/interfaces/IAccessSystem.sol";

import { AccessRole, AccessRolePerSys, AccessEnforcement } from "../../src/codegen/index.sol";
import { MockForwarder } from "./MockForwarder.sol";

import { ADMIN, APPROVED, EVE_WORLD_NAMESPACE as FRONTIER_WORLD_DEPLOYMENT_NAMESPACE, ACCESS_ROLE_TABLE_NAME, ACCESS_ROLE_PER_SYSTEM_TABLE_NAME, ACCESS_ENFORCEMENT_TABLE_NAME, ACCESS_SYSTEM_NAME } from "../../src/modules/access/constants.sol";
import { ENTITY_SYSTEM_NAME, MODULE_SYSTEM_NAME, HOOK_SYSTEM_NAME } from "@eveworld/smart-object-framework/src/constants.sol";
import { EntityMap, EntityTable, EntityType, EntityTypeAssociation, HookTargetBefore, HookTargetAfter, ModuleSystemLookup } from "@eveworld/smart-object-framework/src/codegen/index.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";

import { IEntityRecordSystem } from "../../src/modules/entity-record/interfaces/IEntityRecordSystem.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";

import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { Utils as ERC721Utils } from "../../src/modules/eve-erc721-puppet/Utils.sol";

import { KillMailLib } from "../../src/modules/kill-mail/KillMailLib.sol";
import { IKillMailSystem } from "../../src/modules/kill-mail/interfaces/IKillMailSystem.sol";
import { Utils as KillMailUtils } from "../../src/modules/kill-mail/Utils.sol";
import { KillMailTableData } from "../../src/codegen/tables/KillMailTable.sol";
import { KillMailLossType } from "../../src/codegen/common.sol";

import { LocationLib } from "../../src/modules/location/LocationLib.sol";
import { ILocationSystem } from "../../src/modules/location/interfaces/ILocationSystem.sol";
import { Utils as LocationUtils } from "../../src/modules/location/Utils.sol";
import { LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { ISmartCharacterSystem } from "../../src/modules/smart-character/interfaces/ISmartCharacterSystem.sol";
import { ISmartCharacterErrors } from "../../src/modules/smart-character/ISmartCharacterErrors.sol";
import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { EntityRecordData as CharEntityRecordData } from "../../src/modules/smart-character/types.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

import { SmartAssemblyType } from "../../src/codegen/common.sol";
import { SmartObjectData as DeployableSmartObjectData } from "../../src/modules/smart-deployable/types.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";

import { SmartGateLib } from "../../src/modules/smart-gate/SmartGateLib.sol";
import { ISmartGateSystem } from "../../src/modules/smart-gate/interfaces/ISmartGateSystem.sol";
import { Utils as SmartGateUtils } from "../../src/modules/smart-gate/Utils.sol";

import { SmartTurretLib } from "../../src/modules/smart-turret/SmartTurretLib.sol";
import { ISmartTurretSystem } from "../../src/modules/smart-turret/interfaces/ISmartTurretSystem.sol";
import { Utils as SmartTurretUtils } from "../../src/modules/smart-turret/Utils.sol";

import { ISmartStorageUnitSystem } from "../../src/modules/smart-storage-unit/interfaces/ISmartStorageUnitSystem.sol";
import { Utils as SmartStorageUtils } from "../../src/modules/smart-storage-unit/Utils.sol";

import { StaticDataLib } from "../../src/modules/static-data/StaticDataLib.sol";
import { IStaticDataSystem } from "../../src/modules/static-data/interfaces/IStaticDataSystem.sol";
import { Utils as StaticDataUtils } from "../../src/modules/static-data/Utils.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";

contract AccessTest is MudTest {
  using WorldResourceIdInstance for ResourceId;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartDeployableUtils for bytes14;
  using InventoryUtils for bytes14;
  using AccessUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  using KillMailLib for KillMailLib.World;
  using LocationLib for LocationLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartGateLib for SmartGateLib.World;
  using SmartTurretLib for SmartTurretLib.World;
  using StaticDataLib for StaticDataLib.World;

  using EntityRecordLib for EntityRecordLib.World;
  using EntityRecordUtils for bytes14;
  using ERC721Utils for bytes14;
  using KillMailUtils for bytes14;
  using LocationUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartGateUtils for bytes14;
  using SmartTurretUtils for bytes14;
  using SmartStorageUtils for bytes14;
  using StaticDataUtils for bytes14;

  // account variables
  // default foundry anvil mnemonic
  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 1);
  uint256 bobPK = vm.deriveKey(mnemonic, 2);
  uint256 charliePK = vm.deriveKey(mnemonic, 3);

  address deployer = vm.addr(deployerPK); // ADMIN
  address alice = vm.addr(alicePK); // Object owner, and part time Ephemeral owner
  address bob = vm.addr(bobPK); // owner of nothing
  address charlie = vm.addr(charliePK); // exclusively Ephemeral owner

  IWorldWithEntryContext world;

  KillMailLib.World killMail;
  LocationLib.World location;
  SmartGateLib.World smartGate;
  SmartTurretLib.World smartTurret;
  StaticDataLib.World staticData;

  bytes14 constant ERC721_CHARACTER_NAMESPACE = bytes14("erc721charactr");
  address erc721SmartCharacterToken;
  SmartCharacterLib.World smartCharacter;

  // Deployable variables
  EntityRecordLib.World entityRecord;
  SmartDeployableLib.World smartDeployable;
  bytes14 constant ERC721_DEPLOYABLE_NAMESPACE = bytes14("erc721deploybl");
  address erc721SmartDeployableToken;

  // SSU variables
  SmartStorageUnitLib.World smartStorageUnit;
  ResourceId SMART_STORAGE_UNIT_SYSTEM_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
      name: bytes16("SmartStorageUnit")
    });

  uint256 ssuId = uint256(keccak256("SSU_DUMMY"));

  // inventory variables
  InventoryLib.World inventory;
  address interactAddr;

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

  // SmartCharacter variables
  SmartCharacterLib.World SCInterface;
  uint256 characterId = 1111;

  uint256 tribeId = 1122;
  CharEntityRecordData charEntityRecordData = CharEntityRecordData({ itemId: 1234, typeId: 2345, volume: 0 });

  EntityRecordOffchainTableData charOffchainData =
    EntityRecordOffchainTableData({
      name: "Albus Demunster",
      dappURL: "https://www.my-tribe-website.com",
      description: "The top hunter-seeker in the Frontier."
    });

  string tokenCID = "Qm1234abcdxxxx";

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
    smartDeployable = SmartDeployableLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    smartStorageUnit = SmartStorageUnitLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    entityRecord = EntityRecordLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    inventory = InventoryLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    killMail = KillMailLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    location = LocationLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    smartCharacter = SmartCharacterLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    smartGate = SmartGateLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    smartTurret = SmartTurretLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);
    staticData = StaticDataLib.World(world, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE);

    // SSU setup
    erc721SmartDeployableToken = ERC721Registry.get(
      ERC721_REGISTRY_TABLE_ID,
      WorldResourceIdLib.encodeNamespace(ERC721_DEPLOYABLE_NAMESPACE)
    );

    erc721SmartCharacterToken = ERC721Registry.get(
      ERC721_REGISTRY_TABLE_ID,
      WorldResourceIdLib.encodeNamespace(ERC721_CHARACTER_NAMESPACE)
    );

    smartCharacter.createCharacter(
      3333,
      alice,
      369369,
      CharEntityRecordData(12, 13, 1),
      EntityRecordOffchainTableData("name", "URL", "description"),
      "cid"
    );

    // create a test SSU Object (internally registers SSU ID as Object and tags it to SSU CLASS ID)
    smartStorageUnit.createAndAnchorSmartStorageUnit(
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

    smartDeployable.globalResume();

    // put SSU in a state to accept Items
    smartDeployable.depositFuel(ssuId, 200000);

    smartDeployable.bringOnline(ssuId);

    entityRecord.createEntityRecord(inventoryItemId, itemId, typeId, volume);

    interactAddr = Systems.getSystem(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventoryInteractSystemId());
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
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_AccessConfigDenied.selector, bob, "AccessRole")
    );
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
    approvedAccessList[0] = interactAddr;
    // failure, not granted
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_AccessConfigDenied.selector, bob, "AccessRolePerSys")
    );
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
    assertEq(storedApprovedAccessList[0], interactAddr);
  }

  function testSetAccessEnforcement() public {
    bytes32 target = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.setInventoryCapacity.selector
      )
    );
    // failure, not granted
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_AccessConfigDenied.selector, bob, "AccessEnforcement")
    );
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
    inventory.setInventoryCapacity(ssuId, 100000000);
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
    inventory.setInventoryCapacity(ssuId, 100000000);
    // success, not enforced
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target, false)));
    inventory.setInventoryCapacity(ssuId, 100000000);
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
    inventory.setInventoryCapacity(ssuId, 100000000);
    vm.stopPrank();

    // reject, not ADMIN
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, bytes32(ADMIN))
    );
    vm.startPrank(deployer, alice); // alice is not ADMIN
    inventory.setInventoryCapacity(ssuId, 100000000);
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
    smartDeployable.bringOffline(ssuId);
    vm.stopPrank();

    // success, OWNER only pass
    vm.prank(alice, alice);
    smartDeployable.bringOnline(ssuId);
  }

  function testOnlyAdminOrObjectOwner2() public {
    // new initialization with charlie who is not ADMIN nor OWNER, this is needed fro initMsgSender testing since prank doesn't reliably update transient storage values in the same test
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
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    smartDeployable.bringOnline(ssuId);
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
    smartDeployable.bringOffline(ssuId);
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
    approvedAccessList[0] = interactAddr;
    bytes32 target1 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
        IEphemeralInventorySystem.withdrawFromEphemeralInventory.selector
      )
    );
    bytes32 target2 = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.depositToInventory.selector
      )
    );

    // ENV INV OWNER AND ADMIN
    vm.startPrank(alice, deployer);
    // no permissions enforced.. populate items and test flows with free calls
    inventory.depositToEphemeralInventory(ssuId, alice, inItems);
    inventory.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    inventory.depositToInventory(ssuId, outItems);

    // set ADMIN account
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // set APPROVED account (only InventoryInteract)
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    world.call(
      ACCESS_SYSTEM_ID,
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    // enforce permissions
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target1, true)));
    world.call(ACCESS_SYSTEM_ID, abi.encodeCall(IAccessSystem.setAccessEnforcement, (target2, true)));

    // success, is ADMIN, is EPH INV OWNER, is not APPROVED (direct call)
    inventory.withdrawFromEphemeralInventory(ssuId, alice, outItems);
    inventory.depositToInventory(ssuId, outItems);
    vm.stopPrank();

    // EPH INV OWNER ONLY
    vm.startPrank(alice, alice);
    // reject, is not ADMIN, is EPH INV OWNER, and is not APPROVED (direct call)
    vm.expectRevert(abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, ADMIN));
    inventory.withdrawFromEphemeralInventory(ssuId, alice, outItems);

    vm.expectRevert(abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, alice, ADMIN));
    inventory.depositToInventory(ssuId, inItems);

    TransferItem[] memory transferItemsOut = new TransferItem[](1);
    transferItemsOut[0] = TransferItem(outItems[0].inventoryItemId, outItems[0].owner, outItems[0].quantity);

    // make forwarded call
    // success, is not ADMIN, is EPH INV OWNER, is APPROVED (forwarded call from InventoryInteract)
    // this implies both EphemeralInventory.withdrawalFromEphemeralInventory and Inventory.depostiToInventory pass under APPROVED conditions
    inventory.ephemeralToInventoryTransfer(ssuId, transferItemsOut);

    vm.expectRevert( // revert with the APPROVED fail error because this was a cross system call form the Mock Forwarder (who has not been added to the APPROVED list for our systems)
        abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, address(mockForwarder), APPROVED)
      );
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.unapprovedEphemeralToInventoryTransfer, (ssuId, alice, outItems))
    );
    vm.stopPrank();
  }

  /**
   * CONFIGURATION TESTS - the following are verbatim configuration code from the correlary access-config /script respectively
   */

  function setAccessListConfig(address grantee) public {
    // grantee - deployer, alice or charlie
    address[] memory adminAccounts = vm.envAddress("ADMIN_ACCOUNTS", ",");
    // populate with ALL active ADMIN public addresses
    address[] memory adminAccessList = new address[](adminAccounts.length);

    for (uint i = 0; i < adminAccounts.length; i++) {
      adminAccessList[i] = adminAccounts[i];
    }

    address[] memory approvedAccessList = new address[](1);
    // currently we are only allowing InventoryInteract to be an APPROVED call forwarder to the Inventory and EphemeralInventory systems
    approvedAccessList[0] = interactAddr;

    vm.startPrank(grantee, grantee);
    // set global access list for ADMIN accounts
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList))
    );
    // set access list APPROVED accounts for the InventorySystem
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    // set access list APPROVED accounts for the EphemeralInventorySystem
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(
        IAccessSystem.setAccessListPerSystemByRole,
        (FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(), APPROVED, approvedAccessList)
      )
    );
    vm.stopPrank();

    // test global ADMIN list has been set
    address[] memory storedAdminAccessList = AccessRole.get(ADMIN);
    assertEq(adminAccessList.length, adminAccounts.length);
    for (uint i = 0; i < adminAccessList.length; i++) {
      assertEq(storedAdminAccessList[i], adminAccounts[i]);
    }
    // test APPROVED list for InventorySystem has been set
    address[] memory storedInventoryApprovedAccessList = AccessRolePerSys.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
      APPROVED
    );
    assertEq(storedInventoryApprovedAccessList.length, approvedAccessList.length);
    for (uint i = 0; i < storedInventoryApprovedAccessList.length; i++) {
      assertEq(storedInventoryApprovedAccessList[i], approvedAccessList[i]);
    }
    // test APPROVED list for EphemeralInventorySystem has been set
    address[] memory storedEphemeralInventoryApprovedAccessList = AccessRolePerSys.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
      APPROVED
    );
    assertEq(storedEphemeralInventoryApprovedAccessList.length, approvedAccessList.length);
    for (uint i = 0; i < storedEphemeralInventoryApprovedAccessList.length; i++) {
      assertEq(storedEphemeralInventoryApprovedAccessList[i], approvedAccessList[i]);
    }
    // test that other Systems have not had the APPROVED list set (not global)
    address[] memory storedInventoryInteractApprovedAccessList = AccessRolePerSys.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventoryInteractSystemId(),
      APPROVED
    );
    assertEq(storedInventoryInteractApprovedAccessList.length, 0);
  }

  function setEntityRecordEnforcement(address grantee) public {
    // EntityRecord.createEntityRecord
    bytes32 create = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordSystemId(),
        IEntityRecordSystem.createEntityRecord.selector
      )
    );
    // EntityRecord.createEntityRecordOffchain
    bytes32 createOffChain = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordSystemId(),
        IEntityRecordSystem.createEntityRecordOffchain.selector
      )
    );
    // EntityRecord.setEntityMetadata
    bytes32 setMetadata = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordSystemId(),
        IEntityRecordSystem.setEntityMetadata.selector
      )
    );
    // EntityRecord.setName
    bytes32 setName = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordSystemId(), IEntityRecordSystem.setName.selector)
    );
    // EntityRecord.setDappURL
    bytes32 setDappURL = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordSystemId(),
        IEntityRecordSystem.setDappURL.selector
      )
    );
    // EntityRecord.setDescription
    bytes32 setDescription = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordSystemId(),
        IEntityRecordSystem.setDescription.selector
      )
    );
    vm.startPrank(grantee);
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (create, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (createOffChain, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setMetadata, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setName, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setDappURL, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setDescription, true))
    );
    vm.stopPrank();
  }

  function testSuccessEntityRecordAccessConfig() public {
    setAccessListConfig(alice);
    setEntityRecordEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    entityRecord.createEntityRecord(ssuId, 1, 1, 100);
    entityRecord.createEntityRecordOffchain(ssuId, "name", "URL", "description");
    entityRecord.setEntityMetadata(ssuId, "name", "URL", "description");
    entityRecord.setName(ssuId, "name");
    entityRecord.setDappURL(ssuId, "URL");
    entityRecord.setDescription(ssuId, "description");
    vm.stopPrank();

    // OWNER success
    vm.startPrank(alice, bob);
    entityRecord.createEntityRecordOffchain(ssuId, "name", "URL", "description");
    entityRecord.setEntityMetadata(ssuId, "name", "URL", "description");
    entityRecord.setName(ssuId, "name");
    entityRecord.setDappURL(ssuId, "URL");
    entityRecord.setDescription(ssuId, "description");
    vm.stopPrank();
  }

  function testRevertEntityRecordAccessConfig() public {
    setAccessListConfig(charlie);
    setEntityRecordEnforcement(charlie);

    // NON ADMIN, NON OWNER revert
    vm.startPrank(charlie, bob);
    bytes memory errorMessage = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      charlie,
      bytes32("OWNER")
    );
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    entityRecord.createEntityRecord(ssuId, 1, 1, 100);
    vm.expectRevert(errorMessage);
    entityRecord.createEntityRecordOffchain(ssuId, "name", "URL", "description");
    vm.expectRevert(errorMessage);
    entityRecord.setEntityMetadata(ssuId, "name", "URL", "description");
    vm.expectRevert(errorMessage);
    entityRecord.setName(ssuId, "name");
    vm.expectRevert(errorMessage);
    entityRecord.setDappURL(ssuId, "URL");
    vm.expectRevert(errorMessage);
    entityRecord.setDescription(ssuId, "description");
    vm.stopPrank();
  }

  function setERC721PuppetEnforcement(address grantee) public {
    bytes14 DEPLOYMENT_NAMESPACE = bytes14("erc721deploybl");
    // ERC721System.transferFrom
    bytes32 transferFrom = keccak256(
      abi.encodePacked(DEPLOYMENT_NAMESPACE.erc721SystemId(), IERC721.transferFrom.selector)
    );
    // ERC721System.mint
    bytes32 mint = keccak256(abi.encodePacked(DEPLOYMENT_NAMESPACE.erc721SystemId(), IERC721Mintable.mint.selector));
    // ERC721System.safeMint 1
    bytes32 safeMint1 = keccak256(
      abi.encodePacked(DEPLOYMENT_NAMESPACE.erc721SystemId(), bytes4(keccak256("safeMint(address,uint256)")))
    );
    // ERC721System.safeMint 2
    bytes32 safeMint2 = keccak256(
      abi.encodePacked(DEPLOYMENT_NAMESPACE.erc721SystemId(), bytes4(keccak256("safeMint(address,uint256,bytes)")))
    );
    // ERC721System.burn
    bytes32 burn = keccak256(abi.encodePacked(DEPLOYMENT_NAMESPACE.erc721SystemId(), IERC721Mintable.burn.selector));
    // ERC721System.setCid
    bytes32 setCid = keccak256(
      abi.encodePacked(DEPLOYMENT_NAMESPACE.erc721SystemId(), IERC721Mintable.setCid.selector)
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (transferFrom, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (mint, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (safeMint1, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (safeMint2, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (burn, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setCid, true))
    );
    vm.stopPrank();
  }

  function testSuccessERC721PuppetAccessConfig() public {
    setAccessListConfig(alice);
    setERC721PuppetEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    IERC721Mintable(erc721SmartDeployableToken).mint(alice, 1);
    IERC721Mintable(erc721SmartDeployableToken).safeMint(alice, 2);
    IERC721Mintable(erc721SmartDeployableToken).safeMint(alice, 3, "data");
    IERC721Mintable(erc721SmartDeployableToken).burn(1);
    IERC721Mintable(erc721SmartDeployableToken).setCid(2, "cid");
    vm.stopPrank();
  }

  function testRevertERC721PuppetAccessConfig() public {
    setAccessListConfig(alice);
    setERC721PuppetEnforcement(alice);

    // NON ADMIN
    bytes memory notAdminError = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      bob,
      bytes32(ADMIN)
    );
    vm.startPrank(alice, bob);
    vm.expectRevert(notAdminError);
    IERC721Mintable(erc721SmartDeployableToken).mint(alice, 1);
    vm.expectRevert(notAdminError);
    IERC721Mintable(erc721SmartDeployableToken).safeMint(alice, 2);
    vm.expectRevert(notAdminError);
    IERC721Mintable(erc721SmartDeployableToken).safeMint(alice, 3, "data");
    vm.expectRevert(notAdminError);
    IERC721Mintable(erc721SmartDeployableToken).burn(1);
    vm.expectRevert(notAdminError);
    IERC721Mintable(erc721SmartDeployableToken).setCid(2, "cid");
    vm.stopPrank();

    // both ADMIN and OWNER - but NO ACCESS is set
    bytes memory noAccessError = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      address(0),
      bytes32(0)
    );
    vm.prank(alice, bob);
    vm.expectRevert(noAccessError);
    IERC721Mintable(erc721SmartDeployableToken).transferFrom(alice, bob, 2);
  }

  function setInventoryEnforcement(address grantee) public {
    // Inventory.setInventoryCapacity
    bytes32 invCapacity = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.setInventoryCapacity.selector
      )
    );
    // Inventory.depositToInventory
    bytes32 invDeposit = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.depositToInventory.selector
      )
    );
    // Inventory.withdrawalFromInventory
    bytes32 invWithdraw = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.inventorySystemId(),
        IInventorySystem.withdrawFromInventory.selector
      )
    );

    // EphemeralInventorySystem
    // EphemeralInventory.setEphemeralInventoryCapacity
    bytes32 ephInvCapacity = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
        IEphemeralInventorySystem.setEphemeralInventoryCapacity.selector
      )
    );

    // EphemeralInventory.depositToEphemeralInventory
    bytes32 ephInvDeposit = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
        IEphemeralInventorySystem.depositToEphemeralInventory.selector
      )
    );
    // EphemeralInventory.withdrawalFromEphemeralInventory
    bytes32 ephInvWithdraw = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId(),
        IEphemeralInventorySystem.withdrawFromEphemeralInventory.selector
      )
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (invCapacity, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (invDeposit, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (invWithdraw, true))
    );

    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvCapacity, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvDeposit, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvWithdraw, true))
    );

    vm.stopPrank();
  }

  function testSuccessInventoryAccessConfig() public {
    InventoryItem[] memory invItemsIn = new InventoryItem[](1);
    invItemsIn[0] = InventoryItem({
      inventoryItemId: 1,
      owner: alice,
      itemId: 11,
      typeId: 111,
      volume: 10,
      quantity: 3
    });
    InventoryItem[] memory invItemsOut = new InventoryItem[](1);
    invItemsOut[0] = invItemsIn[0];
    invItemsOut[0].quantity = 1;

    TransferItem[] memory invTransferItemsOut = new TransferItem[](1);
    invTransferItemsOut[0] = TransferItem(
      invItemsOut[0].inventoryItemId,
      invItemsOut[0].owner,
      invItemsOut[0].quantity
    );

    InventoryItem[] memory ephInvItemsIn = new InventoryItem[](1);
    ephInvItemsIn[0] = InventoryItem({
      inventoryItemId: 2,
      owner: alice,
      itemId: 12,
      typeId: 111,
      volume: 10,
      quantity: 3
    });

    InventoryItem[] memory ephInvItemsOut = new InventoryItem[](1);
    ephInvItemsOut[0] = ephInvItemsIn[0];
    ephInvItemsOut[0].quantity = 1;

    TransferItem[] memory ephTransferItemsOut = new TransferItem[](1);
    ephTransferItemsOut[0] = TransferItem(
      ephInvItemsOut[0].inventoryItemId,
      ephInvItemsOut[0].owner,
      ephInvItemsOut[0].quantity
    );

    setAccessListConfig(alice);
    setInventoryEnforcement(alice);

    entityRecord.createEntityRecord(1, 11, 111, 10);
    entityRecord.createEntityRecord(2, 12, 111, 10);

    // ADMIN success
    vm.startPrank(alice, deployer);

    inventory.setInventoryCapacity(ssuId, 100000);
    inventory.depositToInventory(ssuId, invItemsIn);
    inventory.withdrawFromInventory(ssuId, invItemsOut);
    inventory.setEphemeralInventoryCapacity(ssuId, 1000);
    inventory.depositToEphemeralInventory(ssuId, alice, ephInvItemsIn);
    inventory.withdrawFromEphemeralInventory(ssuId, alice, ephInvItemsOut);
    inventory.depositToInventory(ssuId, invItemsIn); // extra items to run interact transfers
    inventory.depositToEphemeralInventory(ssuId, alice, ephInvItemsIn); // extra items to run interact transfers
    vm.stopPrank();

    // APPROVED success
    vm.startPrank(alice, bob);
    // covers inventory.withdrawFromEphemeralInventory and inventory.depositToInventory
    inventory.ephemeralToInventoryTransfer(ssuId, ephTransferItemsOut);
    // covers inventory.withdrawFromInventory and inventory.depositToEphemeralInventory
    inventory.inventoryToEphemeralTransfer(ssuId, alice, invTransferItemsOut);
    vm.stopPrank();
  }

  function testRevertInventoryAccessConfig() public {
    InventoryItem[] memory invItems = new InventoryItem[](1);
    invItems[0] = InventoryItem({ inventoryItemId: 1, owner: alice, itemId: 11, typeId: 111, volume: 10, quantity: 1 });

    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    ephInvItems[0] = InventoryItem({
      inventoryItemId: 2,
      owner: alice,
      itemId: 12,
      typeId: 111,
      volume: 10,
      quantity: 1
    });

    setAccessListConfig(alice);
    setInventoryEnforcement(alice);

    entityRecord.createEntityRecord(1, 11, 111, 10);
    entityRecord.createEntityRecord(2, 12, 111, 10);

    // NON ADMIN revert
    vm.startPrank(alice, bob);
    bytes memory nonAdminError = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      bob,
      bytes32(ADMIN)
    );
    vm.expectRevert(nonAdminError);
    inventory.setInventoryCapacity(ssuId, 100000);
    vm.expectRevert(nonAdminError);
    inventory.setEphemeralInventoryCapacity(ssuId, 1000);

    // NON ADMIN, NON APPROVED revert
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessSystemErrors.AccessSystem_NoPermission.selector,
        address(mockForwarder),
        bytes32(APPROVED)
      )
    );
    world.call(MOCK_FORWARDER_SYSTEM_ID, abi.encodeCall(MockForwarder.callInventoryDeposit, (ssuId, invItems)));
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessSystemErrors.AccessSystem_NoPermission.selector,
        address(mockForwarder),
        bytes32(APPROVED)
      )
    );
    world.call(MOCK_FORWARDER_SYSTEM_ID, abi.encodeCall(MockForwarder.callInventoryWithdraw, (ssuId, invItems)));
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessSystemErrors.AccessSystem_NoPermission.selector,
        address(mockForwarder),
        bytes32(APPROVED)
      )
    );
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.callEphemeralInventoryDeposit, (ssuId, alice, ephInvItems))
    );
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessSystemErrors.AccessSystem_NoPermission.selector,
        address(mockForwarder),
        bytes32(APPROVED)
      )
    );
    world.call(
      MOCK_FORWARDER_SYSTEM_ID,
      abi.encodeCall(MockForwarder.callEphemeralInventoryWithdraw, (ssuId, alice, ephInvItems))
    );
    vm.stopPrank();
  }

  function setKillMailEnforcement(address grantee) public {
    // KillMail.reportKill
    bytes32 report = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.killMailSystemId(), IKillMailSystem.reportKill.selector)
    );

    vm.prank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (report, true))
    );
  }

  function testSuccessKillMailAccessConfig() public {
    KillMailTableData memory killData = KillMailTableData(77, 21, KillMailLossType.SHIP, 111, 1000000001);

    setAccessListConfig(alice);
    setKillMailEnforcement(alice);

    // ADMIN success
    vm.prank(alice, deployer);
    killMail.reportKill(1, killData);
  }

  function testRevertKillMailAccessConfig() public {
    KillMailTableData memory killData = KillMailTableData(77, 21, KillMailLossType.SHIP, 111, 1000000001);

    setAccessListConfig(charlie);
    setKillMailEnforcement(charlie);

    // NON ADMIN, NON OWNER revert
    vm.prank(charlie, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    killMail.reportKill(1, killData);
  }

  function setLocationEnforcement(address grantee) public {
    // Location.saveLocation
    bytes32 save = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.locationSystemId(), ILocationSystem.saveLocation.selector)
    );

    vm.prank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (save, true))
    );
  }

  function testSuccessLocationAccessConfig() public {
    LocationTableData memory locationData = LocationTableData(12344, 1, 1, 1);

    setAccessListConfig(alice);
    setLocationEnforcement(alice);

    // ADMIN success
    vm.prank(alice, deployer);
    location.saveLocation(ssuId, locationData);
  }

  function testRevertLocationAccessConfig() public {
    LocationTableData memory locationData = LocationTableData(12344, 1, 1, 1);

    setAccessListConfig(alice);
    setLocationEnforcement(alice);

    // NON ADMIN, NON OWNER revert
    vm.prank(charlie, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    location.saveLocation(ssuId, locationData);
  }

  function setSmartCharacterEnforcement(address grantee) public {
    // SmartCharacter.createCharacter
    bytes32 create = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartCharacterSystemId(),
        ISmartCharacterSystem.createCharacter.selector
      )
    );
    // SmartCharacter.registerERC721Token
    bytes32 register = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartCharacterSystemId(),
        ISmartCharacterSystem.registerERC721Token.selector
      )
    );
    // SmartCharacter.setCharClassId
    bytes32 setClass = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartCharacterSystemId(),
        ISmartCharacterSystem.setCharClassId.selector
      )
    );
    // SmartCharacter.updateCorpId
    bytes32 updateCorp = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartCharacterSystemId(),
        ISmartCharacterSystem.updateCorpId.selector
      )
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (create, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (register, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setClass, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (updateCorp, true))
    );
    vm.stopPrank();
  }

  function testSuccessSmartCharacterAccessConfig() public {
    setAccessListConfig(alice);
    setSmartCharacterEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    smartCharacter.createCharacter(
      3334,
      bob,
      369369,
      CharEntityRecordData(12, 13, 1),
      EntityRecordOffchainTableData("name", "URL", "description"),
      "cid"
    );
    vm.expectRevert(ISmartCharacterErrors.SmartCharacter_ERC721AlreadyInitialized.selector);
    smartCharacter.registerERC721Token(erc721SmartCharacterToken);
    smartCharacter.setCharClassId(987654);
    smartCharacter.updateCorpId(3333, 0);
    vm.stopPrank();
  }

  function testRevertSmartCharacterAccessConfig() public {
    setAccessListConfig(alice);
    setSmartCharacterEnforcement(alice);

    // NON ADMIN, NON OWNER revert
    vm.startPrank(charlie, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartCharacter.createCharacter(
      3335,
      charlie,
      369369,
      CharEntityRecordData(12, 13, 1),
      EntityRecordOffchainTableData("name", "URL", "description"),
      "cid"
    );
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartCharacter.registerERC721Token(erc721SmartCharacterToken);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartCharacter.setCharClassId(987654);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartCharacter.updateCorpId(3333, 0);
    vm.stopPrank();
  }

  function setSmartDeployableEnforcement(address grantee) public {
    {
      // SmartDeployable.registerDeployable
      bytes32 register = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.registerDeployable.selector
        )
      );
      // SmartDeployable.setSmartAssemblyType
      bytes32 setType = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.setSmartAssemblyType.selector
        )
      );
      // SmartDeployable.destroyDeployable
      bytes32 destroy = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.destroyDeployable.selector
        )
      );
      // SmartDeployable.bringOnline
      bytes32 online = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.bringOnline.selector
        )
      );
      // SmartDeployable.bringOffline
      bytes32 offline = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.bringOffline.selector
        )
      );
      // SmartDeployable.anchor
      bytes32 anchor = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.anchor.selector
        )
      );
      // SmartDeployable.unanchor
      bytes32 unanchor = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.unanchor.selector
        )
      );

      vm.startPrank(grantee);
      // set enforcement to true for all
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (register, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (setType, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (destroy, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (online, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (offline, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (anchor, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (unanchor, true))
      );
      vm.stopPrank();
    }
    {
      // SmartDeployable.globalPause
      bytes32 pause = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.globalPause.selector
        )
      );
      // SmartDeployable.globalResume
      bytes32 resume = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.globalResume.selector
        )
      );
      // SmartDeployable.setFuelConsumptionPerMinute
      bytes32 setFuel = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.setFuelConsumptionPerMinute.selector
        )
      );
      // SmartDeployable.setFuelMaxCapacity
      bytes32 setMax = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.setFuelMaxCapacity.selector
        )
      );
      // SmartDeployable.depositFuel
      bytes32 deposit = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.depositFuel.selector
        )
      );
      // SmartDeployable.withdrawFuel
      bytes32 withdraw = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.withdrawFuel.selector
        )
      );
      // SmartDeployable.registerDeployableToken
      bytes32 tokenReg = keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartDeployableSystemId(),
          ISmartDeployableSystem.registerDeployableToken.selector
        )
      );

      vm.startPrank(grantee);
      // set enforcement to true for all
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (pause, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (resume, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (setFuel, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (setMax, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (deposit, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (withdraw, true))
      );
      world.call(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
        abi.encodeCall(IAccessSystem.setAccessEnforcement, (tokenReg, true))
      );
      vm.stopPrank();
    }
  }

  function testSuccessAdminSmartDeployableAccessConfig() public {
    setAccessListConfig(charlie);
    setSmartDeployableEnforcement(charlie);

    // ADMIN success
    vm.startPrank(charlie, deployer);
    vm.expectRevert(SmartDeployableErrors.SmartDeployableERC721AlreadyInitialized.selector);
    smartDeployable.registerDeployableToken(erc721SmartDeployableToken);
    smartDeployable.setSmartAssemblyType(555, SmartAssemblyType.SMART_TURRET);
    smartDeployable.globalPause();
    smartDeployable.globalResume();
    smartDeployable.registerDeployable(
      555,
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      1e18,
      1,
      1000000 * 1e18
    );
    smartDeployable.setFuelConsumptionPerMinute(555, 2);
    smartDeployable.setFuelMaxCapacity(555, 10000000 * 1e18);
    smartDeployable.anchor(555, LocationTableData(12344, 1, 1, 1));
    smartDeployable.depositFuel(555, 1000);
    smartDeployable.withdrawFuel(555, 100);
    smartDeployable.bringOnline(555);
    smartDeployable.bringOffline(555);
    smartDeployable.unanchor(555);
    smartDeployable.anchor(555, LocationTableData(12344, 1, 1, 1));
    smartDeployable.destroyDeployable(555);
    vm.stopPrank();
  }

  function testSuccessOwnerSmartDeployableAccessConfig() public {
    setAccessListConfig(alice);
    setSmartDeployableEnforcement(alice);

    vm.startPrank(alice, deployer);
    vm.expectRevert(SmartDeployableErrors.SmartDeployableERC721AlreadyInitialized.selector);
    smartDeployable.registerDeployableToken(erc721SmartDeployableToken);
    smartDeployable.setSmartAssemblyType(555, SmartAssemblyType.SMART_TURRET);
    smartDeployable.registerDeployable(
      555,
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      1e18,
      1,
      1000000 * 1e18
    );
    smartDeployable.setFuelConsumptionPerMinute(555, 2);
    smartDeployable.setFuelMaxCapacity(555, 10000000 * 1e18);
    smartDeployable.anchor(555, LocationTableData(12344, 1, 1, 1));
    smartDeployable.depositFuel(555, 10000000);
    vm.stopPrank();

    // ADMIN success
    vm.startPrank(alice, bob);
    smartDeployable.bringOnline(555);
    smartDeployable.bringOffline(555);
    vm.stopPrank();
  }

  function testRevertAdminSmartDeployableAccessConfig() public {
    setAccessListConfig(alice);
    setSmartDeployableEnforcement(alice);

    // NON ADMIN revert
    vm.startPrank(alice, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.registerDeployableToken(erc721SmartDeployableToken);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.setSmartAssemblyType(555, SmartAssemblyType.SMART_TURRET);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.globalPause();
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.globalResume();
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.registerDeployable(
      555,
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      1e18,
      1,
      1000000 * 1e18
    );
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.setFuelConsumptionPerMinute(555, 2);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.setFuelMaxCapacity(555, 10000000 * 1e18);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.anchor(555, LocationTableData(12344, 1, 1, 1));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.depositFuel(555, 1000);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.withdrawFuel(555, 100);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.unanchor(555);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartDeployable.destroyDeployable(555);
    vm.stopPrank();
  }

  function testRevertOwnerSmartDeployableAccessConfig() public {
    setAccessListConfig(charlie);
    setSmartDeployableEnforcement(charlie);

    vm.startPrank(charlie, deployer);
    vm.expectRevert(SmartDeployableErrors.SmartDeployableERC721AlreadyInitialized.selector);
    smartDeployable.registerDeployableToken(erc721SmartDeployableToken);
    smartDeployable.setSmartAssemblyType(555, SmartAssemblyType.SMART_TURRET);
    smartDeployable.registerDeployable(
      555,
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      1e18,
      1,
      1000000 * 1e18
    );
    smartDeployable.setFuelConsumptionPerMinute(555, 2);
    smartDeployable.setFuelMaxCapacity(555, 10000000 * 1e18);
    smartDeployable.anchor(555, LocationTableData(12344, 1, 1, 1));
    vm.stopPrank();

    // NON ADMIN, NON OWNER revert
    vm.startPrank(charlie, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    smartDeployable.bringOnline(555);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, charlie, bytes32("OWNER"))
    );
    smartDeployable.bringOffline(555);
    vm.stopPrank();
  }

  function setSmartGateEnforcement(address grantee) public {
    // SmartGate.createAndAnchorSmartGate
    bytes32 create = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartGateSystemId(),
        ISmartGateSystem.createAndAnchorSmartGate.selector
      )
    );
    // SmartGate.configureSmartGate
    bytes32 configure = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartGateSystemId(),
        ISmartGateSystem.configureSmartGate.selector
      )
    );
    // SmartGate.linkSmartGates
    bytes32 link = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartGateSystemId(),
        ISmartGateSystem.linkSmartGates.selector
      )
    );
    // SmartGate.unlinkSmartGates
    bytes32 unlink = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartGateSystemId(),
        ISmartGateSystem.unlinkSmartGates.selector
      )
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (create, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (configure, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (link, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (unlink, true))
    );
    vm.stopPrank();
  }

  function testSuccessSmartGateAccessConfig() public {
    setAccessListConfig(alice);
    setSmartGateEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    smartGate.createAndAnchorSmartGate(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18
    );
    smartGate.createAndAnchorSmartGate(
      156789,
      EntityRecordData({ typeId: 7889, itemId: 111223, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 5, y: 5, z: 5 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18
    );
    vm.stopPrank();

    vm.startPrank(alice, bob);
    // OWNER success
    smartGate.configureSmartGate(56789, ResourceId.wrap(bytes32(uint256(123455667))));
    smartGate.linkSmartGates(56789, 156789);
    smartGate.unlinkSmartGates(56789, 156789);
    vm.stopPrank();
  }

  function testRevertAdminSmartGateAccessConfig() public {
    setAccessListConfig(alice);
    setSmartGateEnforcement(alice);

    // NON ADMIN revert
    vm.startPrank(alice, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartGate.createAndAnchorSmartGate(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18
    );
    vm.stopPrank();
  }

  function testRevertOwnerSmartGateAccessConfig() public {
    setAccessListConfig(charlie);
    setSmartGateEnforcement(charlie);

    // ADMIN for create
    vm.startPrank(charlie, deployer);
    smartGate.createAndAnchorSmartGate(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18
    );
    smartGate.createAndAnchorSmartGate(
      156789,
      EntityRecordData({ typeId: 7889, itemId: 111223, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 5, y: 5, z: 5 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18
    );
    vm.stopPrank();

    // NON ADMIN, NON OWNER revert
    vm.startPrank(charlie, bob);
    bytes memory errorMessage = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      charlie,
      bytes32("OWNER")
    );
    vm.expectRevert(errorMessage);
    smartGate.configureSmartGate(56789, ResourceId.wrap(bytes32(uint256(123455667))));
    vm.expectRevert(errorMessage);
    smartGate.linkSmartGates(56789, 156789);
    vm.expectRevert(errorMessage);
    smartGate.unlinkSmartGates(56789, 156789);
    vm.stopPrank();
  }

  function setSmartStorageUnitEnforcement(address grantee) public {
    // SmartStorageUnit.createAndAnchorSmartStorageUnit
    bytes32 createAndAnchor = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId(),
        ISmartStorageUnitSystem.createAndAnchorSmartStorageUnit.selector
      )
    );
    // SmartStorageUnit.createAndDepositItemsToInventory
    bytes32 invCreateAndDeposit = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId(),
        ISmartStorageUnitSystem.createAndDepositItemsToInventory.selector
      )
    );
    // SmartStorageUnit.createAndDepositItemsToEphemeralInventory
    bytes32 ephInvCreateAndDeposit = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId(),
        ISmartStorageUnitSystem.createAndDepositItemsToEphemeralInventory.selector
      )
    );
    // SmartStorageUnit.setDeployableMetadata
    bytes32 setDeployableMetadata = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId(),
        ISmartStorageUnitSystem.setDeployableMetadata.selector
      )
    );
    // SmartStorageUnit.setSSUClassId
    bytes32 setClass = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId(),
        ISmartStorageUnitSystem.setSSUClassId.selector
      )
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (createAndAnchor, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (invCreateAndDeposit, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (ephInvCreateAndDeposit, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setDeployableMetadata, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (setClass, true))
    );
    vm.stopPrank();
  }

  function testSuccessSmartStorageUnitAccessConfig() public {
    InventoryItem[] memory invItemsIn = new InventoryItem[](1);
    invItemsIn[0] = InventoryItem({
      inventoryItemId: 1,
      owner: alice,
      itemId: 11,
      typeId: 111,
      volume: 10,
      quantity: 3
    });

    setAccessListConfig(alice);
    setSmartStorageUnitEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    smartStorageUnit.setSSUClassId(uint256(keccak256("SSUClass")));
    smartStorageUnit.createAndAnchorSmartStorageUnit(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      SmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18,
      1000000 * 1e18
    );
    smartDeployable.depositFuel(56789, 200000);
    smartDeployable.bringOnline(56789);
    smartStorageUnit.createAndDepositItemsToInventory(56789, invItemsIn);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(56789, alice, invItemsIn);
    vm.stopPrank();

    vm.startPrank(alice, bob);
    // OWNER success
    smartStorageUnit.setDeployableMetadata(56789, "name", "URI", "description");
    vm.stopPrank();
  }

  function testRevertAdminSmartStorageUnitAccessConfig() public {
    InventoryItem[] memory invItemsIn = new InventoryItem[](1);
    invItemsIn[0] = InventoryItem({
      inventoryItemId: 1,
      owner: alice,
      itemId: 11,
      typeId: 111,
      volume: 10,
      quantity: 3
    });

    setAccessListConfig(alice);
    setSmartStorageUnitEnforcement(alice);

    // NON ADMIN revert
    vm.startPrank(alice, bob);
    bytes memory adminError = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      bob,
      bytes32(ADMIN)
    );
    vm.expectRevert(adminError);
    smartStorageUnit.setSSUClassId(uint256(keccak256("SSUClass")));
    vm.expectRevert(adminError);
    smartStorageUnit.createAndAnchorSmartStorageUnit(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      SmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18,
      1000000 * 1e18
    );
    vm.expectRevert(adminError);
    smartStorageUnit.createAndDepositItemsToInventory(56789, invItemsIn);
    vm.expectRevert(adminError);
    smartStorageUnit.createAndDepositItemsToEphemeralInventory(56789, alice, invItemsIn);
    vm.stopPrank();
  }

  function testRevertOwnerSmartStorageUnitAccessConfig() public {
    setAccessListConfig(charlie);
    setSmartStorageUnitEnforcement(charlie);

    // ADMIN for create
    vm.startPrank(charlie, deployer);
    smartStorageUnit.createAndAnchorSmartStorageUnit(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      SmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18,
      1000000 * 1e18,
      1000000 * 1e18
    );
    smartDeployable.depositFuel(56789, 200000);
    smartDeployable.bringOnline(56789);
    vm.stopPrank();

    // NON ADMIN, NON OWNER revert
    vm.startPrank(charlie, bob);
    bytes memory errorMessage = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      charlie,
      bytes32("OWNER")
    );
    vm.expectRevert(errorMessage);
    smartStorageUnit.setDeployableMetadata(56789, "name", "URI", "description");
    vm.stopPrank();
  }

  function setSmartTurretEnforcement(address grantee) public {
    // SmartTurret.createAndAnchorSmartTurret
    bytes32 createAndAnchor = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartTurretSystemId(),
        ISmartTurretSystem.createAndAnchorSmartTurret.selector
      )
    );
    // SmartTurret.configureSmartTurret
    bytes32 configure = keccak256(
      abi.encodePacked(
        FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartTurretSystemId(),
        ISmartTurretSystem.configureSmartTurret.selector
      )
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (createAndAnchor, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (configure, true))
    );
    vm.stopPrank();
  }

  function testSuccessSmartTurretAccessConfig() public {
    setAccessListConfig(alice);
    setSmartTurretEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    smartTurret.createAndAnchorSmartTurret(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18
    );
    vm.stopPrank();

    vm.startPrank(alice, bob);
    // OWNER success
    smartTurret.configureSmartTurret(56789, ResourceId.wrap(bytes32(uint256(123455667))));
    vm.stopPrank();
  }

  function testRevertAdminSmartTurretAccessConfig() public {
    setAccessListConfig(alice);
    setSmartTurretEnforcement(alice);

    // NON ADMIN revert
    vm.startPrank(alice, bob);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessSystemErrors.AccessSystem_NoPermission.selector, bob, bytes32(ADMIN))
    );
    smartTurret.createAndAnchorSmartTurret(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18
    );

    vm.stopPrank();
  }

  function testRevertOwnerSmartTurretAccessConfig() public {
    setAccessListConfig(charlie);
    setSmartTurretEnforcement(charlie);

    // ADMIN for create
    vm.startPrank(charlie, deployer);
    smartTurret.createAndAnchorSmartTurret(
      56789,
      EntityRecordData({ typeId: 7889, itemId: 111222, volume: 10 }),
      DeployableSmartObjectData({ owner: alice, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18,
      1,
      1000000 * 1e18
    );
    vm.stopPrank();

    // NON ADMIN, NON OWNER revert
    vm.startPrank(charlie, bob);
    bytes memory errorMessage = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      charlie,
      bytes32("OWNER")
    );
    vm.expectRevert(errorMessage);
    smartTurret.configureSmartTurret(56789, ResourceId.wrap(bytes32(uint256(123455667))));
    vm.stopPrank();
  }

  function setStaticDataEnforcement(address grantee) public {
    // StaticData.setBaseURI
    bytes32 baseURI = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setBaseURI.selector)
    );
    // StaticData.setName
    bytes32 name = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setName.selector)
    );
    // StaticData.setSymbol
    bytes32 symbol = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setSymbol.selector)
    );
    // StaticData.setMetadata
    bytes32 metadata = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setMetadata.selector)
    );
    // StaticData.setCid
    bytes32 cid = keccak256(
      abi.encodePacked(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.staticDataSystemId(), IStaticDataSystem.setCid.selector)
    );

    vm.startPrank(grantee);
    // set enforcement to true for all
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (baseURI, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (name, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (symbol, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (metadata, true))
    );
    world.call(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.accessSystemId(),
      abi.encodeCall(IAccessSystem.setAccessEnforcement, (cid, true))
    );
    vm.stopPrank();
  }

  function testSuccessStaticDataAccessConfig() public {
    setAccessListConfig(alice);
    setStaticDataEnforcement(alice);

    // ADMIN success
    vm.startPrank(alice, deployer);
    staticData.setBaseURI(ResourceId.wrap(bytes32(uint256(979797))), "URI");
    staticData.setName(ResourceId.wrap(bytes32(uint256(979797))), "name");
    staticData.setSymbol(ResourceId.wrap(bytes32(uint256(979797))), "ABC");
    staticData.setMetadata(ResourceId.wrap(bytes32(uint256(979797))), StaticDataGlobalTableData("name", "ABC", "URI"));
    staticData.setCid(757575, "cid");
    vm.stopPrank();
  }

  function testRevertAdminStaticDataAccessConfig() public {
    setAccessListConfig(alice);
    setStaticDataEnforcement(alice);

    // NON ADMIN revert
    vm.startPrank(alice, bob);
    bytes memory adminError = abi.encodeWithSelector(
      IAccessSystemErrors.AccessSystem_NoPermission.selector,
      bob,
      bytes32(ADMIN)
    );
    vm.expectRevert(adminError);
    staticData.setBaseURI(ResourceId.wrap(bytes32(uint256(979797))), "URI");
    vm.expectRevert(adminError);
    staticData.setName(ResourceId.wrap(bytes32(uint256(979797))), "name");
    vm.expectRevert(adminError);
    staticData.setSymbol(ResourceId.wrap(bytes32(uint256(979797))), "ABC");
    vm.expectRevert(adminError);
    staticData.setMetadata(ResourceId.wrap(bytes32(uint256(979797))), StaticDataGlobalTableData("name", "ABC", "URI"));
    vm.expectRevert(adminError);
    staticData.setCid(757575, "cid");
    vm.stopPrank();
  }
}
