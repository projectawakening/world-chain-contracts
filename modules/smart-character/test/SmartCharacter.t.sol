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

import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE} from "@eve/common-constants/src/constants.sol";


import { Utils } from "../src/utils.sol";
import { SmartCharacterModule } from "../src/SmartCharacterModule.sol";
import { SmartCharacterLib } from "../src/SmartCharacterLib.sol";
import { createCoreModule } from "./createCoreModule.sol";
import { CharactersTable, CharactersTableData } from "../src/codegen/tables/CharactersTable.sol";

contract SmartCharacterTest is Test {
  using Utils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  SmartCharacterLib.World smartCharacter;
  SmartCharacterModule smartCharacterModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    SmartCharacterModule module = new SmartCharacterModule();
    baseWorld.installModule(module, abi.encode(DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    smartCharacter = SmartCharacterLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address smartCharacterSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartCharacterSystemId());
    ResourceId smartCharacterSystemId = SystemRegistry.get(smartCharacterSystem);
    assertEq(smartCharacterSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
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