// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Test framework
import { EveTest } from "../EveTest.sol";

// Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";

// Tables
import { CrudeLift } from "../../src/namespaces/evefrontier/codegen/tables/CrudeLift.sol";
import { SmartAssembly } from "../../src/namespaces/evefrontier/codegen/tables/SmartAssembly.sol";
import { DeployableState } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { Lens, Rift, Fuel } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Types
import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { WorldPosition, Coord } from "../../src/namespaces/evefrontier/systems/location/types.sol";
import { InventoryItem } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { CreateAndAnchorDeployableParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Systems
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { CrudeLiftSystem, LENS } from "../../src/namespaces/evefrontier/systems/crude-lift/CrudeLiftSystem.sol";
import { FuelSystem } from "../../src/namespaces/evefrontier/systems/fuel/FuelSystem.sol";
import { InventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { EphemeralInventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/EphemeralInventorySystem.sol";
import { RiftSystem } from "../../src/namespaces/evefrontier/systems/rift/RiftSystem.sol";
import { EntityRecordSystem } from "../../src/namespaces/evefrontier/systems/entity-record/EntityRecordSystem.sol";
import { LocationSystem } from "../../src/namespaces/evefrontier/systems/location/LocationSystem.sol";
import { SmartAssemblySystem } from "../../src/namespaces/evefrontier/systems/smart-assembly/SmartAssemblySystem.sol";
import { InventoryInteractSystem } from "../../src/namespaces/evefrontier/systems/inventory/InventoryInteractSystem.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";

// System Libraries
import { deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { crudeLiftSystem } from "../../src/namespaces/evefrontier/codegen/systems/CrudeLiftSystemLib.sol";
import { riftSystem } from "../../src/namespaces/evefrontier/codegen/systems/RiftSystemLib.sol";
import { smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { inventoryInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { accessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";

// Constants
import { CRUDE_LIFT } from "../../src/namespaces/evefrontier/systems/constants.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

contract CrudeLiftTest is EveTest {
  uint256 characterId = 1111;
  uint256 tribeId = 1122;
  uint256 liftId = 12345;
  uint256 lensId = 5678;
  uint256 riftId = 9012;

  uint256 totalCrudeInRift = 250;
  uint256 liftInitialFuel = 150;
  uint256 lensDurability = 125;

  EntityRecordData entityRecord;
  SmartObjectData smartObjectData;
  WorldPosition worldPosition;

  function setUp() public virtual override {
    super.setUp();
    world = IWorldWithContext(worldAddress);

    entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    Coord memory position = Coord({ x: 1, y: 1, z: 1 });
    worldPosition = WorldPosition({ solarSystemId: 1, position: position });

    vm.startPrank(deployer);

    bytes32 adminRole = bytes32("ADMIN_ROLE");

    ResourceId[] memory systemIds = new ResourceId[](10);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = inventorySystem.toResourceId();
    systemIds[2] = ephemeralInventorySystem.toResourceId();
    systemIds[3] = inventoryInteractSystem.toResourceId();
    systemIds[4] = entityRecordSystem.toResourceId();
    systemIds[5] = fuelSystem.toResourceId();
    systemIds[6] = locationSystem.toResourceId();
    systemIds[7] = smartAssemblySystem.toResourceId();
    systemIds[8] = crudeLiftSystem.toResourceId();
    systemIds[9] = riftSystem.toResourceId();
    entitySystem.registerClass(uint256(bytes32("CL")), systemIds);

    systemIds = new ResourceId[](5);
    systemIds[0] = smartAssemblySystem.toResourceId();
    systemIds[1] = riftSystem.toResourceId();
    systemIds[2] = inventorySystem.toResourceId();
    systemIds[3] = crudeLiftSystem.toResourceId();
    systemIds[4] = entityRecordSystem.toResourceId();
    entitySystem.registerClass(uint256(bytes32("RIFT")), systemIds);

    // selector list
    bytes4[] memory onlyAdminSelectors = new bytes4[](8);
    onlyAdminSelectors[0] = CrudeLiftSystem.createAndAnchorCrudeLift.selector;
    onlyAdminSelectors[1] = CrudeLiftSystem.insertLens.selector;
    onlyAdminSelectors[2] = CrudeLiftSystem.startMining.selector;
    onlyAdminSelectors[3] = CrudeLiftSystem.stopMining.selector;
    onlyAdminSelectors[4] = CrudeLiftSystem.removeLens.selector;
    onlyAdminSelectors[5] = CrudeLiftSystem.addCrude.selector;
    onlyAdminSelectors[6] = CrudeLiftSystem.removeCrude.selector;
    onlyAdminSelectors[7] = CrudeLiftSystem.clearCrude.selector;

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        crudeLiftSystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(crudeLiftSystem.toResourceId(), onlyAdminSelectors[i], true);
    }

    onlyAdminSelectors = new bytes4[](2);
    onlyAdminSelectors[0] = RiftSystem.createRift.selector;
    onlyAdminSelectors[1] = RiftSystem.destroyRift.selector;

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        riftSystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(riftSystem.toResourceId(), onlyAdminSelectors[i], true);
    }

    deployableSystem.globalResume();
    smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);
    vm.stopPrank();
  }

  function testAnchorCrudeLift() public {
    uint256 fuelUnitVolume = 1;
    uint256 fuelConsumptionIntervalInSeconds = 1;
    uint256 fuelMaxCapacity = 100_000;
    uint256 storageCapacity = 100_000;
    uint256 ephemeralStorageCapacity = 100_000;

    CreateAndAnchorDeployableParams memory params = CreateAndAnchorDeployableParams({
      smartObjectId: liftId,
      smartAssemblyType: CRUDE_LIFT,
      entityRecordData: entityRecord,
      smartObjectData: smartObjectData,
      locationData: LocationData({
        solarSystemId: worldPosition.solarSystemId,
        x: worldPosition.position.x,
        y: worldPosition.position.y,
        z: worldPosition.position.z
      }),
      fuelUnitVolume: fuelUnitVolume,
      fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity: fuelMaxCapacity
    });

    vm.startPrank(deployer);
    crudeLiftSystem.createAndAnchorCrudeLift(params, storageCapacity, ephemeralStorageCapacity);
    fuelSystem.depositFuel(liftId, liftInitialFuel);
    deployableSystem.bringOnline(liftId);
    vm.stopPrank();

    assertEq(SmartAssembly.getSmartAssemblyType(liftId), CRUDE_LIFT);
    assertEq(uint8(DeployableState.getCurrentState(liftId)), uint8(State.ONLINE));
  }

  function craftLens() public {
    vm.startPrank(deployer);
    Lens.setDurability(lensId, 100);
    vm.stopPrank();
  }

  function createRift() public {
    vm.startPrank(deployer);
    riftSystem.createRift(riftId, totalCrudeInRift);
    vm.stopPrank();

    assertEq(Rift.getCreatedAt(riftId), block.timestamp);
  }

  function testInsertLens() public {
    testAnchorCrudeLift();
    craftLens();

    // Create lens inventory item
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: lensId,
      owner: alice,
      itemId: lensId,
      typeId: LENS,
      volume: 1,
      quantity: 1
    });

    // Deposit lens into crude lift's inventory
    vm.startPrank(deployer);
    inventorySystem.createAndDepositItemsToInventory(liftId, items);
    // Now insert the lens
    crudeLiftSystem.insertLens(liftId);
    vm.stopPrank();

    assertEq(CrudeLift.getLensId(liftId), lensId);
  }

  function testStartMining() public {
    testInsertLens();
    createRift();

    vm.startPrank(deployer);
    crudeLiftSystem.startMining(liftId, riftId, 1);
    vm.stopPrank();

    assertEq(CrudeLift.getMiningRiftId(liftId), riftId);
    assertTrue(CrudeLift.getStartMiningTime(liftId) > 0);
  }

  function testStopMining() public {
    testStartMining();

    vm.warp(block.timestamp + 100); // Advance time by 100 seconds

    vm.startPrank(deployer);
    crudeLiftSystem.stopMining(liftId);
    vm.stopPrank();

    assertEq(CrudeLift.getStartMiningTime(liftId), 0);

    uint256 crudeMined = getCrudeAmount(liftId);
    assertEq(crudeMined, 100);

    uint256 riftCrudeRemaining = getCrudeAmount(riftId);
    assertEq(riftCrudeRemaining, totalCrudeInRift - crudeMined);
  }

  function testRunOutOfFuelBeforeMiningStopped() public {
    testStartMining();

    uint256 originalFuelAmount = Fuel.getFuelAmount(liftId);

    // leave 20 fuel in the Lift, should only be able to mine for 20 blocks
    vm.startPrank(deployer);
    fuelSystem.withdrawFuel(liftId, originalFuelAmount / ONE_UNIT_IN_WEI - 20);
    vm.stopPrank();

    uint256 fuelRemaining = Fuel.getFuelAmount(liftId);
    assertEq(fuelRemaining / ONE_UNIT_IN_WEI, 20, "Fuel remaining should be 20 after withdrawing");

    vm.warp(block.timestamp + 100); // Advance time by 100 seconds

    vm.startPrank(deployer);
    crudeLiftSystem.stopMining(liftId);
    vm.stopPrank();

    uint256 crudeMined = getCrudeAmount(liftId);
    assertEq(crudeMined, 20, "mining did not stop after fuel ran out");

    uint256 riftCrudeRemaining = getCrudeAmount(riftId);
    assertEq(riftCrudeRemaining, totalCrudeInRift - crudeMined, "rift crude not reduced");
  }

  function testRunOutOfCapacityBeforeMiningStopped() public {
    testStartMining();

    // lift can only fit 19 crude
    // Lens takes up 1 space
    vm.startPrank(deployer);
    inventorySystem.setInventoryCapacity(liftId, 20);
    vm.stopPrank();

    vm.warp(block.timestamp + 100); // Advance time by 100 seconds
    vm.startPrank(deployer);
    crudeLiftSystem.stopMining(liftId);
    vm.stopPrank();

    uint256 crudeMined = getCrudeAmount(liftId);
    assertEq(crudeMined, 19, "mining did not stop after capacity ran out");

    uint256 riftCrudeRemaining = getCrudeAmount(riftId);
    assertEq(riftCrudeRemaining, totalCrudeInRift - crudeMined, "rift crude not reduced");
  }

  function testRunOutOfDurabilityBeforeMiningStopped() public {
    testStartMining();

    // 1 second remaining mining time
    vm.startPrank(deployer);
    Lens.setDurability(lensId, 1);
    vm.stopPrank();

    vm.warp(block.timestamp + 100); // Advance time by 100 seconds
    vm.startPrank(deployer);
    crudeLiftSystem.stopMining(liftId);
    vm.stopPrank();

    assertEq(Lens.getDurability(lensId), 0, "lens durability not reduced");

    uint256 crudeMined = getCrudeAmount(liftId);
    assertEq(crudeMined, 1, "mining did not stop after durability ran out");

    uint256 riftCrudeRemaining = getCrudeAmount(riftId);
    assertEq(riftCrudeRemaining, totalCrudeInRift - crudeMined, "rift crude not reduced");
  }

  function testRiftCollapsedBeforeMiningStopped() public {
    testStartMining();

    vm.startPrank(deployer);
    Rift.setCollapsedAt(riftId, CrudeLift.getStartMiningTime(liftId) + 10);
    vm.stopPrank();

    vm.warp(block.timestamp + 100); // Advance time by 100 seconds
    vm.startPrank(deployer);
    crudeLiftSystem.stopMining(liftId);
    vm.stopPrank();

    uint256 crudeMined = getCrudeAmount(liftId);
    assertEq(crudeMined, 10, "mining did not stop after rift collapsed");
  }

  function getCrudeAmount(uint256 smartObjectId) public returns (uint256) {
    bytes memory result = world.call(
      crudeLiftSystem.toResourceId(),
      abi.encodeCall(CrudeLiftSystem.getCrudeAmount, (smartObjectId))
    );
    return abi.decode(result, (uint256));
  }
}
