import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  userTypes: {
    Id: { type: "bytes32", filePath: "./src/libs/Id.sol" },
    ResourceId: { type: "bytes32", filePath: "@latticexyz/store/src/ResourceId.sol" },
  },
  excludeSystems: ["SmartObjectFramework"],
  namespaces: {
    eveworld: {
      systems: {
        EntitySystem: {
          name: "EntitySystem",
          openAccess: true,
        },
        TagSystem: {
          name: "TagSystem",
          openAccess: true,
        },
      },
      tables: {
        /*******************
         * ENTITES and ENTITY MAPPED DATA *
         *******************/
        Classes: {
          schema: {
            classId: "Id",
            exists: "bool",
            systemTags: "bytes32[]",
            objects: "bytes32[]",
          },
          key: ["classId"],
        },
        ClassSystemTagMap: {
          schema: {
            classId: "Id",
            tagId: "Id",
            hasTag: "bool",
            classIndex: "uint256",
            tagIndex: "uint256",
          },
          key: ["classId", "tagId"],
        },
        ClassObjectMap: {
          schema: {
            classId: "Id",
            objectId: "Id",
            instanceOf: "bool",
            objectIndex: "uint256",
          },
          key: ["classId", "objectId"],
        },
        Objects: {
          schema: {
            objectId: "Id",
            exists: "bool",
            class: "Id",
          },
          key: ["objectId"],
        },
        /*******************
         * TAGS *
         *******************/
        SystemTags: {
          schema: {
            tagId: "Id",
            exists: "bool",
            classes: "bytes32[]",
          },
          key: ["tagId"],
        },
      },
    },
  },
});
