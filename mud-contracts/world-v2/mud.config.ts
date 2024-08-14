import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "eveworld",
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", type: "bytes32" },
  },
  tables: {
    /**********************
     * ENTITY RECORD MODULE *
     **********************/
    /**
     * Used to create a record for an game entity onchain
     * Singleton entityId is calculated as `uint256(keccak256("item:<placeholder_tenantID>-<game-itemID>"))`
     * Non Singleton entityId is calculated as `id = uint256(keccak256("item:<placeholder_tenantID>-<game-typeID>"))`
     */
    EntityRecord: {
      schema: {
        entityId: "uint256",
        itemId: "uint256",
        typeId: "uint256",
        volume: "uint256",
        recordExists: "bool",
      },
      key: ["entityId"],
    },
    EntityRecordMetadata: {
      schema: {
        entityId: "uint256",
        name: "string",
        dappURL: "string",
        description: "string",
      },
      key: ["entityId"],
    },
    /**********************
     * STATIC DATA MODULE *
     **********************/
    StaticData: {
      schema: {
        entityId: "uint256",
        cid: "string",
      },
      key: ["entityId"],
    },
    StaticDataMetadata: {
      schema: {
        classId: "bytes32",
        name: "string",
        baseURI: "string",
      },
      key: ["classId"],
    },
    /*************************
     * SMART CHARACTER MODULE *
     *************************/
    Characters: {
      schema: {
        characterId: "uint256",
        characterAddress: "address",
        createdAt: "uint256",
      },
      key: ["characterId"],
    },
    CharacterToken: {
      schema: {
        erc721Address: "address"
      },
      key: [],
    }
  },
});
