// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { registerERC721 } from "../../eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";

import { AccessModified } from "../../access/systems/AccessModified.sol";
import { ClassConfig } from "../../../codegen/tables/ClassConfig.sol";
import { CharactersTable } from "../../../codegen/tables/CharactersTable.sol";
import { CharactersByAddressTable } from "../../../codegen/tables/CharactersByAddressTable.sol";
import { CharactersConstantsTable } from "../../../codegen/tables/CharactersConstantsTable.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTableData } from "../../../codegen/tables/EntityRecordOffchainTable.sol";
import { StaticDataGlobalTableData } from "../../../codegen/tables/StaticDataGlobalTable.sol";
import { Utils } from "../Utils.sol";
import { EntityRecordData } from "../types.sol";
import { ISmartCharacterErrors } from "../ISmartCharacterErrors.sol";

contract SmartCharacterSystem is AccessModified, EveSystem {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;
  using SmartObjectLib for SmartObjectLib.World;

  // TODO: this alone weighs more than 25kbytes, find alternative
  function registerERC721Token(
    address tokenAddress
  ) public onlyAdmin hookable(uint256(ResourceId.unwrap(_systemId())), _systemId()) {
    if (CharactersConstantsTable.getErc721Address() != address(0)) {
      revert ISmartCharacterErrors.SmartCharacter_ERC721AlreadyInitialized();
    }
    CharactersConstantsTable.setErc721Address(tokenAddress);
  }

  function createCharacter(
    uint256 characterId,
    address characterAddress,
    uint256 corpId,
    EntityRecordData memory entityRecord,
    EntityRecordOffchainTableData memory entityRecordOffchain,
    string memory tokenCid
  ) public onlyAdmin hookable(characterId, _systemId()) {
    // TODO: uncomment this if/when static data flows off-chain are ready
    // if (bytes(tokenCid).length == 0) revert SmartCharacterTokenCidCannotBeEmpty(characterId, tokenCid);

    uint256 classId = ClassConfig.getClassId(_systemId());

    if (classId == 0) {
      revert ISmartCharacterErrors.SmartCharacter_UndefinedClassIds();
    }

    // enforce one-to-one mapping
    if (CharactersByAddressTable.get(characterAddress) != 0) {
      revert ISmartCharacterErrors.SmartCharacter_AlreadyCreated(characterAddress, characterId);
    }

    // register smartObjectId as an object
    _smartObjectLib().registerEntity(characterId, 1);

    // tag this object's entity Id to a defined classId
    _smartObjectLib().tagEntity(characterId, classId);

    uint256 createdAt = block.timestamp;

    CharactersTable.set(characterId, characterAddress, corpId, createdAt);
    CharactersByAddressTable.set(characterAddress, characterId);
    //Save the entity record in EntityRecord Module
    _entityRecordLib().createEntityRecord(characterId, entityRecord.itemId, entityRecord.typeId, entityRecord.volume);
    //Save the smartObjectData in ERC721 Module
    _entityRecordLib().createEntityRecordOffchain(
      characterId,
      entityRecordOffchain.name,
      entityRecordOffchain.dappURL,
      entityRecordOffchain.description
    );
    IERC721Mintable(CharactersConstantsTable.getErc721Address()).mint(characterAddress, characterId);
    IERC721Mintable(CharactersConstantsTable.getErc721Address()).setCid(characterId, tokenCid);
  }

  function updateCorpId(uint256 characterId, uint256 corpId) public onlyAdmin hookable(characterId, _systemId()) {
    if (CharactersTable.getCorpId(characterId) == 0) {
      revert ISmartCharacterErrors.SmartCharacterDoesNotExist(characterId);
    }
    CharactersTable.setCorpId(characterId, corpId);
  }

  function setCharClassId(
    uint256 classId
  ) public onlyAdmin hookable(uint256(ResourceId.unwrap(_systemId())), _systemId()) {
    ClassConfig.setClassId(_systemId(), classId);
  }

  function _entityRecordLib() internal view returns (EntityRecordLib.World memory) {
    return EntityRecordLib.World({ iface: IBaseWorld(_world()), namespace: ENTITY_RECORD_DEPLOYMENT_NAMESPACE });
  }

  function _smartObjectLib() internal view returns (SmartObjectLib.World memory) {
    return SmartObjectLib.World({ iface: IBaseWorld(_world()), namespace: SMART_OBJECT_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartCharacterSystemId();
  }
}
