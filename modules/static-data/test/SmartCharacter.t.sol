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


import { Utils } from "../src/utils.sol";
import { SmartCharacterModule } from "../src/SmartCharacterModule.sol";
import { SmartCharacterLib } from "../src/SmartCharacterLib.sol";
import { createCoreModule } from "./createCoreModule.sol";
import { CharactersTable, CharactersTableData } from "../src/codegen/tables/CharactersTable.sol";

contract SmartCharacterTest is Test {
  using Utils for bytes14;
  using SmartCharacterLib for SmartCharacterLib.World;
    using WorldResourceIdInstance for ResourceId;
  

  bytes14 constant SMART_CHAR_NAMESPACE = "SmartChar_v0";

  IBaseWorld baseWorld;
  SmartCharacterLib.World smartCharacter;
  SmartCharacterModule smartCharacterModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    SmartCharacterModule module = new SmartCharacterModule();
    baseWorld.installModule(module, abi.encode(SMART_CHAR_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    smartCharacter = SmartCharacterLib.World(baseWorld, SMART_CHAR_NAMESPACE);
  }

  function testSetup() public {
    address smartCharacterSystem = Systems.getSystem(SMART_CHAR_NAMESPACE.smartCharacterSystemId());
    ResourceId smartCharacterSystemId = SystemRegistry.get(smartCharacterSystem);
    assertEq(smartCharacterSystemId.getNamespace(), SMART_CHAR_NAMESPACE);
  }

  function testCreateCharacter() public {
    bytes32 key = smartCharacter.createCharacter("test");
    uint256 time = block.timestamp;

    CharactersTableData memory data = CharactersTable.get(SMART_CHAR_NAMESPACE.charactersTableTableId(), key);
    assertEq(data.name, "test");
    assertEq(data.createdAt, time);
  }
}