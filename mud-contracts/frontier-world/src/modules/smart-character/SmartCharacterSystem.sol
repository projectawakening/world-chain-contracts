// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { SMART_CHARACTER_MODULE_NAME, SMART_CHARACTER_MODULE_NAMESPACE } from "./constants.sol";
import { Characters, CharactersData } from "../../codegen/index.sol";
import { EntityRecordData, SmartObjectData } from "../types.sol";

contract SmartCharacterSystem is System {
  using WorldResourceIdInstance for ResourceId;

  function createCharacter(
    uint256 characterId,
    address characterAddress,
    EntityRecordData memory entityRecord,
    SmartObjectData memory smartObjectData
  ) public {
    uint256 createdAt = block.timestamp;
    Characters.set(characterId, characterAddress, createdAt);
    //Save the entity record in EntityRecord Module
    //Save the smartObjectData in ERC721 Module
    //TODO implementation
  }

  function characterSystemId() public pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: SMART_CHARACTER_MODULE_NAMESPACE,
        name: SMART_CHARACTER_MODULE_NAME
      });
  }
}
