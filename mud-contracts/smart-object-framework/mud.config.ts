import { defineWorld } from "@latticexyz/world";
import * as constants from "./node_modules/@eveworld/common-constants/src/constants.json";

export default defineWorld({
  namespace: constants.namespace.FRONTIER_WORLD_DEPLOYMENT,
  deploy: {
    customWorld: {
      sourcePath: "src/WorldWithEntryContext.sol",
      name: "WorldWithEntryContext",
    },
  },
  excludeSystems: ["EveSystem"],
  systems: {
    EntitySystem: {
      name: "EntitySystem",
      openAccess: true,
    },
    ModuleSystem: {
      name: "ModuleSystem",
      openAccess: true,
    },
    HookSystem: {
      name: "HookSystem",
      openAccess: true,
    },
  },
  userTypes: {
    ResourceId: { type: "bytes32", filePath: "@latticexyz/store/src/ResourceId.sol" },
  },
  tables: {
    /**
     * Used to store the entity type
     */
    EntityType: {
      schema: {
        typeId: "uint8",
        doesExists: "bool",
        typeName: "bytes32",
      },
      key: ["typeId"],
    },
    /**
     * Used to register an entity by its type
     */
    EntityTable: {
      schema: {
        entityId: "uint256",
        doesExists: "bool",
        entityType: "uint8",
      },
      key: ["entityId"],
    },
    /**
     * Used to enforce association/tagging possibility by entity types
     * eg: Objects can be tagged or grouped under a Class but not vice versa, so Object -> Class is possible
     * also it should prohibit Object-to-Object and Class-to-Class tagging as well
     */
    EntityTypeAssociation: {
      schema: {
        entityType: "uint8",
        taggedEntityType: "uint8",
        isAllowed: "bool",
      },
      key: ["entityType", "taggedEntityType"],
    },
    /**
     * Used to tag/map an entity by its tagged entityIds
     * eg: Similar objects can be grouped as Class, and tagged with a classId.
     * One entity can be tagged with multiple classIds
     */
    EntityMap: {
      schema: {
        entityId: "uint256",
        taggedEntityIds: "uint256[]",
      },
      key: ["entityId"],
    },
    /**
     * Used to associate a entity with a specific set of modules and hooks
     * to inherit the functionality of those modules(systems) and hooks
     */
    EntityAssociation: {
      schema: {
        entityId: "uint256",
        moduleIds: "uint256[]",
        hookIds: "uint256[]",
      },
      key: ["entityId"],
    },

    /************************
     * Module
     ************************/
    /**
     * Used to semantically group systems associated with a module
     */
    ModuleTable: {
      schema: {
        moduleId: "uint256",
        systemId: "ResourceId",
        moduleName: "bytes16",
        doesExists: "bool",
      },
      key: ["moduleId", "systemId"],
    },

    /**
     * Only used for lookup purpose to find the moduleIds associated with a system
     * TODO - Do we need this table?
     */
    ModuleSystemLookup: {
      schema: {
        moduleId: "uint256",
        systemIds: "bytes32[]",
      },
      key: ["moduleId"],
    },

    /************************
     * Hooks
     ************************/
    /**
     * Hook Table is used to register the function to be executed
     * before or after a existing function in the system
     */
    HookTable: {
      schema: {
        hookId: "uint256",
        isHook: "bool",
        systemId: "ResourceId",
        functionSelector: "bytes4",
      },
      key: ["hookId"],
    },
    /**
     * Used to map the function to be executed before a existing function in a system by hookId
     */
    HookTargetBefore: {
      schema: {
        hookId: "uint256",
        targetId: "uint256",
        hasHook: "bool",
        systemSelector: "ResourceId",
        functionSelector: "bytes4",
      },
      key: ["hookId", "targetId"],
    },
    /**
     * Used to map the function to be executed after a existing function in a system by hookId
     */
    HookTargetAfter: {
      schema: {
        hookId: "uint256",
        targetId: "uint256",
        hasHook: "bool",
        systemSelector: "ResourceId",
        functionSelector: "bytes4",
      },
      key: ["hookId", "targetId"],
    },
  },
});
