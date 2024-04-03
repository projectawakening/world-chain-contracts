import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  //having a short namespace as the MUD Namespace must be <= 14 characters
  namespace: "frontier",
  systems: {
    SmartCharacterSystem: {
      name: "SmartCharacterSystem",
      openAccess: true,
    },
    SmartStorageUnit: {
      name: "SmartStorageUnit",
      openAccess: true,
    },
    StaticData: {
      name: "StaticData",
      openAccess: true,
    },
    EntityRecord: {
      name: "EntityRecord",
      openAccess: true,
    },
  },
  enums: {
    State: ["ANCHOR", "UNANCHOR", "ONLINE", "OFFLINE", "DESTROYED"],
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
        key: "uint256",
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
        typeId: "uint8",
        volume: "uint256",
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

    /**
     * Maps the in-game character ID to on-chain EOA address
     */
    Characters: {
      keySchema: {
        characterId: "uint256",
      },
      valueSchema: {
        characterAddress: "address",
        createdAt: "uint256",
      },
    },

    //LOCATION MODULE
    /**
     * Used to store the location of a in-game entity in the solar system
     */
    Location: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        solarsystemId: "uint256",
        x: "uint256",
        y: "uint256",
        z: "uint256",
      },
    },
    //DEPLOYABLE MODULE
    GlobalDeployableState: {
      valueSchema: {
        globalState: "State",
        updatedBlockNumber: "uint256",
      },
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
        state: "State",
        updatedBlockNumber: "uint256",
      },
    },

    //INVENTORY MODULE
    /**
     * Used to store the inventory details of a in-game smart storage unit
     */
    Inventory: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        capacity: "uint256",
        usedCapacity: "uint256",
        items: "uint256[]",
      },
    },
    /**
     * Used to store the inventory items of a in-game smart storage unit
     */
    InventoryItem: {
      keySchema: {
        smartObjectId: "uint256",
        inventoryItemId: "uint256",
      },
      valueSchema: {
        quantity: "uint256",
        index: "uint256",
      },
    },
    //EPHEMERAL INVENTORY MODULE
    /**
     * Used to store the inventory details of a in-game smart storage unit
     */
    EphemeralInventory: {
      keySchema: {
        smartObjectId: "uint256",
        owner: "address",
      },
      valueSchema: {
        capacity: "uint256",
        usedCapacity: "uint256",
        items: "uint256[]",
      },
    },
    /**
     * Used to store the inventory items of a in-game smart storage unit
     */
    EphemeralInvItem: {
      keySchema: {
        smartObjectId: "uint256",
        inventoryItemId: "uint256",
        owner: "address",
      },
      valueSchema: {
        quantity: "uint256",
        index: "uint256",
      },
    },
    /**
     * Used to store the transfer details when a item is exchanged
     */
    ItemTransferOffchain: {
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
      offchainOnly: true,
    },
  },
});
