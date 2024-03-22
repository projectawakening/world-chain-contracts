// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { EntityRecordLib } from "@eve/entity-record/src/EntityRecordLib.sol";
import { EntityRecordTableData } from "@eve/entity-record/src/codegen/tables/EntityRecordTable.sol";
import { registerERC721 } from "@eve/eve-erc721-puppet/src/registerERC721.sol";
import { IERC721Mintable } from "@eve/eve-erc721-puppet/src/IERC721Mintable.sol";
import { StaticDataGlobalTableData } from "@eve/static-data/src/codegen/tables/StaticDataGlobalTable.sol";

import { CharactersTable } from "../codegen/tables/CharactersTable.sol";
import { CharactersConstantsTable } from "../codegen/tables/CharactersConstantsTable.sol";
import { Utils } from "../Utils.sol";

contract SmartCharacter is EveSystem {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;

  error SmartCharacterERC721AlreadyInitialized();

  // TODO: this alone weighs more than 25kbytes, find alternative
  function registerERC721Token(address tokenAddress) public {
    if(CharactersConstantsTable.getErc721Address(_namespace().charactersConstantsTableId()) != address(0)) {
      revert SmartCharacterERC721AlreadyInitialized();
    }
    CharactersConstantsTable.setErc721Address(_namespace().charactersConstantsTableId(), tokenAddress);
  }

  function createCharacter(
    uint256 characterId,
    address characterAddress,
    EntityRecordTableData memory entityRecord,
    string memory tokenURI
  ) public {
    uint256 createdAt = block.timestamp;
    CharactersTable.set(_namespace().charactersTableId(), characterId, characterAddress, createdAt);
    //Save the entity record in EntityRecord Module
    // TODO: Do we have to create the entityId <-> characterId linkup here in Smart Object Framework ?
    EntityRecordLib.World({
      iface: IBaseWorld(_world()),
      namespace: ENTITY_RECORD_DEPLOYMENT_NAMESPACE
    })
    .createEntityRecord(
      characterId,
      entityRecord.itemId,
      entityRecord.typeId,
      entityRecord.volume
    );
    //Save the smartObjectData in ERC721 Module
    IERC721Mintable(CharactersConstantsTable.getErc721Address((_namespace().charactersConstantsTableId()))).mint(characterAddress, characterId);
    IERC721Mintable(CharactersConstantsTable.getErc721Address((_namespace().charactersConstantsTableId()))).setCid(characterId, tokenURI);
  }

  function characterSystemId() public view returns (ResourceId) {
    return _namespace().smartCharacterSystemId();
  }
}