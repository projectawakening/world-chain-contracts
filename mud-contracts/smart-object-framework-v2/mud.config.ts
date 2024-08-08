import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "eveworld",
  userTypes: {
    Id: { type: "bytes32", filePath: "./src/libs/Id.sol" },
    ResourceId: { type: "bytes32", filePath: "@latticexyz/store/src/ResourceId.sol" },
  },
  systems: {
    Entities: {
      name: "Entities",
      openAccess: true,
    },
    Tags: {
      name: "Tags",
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
});
