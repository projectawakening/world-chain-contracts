// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { IERC721Metadata } from "../../src/modules/eve-erc721-puppet/IERC721Metadata.sol";

import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData } from "../../src/modules/smart-character/types.sol";
import { ISmartCharacterErrors } from "../../src/modules/smart-character/ISmartCharacterErrors.sol";

import { CharactersTable, CharactersTableData } from "../../src/codegen/tables/CharactersTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityTable, EntityTableData } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { EntityMap } from "@eveworld/smart-object-framework/src/codegen/tables/EntityMap.sol";

import { ERC721Registry } from "../../src/codegen/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "../../src/modules/eve-erc721-puppet/constants.sol";
import { Utils as ERC721Utils } from "../../src/modules/eve-erc721-puppet/Utils.sol";
import { StaticDataGlobalTable } from "../../src/codegen/tables/StaticDataGlobalTable.sol";

contract SmartCharacterTest is MudTest {
  using SmartCharacterUtils for bytes14;
  using ERC721Utils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  SmartCharacterLib.World smartCharacter;
  IERC721 erc721Token;
  bytes14 constant SMART_CHAR_ERC721_NAMESPACE = "erc721charactr";
  uint256 smartCharacterClassId = uint256(keccak256("SmartCharacterClass"));

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    smartCharacter = SmartCharacterLib.World(world, DEPLOYMENT_NAMESPACE);
    erc721Token = IERC721(
      ERC721Registry.get(ERC721_REGISTRY_TABLE_ID, WorldResourceIdLib.encodeNamespace(SMART_CHAR_ERC721_NAMESPACE))
    );
  }

  function testSetup() public {
    address smartCharacterSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartCharacterSystemId());
    ResourceId smartCharacterSystemId = SystemRegistry.get(smartCharacterSystem);
    assertEq(smartCharacterSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testCreateSmartCharacter(
    uint256 entityId,
    address characterAddress,
    uint256 corpId,
    uint256 typeId,
    uint256 volume,
    EntityRecordOffchainTableData memory offchainData,
    string memory tokenCid
  ) public {
    vm.assume(entityId != 0);
    vm.assume(corpId != 0);
    vm.assume(characterAddress != address(0));
    vm.assume(bytes(tokenCid).length != 0);

    EntityRecordData memory entityRecordData = EntityRecordData({ itemId: 5555, typeId: typeId, volume: volume });
    CharactersTableData memory charactersData = CharactersTableData({
      characterAddress: characterAddress,
      corpId: corpId,
      createdAt: block.timestamp
    });

    smartCharacter.createCharacter(entityId, characterAddress, corpId, entityRecordData, offchainData, tokenCid);
    CharactersTableData memory loggedCharactersData = CharactersTable.get(entityId);
    EntityRecordTableData memory loggedEntityRecordData = EntityRecordTable.get(entityId);

    assertEq(charactersData.characterAddress, loggedCharactersData.characterAddress);

    assertEq(entityRecordData.itemId, loggedEntityRecordData.itemId);
    assertEq(entityRecordData.typeId, loggedEntityRecordData.typeId);
    assertEq(entityRecordData.volume, loggedEntityRecordData.volume);

    assertEq(erc721Token.ownerOf(entityId), characterAddress);
    assertEq(
      keccak256(abi.encode(IERC721Metadata(address(erc721Token)).tokenURI(entityId))),
      keccak256(
        abi.encode(
          string.concat(StaticDataGlobalTable.getBaseURI(SMART_CHAR_ERC721_NAMESPACE.erc721SystemId()), tokenCid)
        )
      )
    );

    // check that the character has been registered as an OBJECT entity
    EntityTableData memory entityTableData = EntityTable.get(entityId);
    assertEq(entityTableData.doesExists, true);
    assertEq(entityTableData.entityType, 1);

    uint256[] memory taggedEntityIds = EntityMap.get(entityId);
    uint256[] memory smartCharTaggedIds = new uint256[](1);
    smartCharTaggedIds[0] = entityId;

    // check that the character has been tagged for the appropriate class
    assertEq(taggedEntityIds.length, 1);
    assertEq(taggedEntityIds[0], smartCharacterClassId);
  }
  function testOnlyOneSmartCharacterPerAddress(
    address characterAddress,
    uint256 corpId,
    uint256 typeId,
    uint256 volume,
    EntityRecordOffchainTableData memory offchainData,
    string memory tokenCid
  ) public {
    uint256 characterId = 3690;
    vm.assume(corpId != 0);
    vm.assume(characterAddress != address(0));
    vm.assume(bytes(tokenCid).length != 0);
    testCreateSmartCharacter(characterId, characterAddress, corpId, typeId, volume, offchainData, tokenCid);

    characterId = 3691;

    EntityRecordData memory entityRecordData = EntityRecordData({ itemId: 5555, typeId: typeId, volume: volume });
    CharactersTableData memory charactersData = CharactersTableData({
      characterAddress: characterAddress,
      corpId: corpId,
      createdAt: block.timestamp
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        ISmartCharacterErrors.SmartCharacter_AlreadyCreated.selector,
        characterAddress,
        characterId
      )
    );
    smartCharacter.createCharacter(characterId, characterAddress, corpId, entityRecordData, offchainData, tokenCid);
  }

  function testCreateSmartCharacterOffchain(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public {
    // vm.assume(entityId != 0);
    // vm.assume(bytes(name).length != 0);
    // SmartCharacterOffchainTableData memory data = SmartCharacterOffchainTableData({name: name, dappURL: dappURL, description: description});
    // SmartCharacter.createSmartCharacterOffchain(entityId, name, dappURL, description);
    // SmartCharacterOffchainTableData memory tableData = SmartCharacterOffchainTable.get(DEPLOYMENT_NAMESPACE.SmartCharacterOffchainTableId(), entityId);
    // assertEq(data.name, tableData.name);
    //assertEq(data.dappURL, tableData.dappURL);
    //assertEq(data.description, tableData.description);
  }

  function testUpdateCorpId(uint256 entityId) public {
    vm.assume(entityId != 0);

    smartCharacter.createCharacter(
      entityId,
      address(this),
      111,
      EntityRecordData({ typeId: 111, itemId: 116, volume: 11 }),
      EntityRecordOffchainTableData({ name: "characterName", dappURL: "noURL", description: "." }),
      "cid"
    );
    CharactersTableData memory charactersData = CharactersTable.get(entityId);
    assertEq(charactersData.corpId, 111);

    smartCharacter.updateCorpId(entityId, 222);
    charactersData = CharactersTable.get(entityId);
    assertEq(charactersData.corpId, 222);
  }

  function revertUpdateCorpId(uint256 characterId, uint256 corpId) public {
    vm.assume(characterId != 0);
    vm.assume(corpId == 0);

    vm.expectRevert(abi.encodeWithSelector(ISmartCharacterErrors.SmartCharacterDoesNotExist.selector, characterId));
    smartCharacter.updateCorpId(characterId, corpId);
  }
}
