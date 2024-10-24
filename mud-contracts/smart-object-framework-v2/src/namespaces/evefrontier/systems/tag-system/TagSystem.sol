// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { Classes } from "../../codegen/tables/Classes.sol";
import { ClassSystemTagMap, ClassSystemTagMapData } from "../../codegen/tables/ClassSystemTagMap.sol";
import { SystemTags } from "../../codegen/tables/SystemTags.sol";

import { Id, IdLib } from "../../../../libs/Id.sol";
import { ENTITY_CLASS } from "../../../../types/entityTypes.sol";
import { TAG_SYSTEM } from "../../../../types/tagTypes.sol";

import { IEntitySystem } from "../../interfaces/IEntitySystem.sol";
import { ITagSystem } from "../../interfaces/ITagSystem.sol";

import { SmartObjectFramework } from "../../../../inherit/SmartObjectFramework.sol";

contract TagSystem is ITagSystem, SmartObjectFramework {
  /**
   * @notice set a SystemTag for a Class
   * @param classId An ENTITY_CLASS type Id referencing an existing Class to tag with `systemTagId`
   * @param systemTagId A TAG_SYSTEM type Id referencing a MUD System that has been registered on to the World which will be tagged to `classId`
   */
  function setSystemTag(Id classId, Id systemTagId) public {
    _setSystemTag(classId, systemTagId);
  }

  /**
   * @notice set multiple SystemTags for a Class
   * @param classId An ENTITY_CLASS type Id referencing an existing Class to tag with each System reference in `systemTagIds`
   * @param systemTagIds An array of TAG_SYSTEM type Ids each referencing a MUD System that has been registered on to the World and each of which will be tagged to `classId`
   */
  function setSystemTags(Id classId, Id[] memory systemTagIds) public {
    for (uint i = 0; i < systemTagIds.length; i++) {
      _setSystemTag(classId, systemTagIds[i]);
    }
  }

  /**
   * @notice remove a SystemTag for a Class
   * @dev removing a SystemTag from a Class may trigger/require dependent data deletions of Class/Object data entries in that System's associated Tables. Be sure to handle these dependencies accordingly in your System logic before removing a SystemTag
   * @param classId An ENTITY_CLASS type Id referencing an existing Class to remove each System reference in `systemTagIds` from
   * @param systemTagId A TAG_SYSTEM type Id referencing a MUD System to remove from `classId`
   */
  function removeSystemTag(Id classId, Id systemTagId) public {
    _removeSystemTag(classId, systemTagId);
  }

  /**
   * @notice remove multiple SystemTags for a Class
   * @param classId An ENTITY_CLASS type Id referencing an existing Class to tag with `systemTagId`
   * @param systemTagIds An array of TAG_SYSTEM type Ids each referencing a MUD System to remove from `classId`
   */
  function removeSystemTags(Id classId, Id[] memory systemTagIds) public {
    for (uint i = 0; i < systemTagIds.length; i++) {
      _removeSystemTag(classId, systemTagIds[i]);
    }
  }

  function _setSystemTag(Id classId, Id tagId) private {
    if (!Classes.getExists(classId)) {
      revert IEntitySystem.ClassDoesNotExist(classId);
    }

    if (Id.unwrap(tagId) == bytes32(0)) {
      revert InvalidTagId(tagId);
    }
    if (tagId.getType() != TAG_SYSTEM) {
      bytes2[] memory expected = new bytes2[](1);
      expected[0] = TAG_SYSTEM;
      revert WrongTagType(tagId.getType(), expected);
    }

    ResourceId systemId = ResourceId.wrap((Id.unwrap(tagId)));
    if (!(ResourceIds.getExists(systemId))) {
      revert SystemNotRegistered(systemId);
    }

    if (!SystemTags.getExists(tagId)) {
      SystemTags.set(tagId, true, new bytes32[](0));
    }

    if (!ClassSystemTagMap.getHasTag(classId, tagId)) {
      ClassSystemTagMap.set(classId, tagId, true, SystemTags.lengthClasses(tagId), Classes.lengthSystemTags(classId));
      Classes.pushSystemTags(classId, Id.unwrap(tagId));
      SystemTags.pushClasses(tagId, Id.unwrap(classId));
    } else {
      revert EntityAlreadyHasTag(classId, tagId);
    }
  }

  function _removeSystemTag(Id classId, Id tagId) private {
    if (!Classes.getExists(classId)) {
      revert IEntitySystem.ClassDoesNotExist(classId);
    }

    if (!SystemTags.getExists(tagId)) {
      revert TagDoesNotExist(tagId);
    }

    ClassSystemTagMapData memory classTagMapData = ClassSystemTagMap.get(classId, tagId);
    if (classTagMapData.hasTag) {
      Classes.updateSystemTags(
        classId,
        classTagMapData.tagIndex,
        Classes.getItemSystemTags(classId, Classes.lengthSystemTags(classId) - 1)
      );

      SystemTags.updateClasses(
        tagId,
        classTagMapData.classIndex,
        SystemTags.getItemClasses(tagId, SystemTags.lengthClasses(tagId) - 1)
      );

      ClassSystemTagMap.setTagIndex(
        classId,
        Id.wrap(Classes.getItemSystemTags(classId, Classes.lengthSystemTags(classId) - 1)),
        classTagMapData.tagIndex
      );

      ClassSystemTagMap.setClassIndex(
        Id.wrap(SystemTags.getItemClasses(tagId, SystemTags.lengthClasses(tagId) - 1)),
        tagId,
        classTagMapData.classIndex
      );

      ClassSystemTagMap.deleteRecord(classId, tagId);

      Classes.popSystemTags(classId);
      SystemTags.popClasses(tagId);
    } else {
      revert TagNotFound(classId, tagId);
    }
  }
}
