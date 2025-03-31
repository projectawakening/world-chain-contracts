// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { ResourceIdLib } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { Entity, EntityData } from "../../codegen/tables/Entity.sol";
import { EntityTagMap, EntityTagMapData } from "../../codegen/tables/EntityTagMap.sol";
import { entitySystem } from "../../codegen/systems/EntitySystemLib.sol";

import { TagId, TagIdLib } from "../../../../libs/TagId.sol";

import { TAG_TYPE_PROPERTY, TAG_TYPE_ENTITY_RELATION, TAG_TYPE_RESOURCE_RELATION, TAG_IDENTIFIER_CLASS, TAG_IDENTIFIER_OBJECT, TAG_IDENTIFIER_ENTITY_COUNT, TagParams, EntityRelationValue, ResourceRelationValue } from "./types.sol";

import { IWorldWithContext } from "../../../../IWorldWithContext.sol";

import { SmartObjectFramework } from "../../../../inherit/SmartObjectFramework.sol";

contract TagSystem is SmartObjectFramework {
  using TagIdLib for TagId;

  error Tag_InvalidTagId(TagId tagId);
  error Tag_TagDoesNotExist(TagId tagId);
  error Tag_TagNotFound(uint256 entityId, TagId tagId);
  error Tag_TagTypeNotDefined(bytes2 tagType);
  error Tag_ResourceNotRegistered(ResourceId systemId);
  error Tag_EntityAlreadyHasTag(uint256 entityId, TagId tagId);
  error Tag_InvalidCaller(address caller);
  error Tag_OnlyClassOrObjectPropertyAllowed();
  error Tag_EntityDoesNotExist(uint256 entityId);
  /**
   * @notice set a Tag for an Entity
   * @param entityId A unique uint256 entity ID
   * @param tagParams A TagParams struct containing the tagId and value
   */
  function setTag(uint256 entityId, TagParams memory tagParams) public context access(entityId) {
    _setTag(entityId, tagParams);
  }

  /**
   * @notice set multiple Tags for an Entity
   * @param entityId A unique uint256 entity ID
   * @param tagParams An array of TagParams structs containing the tagId and value
   */
  function setTags(uint256 entityId, TagParams[] memory tagParams) public {
    for (uint i = 0; i < tagParams.length; i++) {
      _setTag(entityId, tagParams[i]);
    }
  }

  /**
   * @notice remove a Tag from an Entity
   * @param entityId A unique uint256 entity ID
   * @param tagId A TagId tagId
   * @dev Warning: removing a Tag from an Entity may trigger/require dependent data deletions of in associated Enity or Resource Tables. Be sure to handle these dependencies accordingly in your System logic before removing a Tag

   */
  function removeTag(uint256 entityId, TagId tagId) public context access(entityId) {
    _removeTag(entityId, tagId);
  }

  /**
   * @notice remove multiple SystemTags for a Class or Object
   * @param entityId A unique uint256 entity ID
   * @param tagIds An array of TagId tagIds
   */
  function removeTags(uint256 entityId, TagId[] memory tagIds) public {
    for (uint i = 0; i < tagIds.length; i++) {
      _removeTag(entityId, tagIds[i]);
    }
  }

  function _setTag(uint256 entityId, TagParams memory tagParams) private {
    if (TagId.unwrap(tagParams.tagId) == bytes32(0)) {
      revert Tag_InvalidTagId(tagParams.tagId);
    }

    if (!EntityTagMap.getHasTag(entityId, tagParams.tagId)) {
      uint256 tagIndex;
      if (tagParams.tagId.getType() == TAG_TYPE_PROPERTY) {
        if (
          tagParams.tagId.getIdentifier() == TAG_IDENTIFIER_OBJECT ||
          tagParams.tagId.getIdentifier() == TAG_IDENTIFIER_CLASS ||
          tagParams.tagId.getIdentifier() == TAG_IDENTIFIER_ENTITY_COUNT
        ) {
          uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
          // we only allow EntitySystem.sol as a caller to set these tags
          if (callCount <= 1) {
            // revert, no direct calls
            revert Tag_InvalidCaller(_msgSender());
          } else {
            (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext();
            ResourceId callingSystemId = SystemRegistry.get(msgSender);
            if (callingSystemId.unwrap() != entitySystem.toResourceId().unwrap()) {
              revert Tag_InvalidCaller(msgSender);
            }
          }
        }

        tagIndex = Entity.lengthPropertyTags(entityId);

        Entity.pushPropertyTags(entityId, TagId.unwrap(tagParams.tagId));
      } else if (tagParams.tagId.getType() == TAG_TYPE_ENTITY_RELATION) {
        EntityRelationValue memory entityRelationValue = abi.decode(tagParams.value, (EntityRelationValue));

        if (
          keccak256(abi.encodePacked(entityRelationValue.relationType)) == keccak256(abi.encodePacked("INHERITANCE"))
        ) {
          uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
          // we only allow EntitySystem.sol as a caller to set these tags
          if (callCount <= 1) {
            // revert, no direct calls
            revert Tag_InvalidCaller(_msgSender());
          } else {
            (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext();
            ResourceId callingSystemId = SystemRegistry.get(msgSender);
            if (callingSystemId.unwrap() != entitySystem.toResourceId().unwrap()) {
              revert Tag_InvalidCaller(msgSender);
            }
          }
        }

        if (!Entity.getExists(entityRelationValue.relatedEntityId)) {
          revert Tag_EntityDoesNotExist(entityRelationValue.relatedEntityId);
        }

        tagIndex = 0;

        Entity.setEntityRelationTag(entityId, tagParams.tagId);
      } else if (tagParams.tagId.getType() == TAG_TYPE_RESOURCE_RELATION) {
        ResourceRelationValue memory resourceRelationValue = abi.decode(tagParams.value, (ResourceRelationValue));
        ResourceId resourceId = ResourceIdLib.encode(
          resourceRelationValue.resourceType,
          resourceRelationValue.resourceIdentifier
        );

        if (!(ResourceIds.getExists(resourceId))) {
          revert Tag_ResourceNotRegistered(resourceId);
        }

        tagIndex = Entity.lengthResourceRelationTags(entityId);

        Entity.pushResourceRelationTags(entityId, TagId.unwrap(tagParams.tagId));
      } else {
        revert Tag_TagTypeNotDefined(tagParams.tagId.getType());
      }

      EntityTagMap.set(entityId, tagParams.tagId, true, tagIndex, tagParams.value);
    } else {
      revert Tag_EntityAlreadyHasTag(entityId, tagParams.tagId);
    }
  }

  function _removeTag(uint256 entityId, TagId tagId) private {
    EntityTagMapData memory entityTagMapData = EntityTagMap.get(entityId, tagId);

    if (entityTagMapData.hasTag) {
      if (tagId.getType() == TAG_TYPE_PROPERTY) {
        if (
          tagId.getIdentifier() == TAG_IDENTIFIER_OBJECT ||
          tagId.getIdentifier() == TAG_IDENTIFIER_CLASS ||
          tagId.getIdentifier() == TAG_IDENTIFIER_ENTITY_COUNT
        ) {
          uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
          // we only allow EntitySystem.sol as a caller to set these tags
          if (callCount <= 1) {
            // revert, no direct calls
            revert Tag_InvalidCaller(_msgSender());
          } else {
            (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext();
            ResourceId callingSystemId = SystemRegistry.get(msgSender);
            if (callingSystemId.unwrap() != entitySystem.toResourceId().unwrap()) {
              revert Tag_InvalidCaller(msgSender);
            }
          }
        }

        Entity.updatePropertyTags(
          entityId,
          entityTagMapData.tagIndex,
          Entity.getItemPropertyTags(entityId, Entity.lengthPropertyTags(entityId) - 1)
        );

        EntityTagMap.setTagIndex(
          entityId,
          TagId.wrap(Entity.getItemPropertyTags(entityId, Entity.lengthPropertyTags(entityId) - 1)),
          entityTagMapData.tagIndex
        );

        Entity.popPropertyTags(entityId);
      } else if (tagId.getType() == TAG_TYPE_ENTITY_RELATION) {
        EntityRelationValue memory entityRelationValue = abi.decode(entityTagMapData.value, (EntityRelationValue));

        if (
          keccak256(abi.encodePacked(entityRelationValue.relationType)) == keccak256(abi.encodePacked("INHERITANCE"))
        ) {
          uint256 callCount = IWorldWithContext(_world()).getWorldCallCount();
          // we only allow EntitySystem.sol as a caller to remove these tags
          if (callCount <= 1) {
            // revert, no direct calls
            revert Tag_InvalidCaller(_msgSender());
          } else {
            (, , address msgSender, ) = IWorldWithContext(_world()).getWorldCallContext();
            ResourceId callingSystemId = SystemRegistry.get(msgSender);
            if (callingSystemId.unwrap() != entitySystem.toResourceId().unwrap()) {
              revert Tag_InvalidCaller(msgSender);
            }
          }
        }

        Entity.setEntityRelationTag(entityId, TagId.wrap(bytes32(0)));
      } else if (tagId.getType() == TAG_TYPE_RESOURCE_RELATION) {
        Entity.updateResourceRelationTags(
          entityId,
          entityTagMapData.tagIndex,
          Entity.getItemResourceRelationTags(entityId, Entity.lengthResourceRelationTags(entityId) - 1)
        );

        EntityTagMap.setTagIndex(
          entityId,
          TagId.wrap(Entity.getItemResourceRelationTags(entityId, Entity.lengthResourceRelationTags(entityId) - 1)),
          entityTagMapData.tagIndex
        );

        Entity.popResourceRelationTags(entityId);
      }

      EntityTagMap.deleteRecord(entityId, tagId);
    } else {
      revert Tag_TagNotFound(entityId, tagId);
    }
  }
}
