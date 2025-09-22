// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

// Local namespace tables
import { Tenant, EntityRecord } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordData } from "../../src/namespaces/evefrontier/codegen/tables/EntityRecord.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { IEntitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { eveSystem } from "../../src/namespaces/evefrontier/codegen/systems/EveSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

// Script helper to test
import { runRegisterAssemblies } from "../../script/RegisterAssemblies.s.sol";

contract RegisterAssembliesScriptTest is Test {
  address internal worldAddress;
  bytes32 internal tenantId;
  address internal deployer;

  function setUp() public {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);

    // Use the same mnemonic pattern as other tests to derive a "deployer" address
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));

    tenantId = Tenant.get();
  }

  function test_registerAssemblies_registersClassesWithVolumes() public {
    uint256[] memory ids = new uint256[](2);
    uint256[] memory vols = new uint256[](2);
    ids[0] = 987654321;
    vols[0] = 1;
    ids[1] = 987654322;
    vols[1] = 42;

    vm.startPrank(deployer, deployer);
    // Grant EveSystem call access if it doesn't already have it
    if (
      !CallAccess.get(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, eveSystem.getAddress())
    ) {
      CallAccess.set(
        entitySystem.toResourceId(),
        IEntitySystem.scopedRegisterClass.selector,
        eveSystem.getAddress(),
        true
      );
    }
    if (
      !CallAccess.get(
        entityRecordSystem.toResourceId(),
        EntityRecordSystem.createRecord.selector,
        eveSystem.getAddress()
      )
    ) {
      CallAccess.set(
        entityRecordSystem.toResourceId(),
        EntityRecordSystem.createRecord.selector,
        eveSystem.getAddress(),
        true
      );
    }
    runRegisterAssemblies(ids, vols);
    vm.stopPrank();

    uint256 classId0 = uint256(keccak256(abi.encodePacked(tenantId, ids[0])));
    uint256 classId1 = uint256(keccak256(abi.encodePacked(tenantId, ids[1])));

    assertTrue(EntityRecord.getExists(classId0));
    assertTrue(EntityRecord.getExists(classId1));

    EntityRecordData memory rec0 = EntityRecord.get(classId0);
    EntityRecordData memory rec1 = EntityRecord.get(classId1);

    assertEq(rec0.volume, vols[0]);
    assertEq(rec1.volume, vols[1]);
  }

  function test_registerAssemblies_revertsWhenTypeIdAlreadyExists() public {
    uint256[] memory ids = new uint256[](1);
    uint256[] memory vols = new uint256[](1);
    // Use an ID already registered in the loaded world state (see run-tests.sh TYPE_IDS)
    ids[0] = 77917;
    vols[0] = 7;

    vm.startPrank(deployer, deployer);
    // Grant EveSystem call access if it doesn't already have it
    if (
      !CallAccess.get(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, eveSystem.getAddress())
    ) {
      CallAccess.set(
        entitySystem.toResourceId(),
        IEntitySystem.scopedRegisterClass.selector,
        eveSystem.getAddress(),
        true
      );
    }
    if (
      !CallAccess.get(
        entityRecordSystem.toResourceId(),
        EntityRecordSystem.createRecord.selector,
        eveSystem.getAddress()
      )
    ) {
      CallAccess.set(
        entityRecordSystem.toResourceId(),
        EntityRecordSystem.createRecord.selector,
        eveSystem.getAddress(),
        true
      );
    }
    // Expect revert on first attempt due to collision with existing class
    vm.expectRevert();
    runRegisterAssemblies(ids, vols);
    vm.stopPrank();
  }
}
