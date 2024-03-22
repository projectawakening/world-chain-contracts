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


import { SMART_CHARACTER_DEPLOYMENT_NAMESPACE, EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE, STATIC_DATA_DEPLOYMENT_NAMESPACE} from "@eve/common-constants/src/constants.sol";
import { StaticDataModule } from "@eve/static-data/src/StaticDataModule.sol";
import { ERC721Module } from "@eve/eve-erc721-puppet/src/ERC721Module.sol";
import { registerERC721 } from "@eve/eve-erc721-puppet/src/registerERC721.sol";
import { IERC721Mintable } from "@eve/eve-erc721-puppet/src/IERC721Mintable.sol";
import { StaticDataGlobalTableData } from "@eve/static-data/src/codegen/tables/StaticDataGlobalTable.sol";

import { Utils } from "../src/Utils.sol";
import { SmartCharacterModule } from "../src/SmartCharacterModule.sol";
import { SmartCharacterLib } from "../src/SmartCharacterLib.sol";
import { createCoreModule } from "./CreateCoreModule.sol";
import { CharactersTable, CharactersTableData } from "../src/codegen/tables/CharactersTable.sol";

contract SmartCharacterTest is Test {
  using Utils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  SmartCharacterLib.World smartCharacter;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    // install module dependancies
    StaticDataModule staticDataModule = new StaticDataModule();
    PuppetModule puppetModule = new PuppetModule();
    baseWorld.installModule(puppetModule, new bytes(0));
    baseWorld.installModule(staticDataModule, abi.encode(STATIC_DATA_DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    IERC721Mintable erc721Token = registerERC721(
      baseWorld,
      EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE,
      StaticDataGlobalTableData({ name: "SmartCharacter", symbol: "SC", baseURI: "" })
    );

    // install smartCharacterModule
    SmartCharacterModule smartCharacterModule = new SmartCharacterModule();
    baseWorld.installModule(smartCharacterModule, abi.encode(SMART_CHARACTER_DEPLOYMENT_NAMESPACE));
    SmartCharacterLib.World({iface: baseWorld, namespace: SMART_CHARACTER_DEPLOYMENT_NAMESPACE}).registerERC721Token(address(erc721Token));
    smartCharacter = SmartCharacterLib.World(baseWorld, SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address smartCharacterSystem = Systems.getSystem(SMART_CHARACTER_DEPLOYMENT_NAMESPACE.smartCharacterSystemId());
    ResourceId smartCharacterSystemId = SystemRegistry.get(smartCharacterSystem);
    assertEq(smartCharacterSystemId.getNamespace(), SMART_CHARACTER_DEPLOYMENT_NAMESPACE);
  }

  function testCreateSmartCharacter(uint256 entityId, uint256 itemId, uint8 typeId, uint256 volume) public {
    // vm.assume(entityId != 0);
    // CharactersTableData memory data = CharactersTableData({itemId: itemId, typeId: typeId, volume: volume});
    
    // smartCharacter.createSmartCharacter(entityId, itemId, typeId, volume);
    // CharactersTableData memory tableData = CharactersTable.get(DEPLOYMENT_NAMESPACE.SmartCharacterTableTableId(), entityId);

    // assertEq(data.itemId, tableData.itemId);
    // assertEq(data.typeId, tableData.typeId);
    // assertEq(data.volume, tableData.volume);
  }

  function testCreateSmartCharacterOffchain(uint256 entityId, string memory name, string memory dappURL, string memory description) public {
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