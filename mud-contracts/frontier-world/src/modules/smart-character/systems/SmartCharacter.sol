// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";

import { registerERC721 } from "../../eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";

import { CharactersTable } from "../../../codegen/tables/CharactersTable.sol";
import { CharactersConstantsTable } from "../../../codegen/tables/CharactersConstantsTable.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../../codegen/tables/EntityRecordOffchainTable.sol";
import { StaticDataGlobalTableData } from "../../../codegen/tables/StaticDataGlobalTable.sol";
import { Utils } from "../Utils.sol";

contract SmartCharacter is EveSystem {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;

  error SmartCharacterERC721AlreadyInitialized();
  error SmartCharacterTokenCidCannotBeEmpty(uint256 characterId, string tokenCid);

  // TODO: this alone weighs more than 25kbytes, find alternative
  function registerERC721Token(address tokenAddress) public {
    if (CharactersConstantsTable.getErc721Address(_namespace().charactersConstantsTableId()) != address(0)) {
      revert SmartCharacterERC721AlreadyInitialized();
    }
    CharactersConstantsTable.setErc721Address(_namespace().charactersConstantsTableId(), tokenAddress);
  }

  function createCharacter(
    uint256 characterId,
    address characterAddress,
    EntityRecordTableData memory entityRecord,
    EntityRecordOffchainTableData memory entityRecordOffchain,
    string memory tokenCid
  ) public {
    // TODO: uncomment this if/when static data flows off-chain are ready
    // if (bytes(tokenCid).length == 0) revert SmartCharacterTokenCidCannotBeEmpty(characterId, tokenCid);

    uint256 createdAt = block.timestamp;
    CharactersTable.set(_namespace().charactersTableId(), characterId, characterAddress, createdAt);
    //Save the entity record in EntityRecord Module
    // TODO: Do we have to create the entityId <-> characterId linkup here in Smart Object Framework ?
    _entityRecordLib().createEntityRecord(characterId, entityRecord.itemId, entityRecord.typeId, entityRecord.volume);
    //Save the smartObjectData in ERC721 Module
    _entityRecordLib().createEntityRecordOffchain(characterId, entityRecordOffchain.name, entityRecordOffchain.dappURL, entityRecordOffchain.description);
    IERC721Mintable(CharactersConstantsTable.getErc721Address((_namespace().charactersConstantsTableId()))).mint(
      characterAddress,
      characterId
    );
    IERC721Mintable(CharactersConstantsTable.getErc721Address((_namespace().charactersConstantsTableId()))).setCid(
      characterId,
      tokenCid
    );
  }

  // TODO: this is kinda dirty.
  function _entityRecordLib() internal view returns (EntityRecordLib.World memory) {
    return EntityRecordLib.World({ iface: IBaseWorld(_world()), namespace: DEPLOYMENT_NAMESPACE });
  }

  function characterSystemId() public view returns (ResourceId) {
    return _namespace().smartCharacterSystemId();
  }
}
