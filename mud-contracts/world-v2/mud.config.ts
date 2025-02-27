import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  deploy: {
    customWorld: {
      sourcePath: "src/WorldWithContextProxy.sol",
      name: "WorldWithContextProxy",
    },
  },
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", type: "bytes32" },
  },
  enums: {
    State: ["NULL", "UNANCHORED", "ANCHORED", "ONLINE", "DESTROYED"],
    KillMailLossType: ["SHIP", "POD"],
  },
  codegen: {
    generateSystemLibraries: true,
  },
  namespaces: {
    evefrontier: {
      tables: {
        /***************************
         * SMART ASSEMBLY TABLE *
         ***************************/
        /**
         * Used to store the assembly typeof a smart object
         */
        SmartAssembly: {
          schema: {
            smartObjectId: "uint256",
            smartAssemblyId: "uint256",
            smartAssemblyType: "string",
          },
          key: ["smartObjectId"],
        },

        /**********************
         * ENTITY RECORD TABLES *
         **********************/
        /**
         * Used to create a record which holds important game related data for an entity onchain
         * Singleton entities are treated as objects, OBJECT smartObjectIds are calculated as `objectId = uint256(keccak256(abi.encodePacked(<game-tenantID-as-utf8-string>, <game-itemID-as-uint256>)))`
         * Non-singleton entities are treated as a class, CLASS smartObjectIds as calculated as `classId = uint256(keccak256(abi.encodePacked(<game-typeID-as-uint256>)))`
         */
        EntityRecord: {
          schema: {
            smartObjectId: "uint256",
            exists: "bool",
            itemId: "uint256",
            typeId: "uint256",
            volume: "uint256",
            tenantId: "string",
          },
          key: ["smartObjectId"],
        },
        EntityRecordMetadata: {
          schema: {
            smartObjectId: "uint256",
            name: "string",
            dappURL: "string",
            description: "string",
          },
          key: ["smartObjectId"],
        },
        /*************************
         * SMART CHARACTER TABLE *
         *************************/
        Characters: {
          schema: {
            smartObjectId: "uint256",
            tribeId: "uint256",
            createdAt: "uint256",
          },
          key: ["smartObjectId"],
        },
        CharactersByAccount: {
          schema: {
            account: "address",
            smartObjectId: "uint256",
          },
          key: ["account"],
        },
        /*******************
         * LOCATION TABLE *
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

        /***************************
         * DEPLOYABLE TABLES *
         ***************************/
        /**
         * Used to store the Global state of the Deployable
         */
        GlobalDeployableState: {
          schema: {
            isPaused: "bool",
            updatedBlockNumber: "uint256",
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
            smartObjectId: "uint256",
            createdAt: "uint256",
            previousState: "State",
            currentState: "State",
            isValid: "bool",
            anchoredAt: "uint256",
            updatedBlockNumber: "uint256",
            updatedBlockTime: "uint256",
          },
          key: ["smartObjectId"],
        },
        /*******************
         * FUEL TABLES *
         *******************/

        /**
         * Used to store the fuel balance of a Deployable
         */
        Fuel: {
          schema: {
            smartObjectId: "uint256",
            fuelUnitVolume: "uint256",
            fuelConsumptionIntervalInSeconds: "uint256",
            fuelMaxCapacity: "uint256",
            fuelAmount: "uint256",
            lastUpdatedAt: "uint256", // unix time in seconds
          },
          key: ["smartObjectId"],
        },

        /*******************
         * INVENTORY TABLES *
         *******************/
        Inventory: {
          schema: {
            smartObjectId: "uint256",
            capacity: "uint256",
            usedCapacity: "uint256",
            items: "uint256[]",
          },
          key: ["smartObjectId"],
        },
        /**
         * Used to store the inventory items of a in-game smart storage unit
         */
        InventoryItem: {
          schema: {
            smartObjectId: "uint256",
            inventoryItemId: "uint256",
            quantity: "uint256",
            index: "uint256",
            stateUpdate: "uint256",
          },
          key: ["smartObjectId", "inventoryItemId"],
        },
        //EPHEMERAL INVENTORY MODULE
        /**
         * Used to Store Ephemeral Capacity by smartObjectId
         */
        EphemeralInvCapacity: {
          schema: {
            smartObjectId: "uint256",
            capacity: "uint256",
          },
          key: ["smartObjectId"],
        },
        /**
         * Used to store the ephemeral inventory details of a in-game smart storage unit
         * Each user has a separate ephemeral inventory capacity
         */
        EphemeralInv: {
          schema: {
            smartObjectId: "uint256",
            ephemeralInvOwner: "address",
            usedCapacity: "uint256",
            items: "uint256[]",
          },
          key: ["smartObjectId", "ephemeralInvOwner"],
        },
        /**
         * Used to store the ephemeral inventory items details of a in-game smart storage unit
         */
        EphemeralInvItem: {
          schema: {
            smartObjectId: "uint256",
            inventoryItemId: "uint256",
            ephemeralInvOwner: "address",
            quantity: "uint256",
            index: "uint256",
            stateUpdate: "uint256",
          },
          key: ["smartObjectId", "inventoryItemId", "ephemeralInvOwner"],
        },
        /**
         * Used to store the transfer details when a item is exchanged
         */
        ItemTransferOffchain: {
          schema: {
            smartObjectId: "uint256",
            inventoryItemId: "uint256",
            previousOwner: "address",
            currentOwner: "address",
            quantity: "uint256",
            updatedAt: "uint256",
          },
          key: ["smartObjectId", "inventoryItemId"],
        },
        /*************************
         * SMART TURRET TABLES *
         *************************/
        SmartTurretConfig: {
          schema: {
            smartObjectId: "uint256",
            systemId: "ResourceId",
          },
          key: ["smartObjectId"],
        },

        /*************************
         * SMART GATE TABLES *
         *************************/
        SmartGateConfig: {
          schema: {
            smartObjectId: "uint256",
            systemId: "ResourceId",
            maxDistance: "uint256",
          },
          key: ["smartObjectId"],
        },

        SmartGateLink: {
          schema: {
            sourceGateId: "uint256",
            destinationGateId: "uint256",
            isLinked: "bool",
          },
          key: ["sourceGateId"],
        },
      },
    },
  },
});
