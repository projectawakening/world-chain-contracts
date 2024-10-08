import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "eveworld",
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", type: "bytes32" },
  },
  enums: {
    State: ["NULL", "UNANCHORED", "ANCHORED", "ONLINE", "DESTROYED"],
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
    /**
     * Used to store the IPFS CID of a smart object
     */
    StaticData: {
      schema: {
        entityId: "uint256",
        cid: "string",
      },
      key: ["entityId"],
    },
    /**
     * Used to store the DNS which servers the IPFS gateway
     */
    StaticDataMetadata: {
      schema: {
        baseURI: "string",
      },
      key: [],
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
        erc721Address: "address",
      },
      key: [],
    },

    /*************************
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
    /*******************
     * LOCATION MODULE *
     *******************/

    /**
     * Used to store the location of a in-game entity in the solar system
     */
    Location: {
      schema: {
        smartObjectId: "uint256",
        solarSystemId: "uint256",
        x: "uint256",
        y: "uint256",
        z: "uint256",
      },
      key: ["smartObjectId"],
    },
    /*******************
     * FUEL MODULE *
     *******************/

    /**
     * Used to store the fuel balance of a Smart Deployable
     */
    Fuel: {
      schema: {
        entityId: "uint256",
        fuelUnitVolume: "uint256",
        fuelConsumptionIntervalInSeconds: "uint256",
        fuelMaxCapacity: "uint256",
        fuelAmount: "uint256",
        lastUpdatedAt: "uint256", // unix time in seconds
      },
      key: ["entityId"],
    },

    /***************************
     * SMART DEPLOYABLE MODULE *
     ***************************/

    /**
     * Used to store the Global state of the Smart Deployable
     */
    GlobalDeployableState: {
      schema: {
        updatedBlockNumber: "uint256",
        isPaused: "bool",
        lastGlobalOffline: "uint256",
        lastGlobalOnline: "uint256",
      },
      key: [],
    },
    /**
     * Used to store the current state of a deployable
     */
    DeployableState: {
      schema: {
        entityId: "uint256",
        createdAt: "uint256",
        previousState: "State",
        currentState: "State",
        isValid: "bool",
        anchoredAt: "uint256",
        updatedBlockNumber: "uint256",
        updatedBlockTime: "uint256",
      },
      key: ["entityId"],
    },
    /**
     * Used to store the deployable details of a in-game entity
     */
    DeployableTokenTable: {
      schema: {
        erc721Address: "address",
      },
      key: [],
    },
  },
});
