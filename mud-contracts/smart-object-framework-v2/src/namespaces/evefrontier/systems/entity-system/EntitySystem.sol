// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { Classes, ClassesData } from "../../codegen/tables/Classes.sol";
import { ClassSystemTagMap } from "../../codegen/tables/ClassSystemTagMap.sol";
import { ClassObjectMap, ClassObjectMapData } from "../../codegen/tables/ClassObjectMap.sol";
import { Objects } from "../../codegen/tables/Objects.sol";

import { Id, IdLib } from "../../../../libs/Id.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../../../../types/entityTypes.sol";
import { TAG_SYSTEM } from "../../../../types/tagTypes.sol";

import { ITagSystem } from "../../interfaces/ITagSystem.sol";
import { IEntitySystem } from "../../interfaces/IEntitySystem.sol";

import { Utils as TagSystemUtils } from "../tag-system/Utils.sol";

import { SmartObjectFramework } from "../../../../inherit/SmartObjectFramework.sol";

/**
 * @title EntitySystem
 * @author CCP Games
 * @dev Manage Class and Object creation/deletion through the use of reference Ids { see, `libs/Id.sol` and `types/entityTypes.sol`}
 */
contract EntitySystem is IEntitySystem, SmartObjectFramework {
  /**
   * @notice register a Class Entity into the SOF with an initial set of assigned SystemTags
   * @param classId A unique ENTITY_CLASS type Id for referencing a newly registred Class Entity within SOF compatible Systems
   * @param systemTags An array of TAG_SYSTEM type Ids which correlate to exsiting MUD System ResourceIds for tagging a Class with
   */
  function registerClass(Id classId, Id[] memory systemTags) public {
    if (Id.unwrap(classId) == bytes32(0)) {
      revert InvalidEntityId(classId);
    }
    if (classId.getType() != ENTITY_CLASS) {
      bytes2[] memory expected = new bytes2[](1);
      expected[0] = ENTITY_CLASS;
      revert WrongEntityType(classId.getType(), expected);
    }
    if (Classes.getExists(classId)) {
      revert ClassAlreadyExists(classId);
    }

    Classes.set(classId, true, new bytes32[](0), new bytes32[](0));

    IWorldKernel(_world()).call(
      TagSystemUtils.tagSystemId(),
      abi.encodeCall(ITagSystem.setSystemTags, (classId, systemTags))
    );
  }

  /**
   * @notice delete a registered Class
   * @dev deleting a Class may trigger/require dependent data deletions of Class data entries in any related/tagged System associated Tables. Be sure to handle these dependencies accordingly in your System logic before deleting a Class
   * @param classId An ENTITY_CLASS type Id reference of an existing Class to be deleted
   */
  function deleteClass(Id classId) public {
    if (!Classes.getExists(classId)) {
      revert ClassDoesNotExist(classId);
    }

    ClassesData memory class = Classes.get(classId);
    if (class.objects.length > 0) {
      revert ClassHasObjects(classId, class.objects.length);
    }

    Id[] memory systemTags = new Id[](class.systemTags.length);
    for (uint i = 0; i < class.systemTags.length; i++) {
      systemTags[i] = Id.wrap(class.systemTags[i]);
    }

    IWorldKernel(_world()).call(
      TagSystemUtils.tagSystemId(),
      abi.encodeCall(ITagSystem.removeSystemTags, (classId, systemTags))
    );

    Classes.deleteRecord(classId);
  }

  /**
   * @notice delete multiple registered Classes
   * @param classIds An array of ENTITY_CLASS type Id references of existing Classes to be deleted
   */
  function deleteClasses(Id[] memory classIds) public {
    for (uint i = 0; i < classIds.length; i++) {
      deleteClass(classIds[i]);
    }
  }

  /**
   * @notice instantiate an Object from a given Class
   * @param classId An ENTITY_CLASS type Id referencing an existing Class from which the Object will be instantiated
   * @param objectId An ENTITY_OBJECT type Id reference assigned to the newly instantiated Object
   */
  function instantiate(Id classId, Id objectId) public {
    if (!Classes.getExists(classId)) {
      revert ClassDoesNotExist(classId);
    }

    if (Id.unwrap(objectId) == bytes32(0)) {
      revert InvalidEntityId(objectId);
    }
    if (objectId.getType() != ENTITY_OBJECT) {
      bytes2[] memory expected = new bytes2[](1);
      expected[0] = ENTITY_OBJECT;
      revert WrongEntityType(objectId.getType(), expected);
    }
    if (Objects.getExists(objectId)) {
      Id instanceClass = Objects.getClass(objectId);
      revert ObjectAlreadyExists(objectId, instanceClass);
    }

    ClassObjectMap.set(classId, objectId, true, Classes.lengthObjects(classId));
    Classes.pushObjects(classId, Id.unwrap(objectId));
    Objects.set(objectId, true, classId);
  }

  /**
   * @notice delete an instantiated Object
   * @dev deleting an Object may trigger/require dependent data deletions of Object data entries in any related/tagged System associated Tables. Be sure to handle these dependencies accordingly in your System logic before deleting an Object
   * @param objectId An ENTITY_OBJECT type Id referencing an existing Object
   */
  function deleteObject(Id objectId) public {
    if (!Objects.getExists(objectId)) {
      revert ObjectDoesNotExist(objectId);
    }

    Id classId = Objects.getClass(objectId);
    ClassObjectMapData memory classObjectMapData = ClassObjectMap.get(classId, objectId);

    Classes.updateObjects(
      classId,
      classObjectMapData.objectIndex,
      Classes.getItemObjects(classId, Classes.lengthObjects(classId) - 1)
    );

    ClassObjectMap.setObjectIndex(
      classId,
      Id.wrap(Classes.getItemObjects(classId, Classes.lengthObjects(classId) - 1)),
      classObjectMapData.objectIndex
    );

    ClassObjectMap.deleteRecord(classId, objectId);

    Classes.popObjects(classId);

    Objects.deleteRecord(objectId);
  }

  /**
   * @notice delete multiple instantiated Objects
   * @param objectIds An array of ENTITY_OBJECT type Ids referencing existing Objects
   */
  function deleteObjects(Id[] memory objectIds) public {
    for (uint i = 0; i < objectIds.length; i++) {
      deleteObject(objectIds[i]);
    }
  }
}
