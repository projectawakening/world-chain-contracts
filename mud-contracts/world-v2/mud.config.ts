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
    /************************
     * ERC721 PUPPET MODULE *
     ************************/
    Balances: {
      schema: {
        account: "address",
        value: "uint256",
      },
      key: ["account"],
      codegen: {
        tableIdArgument: true,
      },
    },
    ERC721Metadata: {
      schema: {
        name: "string",
        symbol: "string",
        baseURI: "string",
      },
      key: [],
      codegen: {
        tableIdArgument: true,
      },
    },
    TokenURI: {
      schema: {
        tokenId: "uint256",
        tokenURI: "string",
      },
      key: ["tokenId"],
      codegen: {
        tableIdArgument: true,
      },
    },
    Owners: {
      schema: {
        tokenId: "uint256",
        owner: "address",
      },
      key: ["tokenId"],
      codegen: {
        tableIdArgument: true,
      },
    },
    TokenApproval: {
      schema: {
        tokenId: "uint256",
        account: "address",
      },
      key: ["tokenId"],
      codegen: {
        tableIdArgument: true,
      },
    },
    OperatorApproval: {
      schema: {
        owner: "address",
        operator: "address",
        approved: "bool",
      },
      key: ["owner", "operator"],
      codegen: {
        tableIdArgument: true,
      },
    },
    ERC721Registry: {
      schema: {
        namespaceId: "ResourceId",
        tokenAddress: "address",
      },
      key: ["namespaceId"],
      codegen: {
        tableIdArgument: true,
      },
    },

  },
});
