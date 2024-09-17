// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";

import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE, STATIC_DATA_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { ERC721Module } from "../../src/modules/eve-erc721-puppet/ERC721Module.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IERC721Metadata } from "../../src/modules/eve-erc721-puppet/IERC721Metadata.sol";

import { Utils as SmartCharacterUtils } from "../../src/modules/smart-character/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { SmartCharacterModule } from "../../src/modules/smart-character/SmartCharacterModule.sol";
import { SmartCharacterLib } from "../../src/modules/smart-character/SmartCharacterLib.sol";
import { SmartObjectData, EntityRecordData } from "../../src/modules/smart-character/types.sol";
import { ISmartCharacterErrors } from "../../src/modules/smart-character/ISmartCharacterErrors.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import { CharactersTable, CharactersTableData } from "../../src/codegen/tables/CharactersTable.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";
import { EntityTable, EntityTableData } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { EntityMap } from "@eveworld/smart-object-framework/src/codegen/tables/EntityMap.sol";
import { Utils as SmartObjectUtils } from "@eveworld/smart-object-framework/src/utils.sol";

contract SmartCharacterTest is Test {
  using SmartCharacterUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartObjectUtils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;

  IBaseWorld world;
  SmartCharacterLib.World smartCharacter;
  IERC721Mintable erc721Token;
  bytes14 constant SMART_CHAR_ERC721 = "ERC721Char";
  SmartObjectLib.World SOFInterface;
  uint256 smartCharacterClassId = uint256(keccak256("SmartCharacterClass"));
  uint256[] smartCharClassIds;

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    // installing SOF & other modules (SmartCharacterModule dependancies)
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );

    SOFInterface = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);

    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    erc721Token = registerERC721(
      world,
      SMART_CHAR_ERC721,
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: "" })
    );

    // install smartCharacterModule
    _installModule(new SmartCharacterModule(), SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
    smartCharacter = SmartCharacterLib.World(world, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
    smartCharacter.registerERC721Token(address(erc721Token));

    // create class and object types
    SOFInterface.registerEntityType(2, "CLASS");
    SOFInterface.registerEntityType(1, "OBJECT");
    // allow object to class tagging
    SOFInterface.registerEntityTypeAssociation(1, 2);

    // initalize the smart character class
    SOFInterface.registerEntity(smartCharacterClassId, 2);
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function testSetup() public {
    address smartCharacterSystem = Systems.getSystem(SMART_CHARACTER_DEPLOYMENT_NAMESPACE.smartCharacterSystemId());
    ResourceId smartCharacterSystemId = SystemRegistry.get(smartCharacterSystem);
    assertEq(smartCharacterSystemId.getNamespace(), SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
  }

  function testCreateSmartCharacter(
    uint256 entityId,
    address characterAddress,
    uint256 corpId,
    uint256 itemId,
    uint256 typeId,
    uint256 volume,
    EntityRecordOffchainTableData memory offchainData,
    string memory tokenCid
  ) public {
    vm.assume(entityId != 0);
    vm.assume(corpId != 0);
    vm.assume(characterAddress != address(0));
    vm.assume(bytes(tokenCid).length != 0);

    // set smart character classId in the config
    smartCharacter.setCharClassId(smartCharacterClassId);

    EntityRecordData memory entityRecordData = EntityRecordData({ itemId: itemId, typeId: typeId, volume: volume });
    CharactersTableData memory charactersData = CharactersTableData({
      characterAddress: characterAddress,
      corpId: corpId,
      createdAt: block.timestamp
    });

    smartCharacter.createCharacter(entityId, characterAddress, corpId, entityRecordData, offchainData, tokenCid);
    CharactersTableData memory loggedCharactersData = CharactersTable.get(
      SMART_CHARACTER_DEPLOYMENT_NAMESPACE.charactersTableId(),
      entityId
    );
    EntityRecordTableData memory loggedEntityRecordData = EntityRecordTable.get(
      ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      entityId
    );

    assertEq(charactersData.characterAddress, loggedCharactersData.characterAddress);

    assertEq(entityRecordData.itemId, loggedEntityRecordData.itemId);
    assertEq(entityRecordData.typeId, loggedEntityRecordData.typeId);
    assertEq(entityRecordData.volume, loggedEntityRecordData.volume);

    assertEq(erc721Token.ownerOf(entityId), characterAddress);
    assertEq(
      keccak256(abi.encode(IERC721Metadata(address(erc721Token)).tokenURI(entityId))),
      keccak256(abi.encode(tokenCid)) // works because we have an empty base URI for this test case
    );

    // check that the character has been registered as an OBJECT entity
    EntityTableData memory entityTableData = EntityTable.get(
      SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityTableTableId(),
      entityId
    );
    assertEq(entityTableData.doesExists, true);
    assertEq(entityTableData.entityType, 1);

    uint256[] memory taggedEntityIds = EntityMap.get(SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityMapTableId(), entityId);
    uint256[] memory smartCharTaggedIds = new uint256[](1);
    smartCharTaggedIds[0] = entityId;

    // check that the character has been tagged for the appropriate class
    assertEq(taggedEntityIds.length, 1);
    assertEq(taggedEntityIds[0], smartCharacterClassId);
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
    smartCharacter.setCharClassId(smartCharacterClassId);

    smartCharacter.createCharacter(
      entityId,
      address(this),
      111,
      EntityRecordData({ typeId: 111, itemId: 11, volume: 11 }),
      EntityRecordOffchainTableData({ name: "characterName", dappURL: "noURL", description: "." }),
      "cid"
    );
    CharactersTableData memory charactersData = CharactersTable.get(
      SMART_CHARACTER_DEPLOYMENT_NAMESPACE.charactersTableId(),
      entityId
    );
    assertEq(charactersData.corpId, 111);

    smartCharacter.updateCorpId(entityId, 222);
    charactersData = CharactersTable.get(SMART_CHARACTER_DEPLOYMENT_NAMESPACE.charactersTableId(), entityId);
    assertEq(charactersData.corpId, 222);
  }

  function revertUpdateCorpId(uint256 characterId, uint256 corpId) public {
    vm.assume(characterId != 0);
    vm.assume(corpId == 0);

    vm.expectRevert(abi.encodeWithSelector(ISmartCharacterErrors.SmartCharacterDoesNotExist.selector, characterId));
    smartCharacter.updateCorpId(characterId, corpId);
  }
}
