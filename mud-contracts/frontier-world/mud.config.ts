import { mudConfig } from "@latticexyz/world/register";
// this import statement doesnt support remappings for some reason
import constants = require("./node_modules/@eve/common-constants/src/constants.json");

export default mudConfig({
  //having a short namespace as the MUD Namespace must be <= 14 characters
  namespace: constants.namespace.FRONTIER_WORLD_DEPLOYMENT,
  excludeSystems: ["ERC721System"],
  systems: {
    SmartCharacter: {
      name: constants.systemName.SMART_CHARACTER,
      openAccess: true,
    },
    SmartStorageUnit: {
      name: constants.systemName.SMART_STORAGE_UNIT,
      openAccess: true,
    },
    StaticData: {
      name: constants.systemName.STATIC_DATA,
      openAccess: true,
    },
    EntityRecord: {
      name: constants.systemName.ENTITY_RECORD,
      openAccess: true,
    },
    LocationSystem: {
      name: constants.systemName.LOCATION,
      openAccess: true,
    },
    SmartDeployable: {
      name: constants.systemName.SMART_DEPLOYABLE,
      openAccess: true,
    },
    Inventory: {
      name: constants.systemName.INVENTORY,
      openAccess: true,
    },
    EphemeralInventory: {
      name: constants.systemName.EPHEMERAL_INVENTORY,
      openAccess: true,
    },
    InventoryInteract: {
      name: constants.systemName.INVENTORY_INTERACT,
      openAccess: true,
    },
  },
  enums: {
    State: ["NULL", "UNANCHORED", "ANCHORED", "ONLINE", "OFFLINE", "DESTROYED"],
  },
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", internalType: "bytes32" },
  },
  tables: {
    /**********************
     * STATIC DATA MODULE *
     **********************/

    /**
     * Used to store the IPFS CID of a smart object
     */
    StaticDataTable: {
      keySchema: {
        entityId: "uint256",
      },
      valueSchema: {
        cid: "string",
      },
      tableIdArgument: true,
    },

    /**
     * Used to store the DNS which servers the IPFS gateway
     */
    StaticDataGlobalTable: {
      keySchema: {
        systemId: "ResourceId",
      },
      valueSchema: {
        name: "string",
        symbol: "string",
        baseURI: "string",
      },
      tableIdArgument: true,
      // TODO: put this flag back online for release ? This might be a bit heavy; for now tests are relying on on-chain
      // offchainOnly: true,
    },

    /**********************
     * STATIC DATA MODULE *
     **********************/

    /**
     * Used to store the metadata of a in-game entity
     * Singleton entityId is the hash of (typeId, itemId and databaseId) ?
     * Non Singleton entityId is the hash of the typeId
     */
    EntityRecordTable: {
      keySchema: {
        entityId: "uint256",
      },
      valueSchema: {
        itemId: "uint256",
        typeId: "uint256",
        volume: "uint256",
        recordExists: "bool",
      },
      tableIdArgument: true,
    },
    EntityRecordOffchainTable: {
      keySchema: {
        entityId: "uint256",
      },
      valueSchema: {
        name: "string",
        dappURL: "string",
        description: "string",
      },
      tableIdArgument: true,
      // offchainOnly: true, TODO: do we enable this flag for playtest release ?
    },

    /**************************
     * SMART CHARACTER MODULE *
     **************************/

    /**
     * Maps the in-game character ID to on-chain EOA address
     */
    CharactersTable: {
      keySchema: {
        characterId: "uint256",
      },
      valueSchema: {
        characterAddress: "address",
        createdAt: "uint256",
      },
      tableIdArgument: true,
    },

    CharactersConstantsTable: {
      keySchema: {},
      valueSchema: {
        erc721Address: "address",
      },
      tableIdArgument: true,
    },

    /*******************
     * LOCATION MODULE *
     *******************/

    /**
     * Used to store the location of a in-game entity in the solar system
     */
    LocationTable: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        solarSystemId: "uint256",
        x: "uint256",
        y: "uint256",
        z: "uint256",
      },
      tableIdArgument: true,
    },

    /***************************
     * SMART DEPLOYABLE MODULE *
     ***************************/

    GlobalDeployableState: {
      keySchema: {},
      valueSchema: {
        updatedBlockNumber: "uint256",
        globalState: "State",
        lastGlobalOffline: "uint256",
        lastGlobalOnline: "uint256",
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the current state of a deployable
     */
    DeployableState: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        createdAt: "uint256",
        previousState: "State",
        currentState: "State",
        isValid: "bool",
        validityStateUpdatedAt: "uint256",
        updatedBlockNumber: "uint256",
        updatedBlockTime: "uint256",
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the fuel balance of a deployable
     */
    DeployableFuelBalance: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        fuelUnitVolume: "uint256",
        fuelConsumptionPerMinute: "uint256",
        fuelMaxCapacity: "uint256",
        fuelAmount: "uint256",
        lastUpdatedAt: "uint256", //UNIX time
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the deployable details of a in-game entity
     */
    DeployableTokenTable: {
      keySchema: {},
      valueSchema: {
        erc721Address: "address",
      },
      tableIdArgument: true,
    },

    //INVENTORY MODULE
    /**
     * Used to store the inventory details of a in-game smart storage unit
     */
    InventoryTable: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        capacity: "uint256",
        usedCapacity: "uint256",
        items: "uint256[]",
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the inventory items of a in-game smart storage unit
     */
    InventoryItemTable: {
      keySchema: {
        smartObjectId: "uint256",
        inventoryItemId: "uint256",
      },
      valueSchema: {
        quantity: "uint256",
        index: "uint256",
        stateUpdate: "uint256",
      },
      tableIdArgument: true,
    },
    //EPHEMERAL INVENTORY MODULE
    /**
     * Used to Store Ephemeral Capacity by smartObjectId
     */
    EphemeralInvCapacityTable: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        capacity: "uint256",
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the ephemeral inventory details of a in-game smart storage unit
     * Each user has a separate ephemeral inventory capacity
     */
    EphemeralInvTable: {
      keySchema: {
        smartObjectId: "uint256",
        ephemeralInvOwner: "address",
      },
      valueSchema: {
        usedCapacity: "uint256",
        items: "uint256[]",
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the ephemeral inventory items details of a in-game smart storage unit
     */
    EphemeralInvItemTable: {
      keySchema: {
        smartObjectId: "uint256",
        inventoryItemId: "uint256",
        ephemeralInvItemOwner: "address",
      },
      valueSchema: {
        quantity: "uint256",
        index: "uint256",
        stateUpdate: "uint256",
      },
      tableIdArgument: true,
    },
    /**
     * Used to store the transfer details when a item is exchanged
     */
    ItemTransferOffchainTable: {
      keySchema: {
        smartObjectId: "uint256",
        inventoryItemId: "uint256",
      },
      valueSchema: {
        previousOwner: "address",
        currentOwner: "address",
        quantity: "uint256",
        updatedAt: "uint256",
      },
      tableIdArgument: true,
      // offchainOnly: true,
    },

    /************************
     * ERC721 PUPPET MODULE *
     ************************/

    Balances: {
      keySchema: {
        account: "address",
      },
      valueSchema: {
        value: "uint256",
      },
      tableIdArgument: true,
    },

    TokenURI: {
      keySchema: {
        tokenId: "uint256",
      },
      valueSchema: {
        tokenURI: "string",
      },
      tableIdArgument: true,
    },

    Owners: {
      keySchema: {
        tokenId: "uint256",
      },
      valueSchema: {
        owner: "address",
      },
      tableIdArgument: true,
    },

    ERC721Registry: {
      keySchema: {
        namespaceId: "ResourceId",
      },
      valueSchema: {
        tokenAddress: "address",
      },
      tableIdArgument: true,
    },

    TokenApproval: {
      keySchema: {
        tokenId: "uint256",
      },
      valueSchema: {
        account: "address",
      },
      tableIdArgument: true,
    },

    OperatorApproval: {
      keySchema: {
        owner: "address",
        operator: "address",
      },
      valueSchema: {
        approved: "bool",
      },
      tableIdArgument: true,
    },
  },
});
