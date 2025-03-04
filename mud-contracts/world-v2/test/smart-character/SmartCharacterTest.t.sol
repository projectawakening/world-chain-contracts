// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { Characters, CharactersData } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { EntityRecord, EntityRecordData as RecordData } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { Characters, CharacterToken } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";

import "forge-std/console.sol";

contract SmartCharacterTest is MudTest {
  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));

  address alice = vm.addr(vm.deriveKey(mnemonic, 2));

  uint256 testClassId = uint256(bytes32("characterClassId"));

  function setUp() public virtual override {
    super.setUp();
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testRevertTokenAlreadyInitialized() public {
    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSelector(SmartCharacterSystem.SmartCharacter_ERC721AlreadyInitialized.selector));
    smartCharacterSystem.registerCharacterToken(address(0x123));
    vm.stopPrank();
  }

  /// forge-config: default.fuzz.runs = 100
  function testSmartCharacter() public {
    vm.startPrank(deployer);
    uint256 characterId = 123;
    address characterAddress = address(0x123);
    uint256 tribeId = 100;
    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartCharacterSystem.createCharacter(characterId, characterAddress, tribeId, entityRecord, entityRecordMetadata);

    CharactersData memory character = Characters.get(characterId);
    assertEq(characterAddress, character.characterAddress);

    RecordData memory storedEntityRecord = EntityRecord.get(characterId);
    assertEq(entityRecord.typeId, storedEntityRecord.typeId);
    assertEq(entityRecord.itemId, storedEntityRecord.itemId);
    assertEq(entityRecord.volume, storedEntityRecord.volume);
    vm.stopPrank();
  }
}
