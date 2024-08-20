import { defineWorld } from "@latticexyz/world";

// export default defineWorld({
//   userTypes: {
//     Id: { type: "bytes32", filePath: "./src/libs/Id.sol" },
//     ResourceId: { type: "bytes32", filePath: "@latticexyz/store/src/ResourceId.sol" },
//   },
//   excludeSystems: ["SmartObjectFramework"],
//   namespaces: {
//     eveworld: {
//       systems: {
//         SmartObjectFramework: {
//           name: "SmartObjectFramework",
//           openAccess: true,
//           deploy: {
//             disabled: true,
//           },
//           codegen: {
//             disabled: true,
//           }
//         },
//         EntryForwarder: {
//           name: "EntryForwarder",
//           openAccess: true,
//         },
//         Entities: {
//           name: "Entities",
//           openAccess: true,
//         },
//         Tags: {
//           name: "Tags",
//           openAccess: true,
//         },
//       },
//       tables: {
//         /*******************
//          * ENTITES and ENTITY MAPPED DATA *
//          *******************/
//         Classes: {
//           schema: {
//             classId: "Id",
//             exists: "bool",
//             systemTags: "bytes32[]",
//             objects: "bytes32[]",
//           },
//           key: ["classId"],
//         },
//         ClassSystemTagMap: {
//           schema: {
//             classId: "Id",
//             tagId: "Id",
//             hasTag: "bool",
//             classIndex: "uint256",
//             tagIndex: "uint256",
//           },
//           key: ["classId", "tagId"],
//         },
//         ClassObjectMap: {
//           schema: {
//             classId: "Id",
//             objectId: "Id",
//             instanceOf: "bool",
//             objectIndex: "uint256",
//           },
//           key: ["classId", "objectId"],
//         },
//         Objects: {
//           schema: {
//             objectId: "Id",
//             exists: "bool",
//             class: "Id",
//           },
//           key: ["objectId"],
//         },
//         /*******************
//          * TAGS *
//          *******************/
//         SystemTags: {
//           schema: {
//             tagId: "Id",
//             exists: "bool",
//             classes: "bytes32[]",
//           },
//           key: ["tagId"],
//         },
//         /*******************
//          * EXECUTION CONTEXT *
//          *******************/
//         // Nonces - sequential nonce to preserve identifier uniquness in case of multiple execution entries or multiple same calls within the same execution (e.g., re-entrancy)
//         Nonces: {
//           schema: {
//             id: "bytes32",
//             exists: "bool",
//             nonce: "uint256"
//           },
//           key: ["id"],
//         },
//         // ExecutionContext - records all relevant global context for a full MUD transaction execution chain
//         ExecutionContext: {
//           schema: {
//             executionId: "bytes32",
//             exists: "bool",
//             blocknumber: "uint256",
//             callHistory: "bytes32[]",
//           },
//           key: ["executionId"],
//         },
//         // CallContext - records all relevant context for an internal MUD world.call()
//         CallContext: {
//           schema: {
//             callId: "bytes32",
//             exists: "bool",
//             executionId: "bytes32",
//             msgSender: "address",
//             msgValue: "uint256",
//             systemId: "ResourceId",
//             functionId: "bytes4",
//             argsData: "bytes"
//           },
//           key: ["callId"],
//         },
//       },
//     },
//   },
// });

export default defineWorld({
  namespace: "eveworld",
  userTypes: {
    Id: { type: "bytes32", filePath: "./src/libs/Id.sol" },
    ResourceId: { type: "bytes32", filePath: "@latticexyz/store/src/ResourceId.sol" },
  },
  excludeSystems: ["SmartObjectSystem"],
  systems: {
    Entities: {
      name: "Entities",
      openAccess: true,
    },
    EntryForwarder: {
      name: "EntryForwarder",
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
    /*******************
     * EXECUTION CONTEXT *
     *******************/
    // Nonces - sequential nonce to preserve identifier uniquness in case of multiple execution entries or multiple same calls within the same execution (e.g., re-entrancy)
    Nonces: {
      schema: {
        id: "bytes32",
        exists: "bool",
        nonce: "uint256",
      },
      key: ["id"],
    },
    // ExecutionContext - records all relevant global context for a full MUD transaction execution chain
    ExecutionContext: {
      schema: {
        executionId: "bytes32",
        exists: "bool",
        blocknumber: "uint256",
        callHistory: "bytes32[]",
      },
      key: ["executionId"],
    },
    // CallContext - records all relevant context for an internal MUD world.call()
    CallContext: {
      schema: {
        callId: "bytes32",
        exists: "bool",
        executionId: "bytes32",
        msgSender: "address",
        msgValue: "uint256",
        systemId: "ResourceId",
        functionId: "bytes4",
        argsData: "bytes",
      },
      key: ["callId"],
    },
  },
});
