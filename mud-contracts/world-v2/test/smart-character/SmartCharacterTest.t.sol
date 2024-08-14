// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import { ERC721MetadataData } from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Metadata.sol";
import { registerERC721 } from "@latticexyz/world-modules/src/modules/erc721-puppet/registerERC721.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { Characters, CharactersData } from "../../src/codegen/index.sol";
import { ISmartCharacterSystem } from "../../src/codegen/world/ISmartCharacterSystem.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { Characters, CharacterToken } from "../../src/codegen/index.sol";

contract SmartCharacterTest is MudTest {
  IBaseWorld world;

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  /// forge-config: default.fuzz.runs = 100
  function testSmartCharacter() public {
    
    uint256 characterId = 123;
    address characterAddress = address(0x123);
    EntityRecordData memory entityRecord = EntityRecordData({
      entityId: characterId,
      typeId: 123,
      itemId: 234,
      volume: 100
    });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      entityId: characterId,
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });
    string memory cid = "cid";

    bytes4 functionSelector = ISmartCharacterSystem.eveworld__createCharacter.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, characterAddress, entityRecord, entityRecordMetadata, cid)
      )
    );

    // CharactersData memory character = Characters.get(characterId);
    // assertEq(characterAddress, character.characterAddress);
  }
}
