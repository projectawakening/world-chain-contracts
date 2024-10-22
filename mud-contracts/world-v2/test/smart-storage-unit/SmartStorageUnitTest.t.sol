// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { SmartStorageUnitSystem } from "../../src/systems/smart-storage-unit/SmartStorageUnitSystem.sol";
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";
import { SmartStorageUnitUtils } from "../../src/systems/smart-storage-unit/SmartStorageUnitUtils.sol";
import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { State, SmartObjectData } from "../../src/systems/deployable/types.sol";
import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { WorldPosition } from "../../src/systems/smart-storage-unit/types.sol";

contract SmartStorageUnitTest is MudTest {
  IBaseWorld world;
  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 2);

  uint256 characterId = 123;
  address alice = vm.addr(alicePK);
  uint256 tribeId = 100;
  SmartObjectData smartObjectData;

  ResourceId smartStorageUnitSystemId = SmartStorageUnitUtils.smartStorageUnitSystemId();
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId characterSystemId = SmartCharacterUtils.smartCharacterSystemId();

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));

    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    world.call(
      characterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, alice, tribeId, entityRecord, entityRecordMetadata)
      )
    );
  }

  function testcreateAndAnchorSmartStorageUnit(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    EntityRecordData memory entityRecordData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));
    vm.assume(storageCapacity > 0);
    vm.assume(ephemeralStorageCapacity > 0);
    vm.assume(fuelConsumptionIntervalInSeconds > 1);

    world.call(
      smartStorageUnitSystemId,
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorSmartStorageUnit,
        (
          smartObjectId,
          smartAssemblyType,
          entityRecordData,
          smartObjectData,
          worldPosition,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          storageCapacity,
          ephemeralStorageCapacity
        )
      )
    );
  }
}
