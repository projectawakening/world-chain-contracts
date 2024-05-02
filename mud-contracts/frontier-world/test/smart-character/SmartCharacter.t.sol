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

import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eve/frontier-smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eve/frontier-smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eve/frontier-smart-object-framework/src/systems/core/ModuleCore.sol";

import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE, STATIC_DATA_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
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
import { createCoreModule } from "../CreateCoreModule.sol";

import { CharactersTable, CharactersTableData } from "../../src/codegen/tables/CharactersTable.sol";
import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../src/codegen/tables/EntityRecordOffchainTable.sol";

contract SmartCharacterTest is Test {
  using SmartCharacterUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  SmartCharacterLib.World smartCharacter;
  IERC721Mintable erc721Token;
  bytes14 constant SMART_CHAR_ERC721 = "ERC721Char";

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
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal{
    if(NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
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
    uint256 itemId,
    uint256 typeId,
    uint256 volume,
    EntityRecordOffchainTableData memory offchainData,
    string memory tokenCid
  ) public {
    vm.assume(entityId != 0);
    vm.assume(characterAddress != address(0));
    vm.assume(bytes(tokenCid).length != 0);

    EntityRecordTableData memory entityRecordData = EntityRecordTableData({
      itemId: itemId,
      typeId: typeId,
      volume: volume
    });
    CharactersTableData memory charactersData = CharactersTableData({
      characterAddress: characterAddress,
      createdAt: block.timestamp
    });

    smartCharacter.createCharacter(entityId, characterAddress, entityRecordData, offchainData, tokenCid);
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
}
