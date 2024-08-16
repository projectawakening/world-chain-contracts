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
        classId: "bytes32",
        name: "string",
        baseURI: "string",
      },
      key: ["classId"],
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
      key: ["updatedBlockNumber"],
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
        entityId: "uint256",
        erc721Address: "address",
      },
      key: ["entityId"],
    },
  },
});
