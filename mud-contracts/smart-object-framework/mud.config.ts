import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "frontier",
  excludeSystems: ["EveSystem"],
  systems: {
    EntityCore: {
      name: "EntityCore",
      openAccess: true,
    },
    ModuleCore: {
      name: "ModuleCore",
      openAccess: true,
    },
    HookCore: {
      name: "HookCore",
      openAccess: true,
    },
  },
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", internalType: "bytes32" },
  },
  tables: {
    /**
     * Used to store the entity type
     */
    EntityType: {
      keySchema: { typeId: "uint8" },
      valueSchema: {
        doesExists: "bool",
        typeName: "bytes32",
      },
      tableIdArgument: true,
    },
    /**
     * Used to register an entity by its type
     */
    EntityTable: {
      keySchema: { entityId: "uint256" },
      valueSchema: {
        doesExists: "bool", //Tracks the entity which is no longer valid
        entityType: "uint8",
      },
      tableIdArgument: true,
    },
    /**
     * Used to enforce association/tagging possibility by entity types
     * eg: Objects can be tagged or grouped under a Class but not vice versa, so Object -> Class is possible
     * also it should prohibit Object-to-Object and Class-to-Class tagging as well
     */
    EntityTypeAssociation: {
      keySchema: { entityType: "uint8", taggedEntityType: "uint8" },
      valueSchema: {
        isAllowed: "bool",
      },
      tableIdArgument: true,
    },
    /**
     * Used to tag/map an entity by its tagged entityIds
     * eg: Similar objects can be grouped as Class, and tagged with a classId.
     * One entity can be tagged with multiple classIds
     */
    EntityMap: {
      keySchema: { entityId: "uint256" },
      valueSchema: {
        taggedEntityIds: "uint256[]",
      },
      tableIdArgument: true,
    },
    /**
     * Used to associate a entity with a specific set of modules and hooks
     * to inherit the functionality of those modules(systems) and hooks
     */
    EntityAssociation: {
      keySchema: { entityId: "uint256" },
      valueSchema: {
        moduleIds: "uint256[]",
        hookIds: "uint256[]",
      },
      tableIdArgument: true,
    },

    /************************
     * Module
     ************************/
    /**
     * Used to semantically group systems associated with a module
     */
    ModuleTable: {
      keySchema: { moduleId: "uint256", systemId: "ResourceId" },
      valueSchema: {
        //Can add functions registered in this system if we need granular control
        moduleName: "bytes16",
        doesExists: "bool",
      },
      tableIdArgument: true,
    },

    /**
     * Only used for lookup purpose to find the moduleIds associated with a system
     * TODO - Do we need this table?
     */
    ModuleSystemLookup: {
      keySchema: { moduleId: "uint256" },
      valueSchema: {
        systemIds: "bytes32[]",
      },
      tableIdArgument: true,
    },

    /************************
     * Hooks
     ************************/
    /**
     * Hook Table is used to register the function to be executed
     * before or after a existing function in the system
     */
    HookTable: {
      keySchema: { hookId: "uint256" }, //keccak(hookSystemId, hookFunctionId)
      valueSchema: {
        isHook: "bool",
        systemId: "ResourceId", //Callback systemId of the hook
        functionSelector: "bytes4", //Callback functionId of the hook
      },
      tableIdArgument: true,
    },
    /**
     * Used to map the function to be executed before a existing function in a system by hookId
     */
    HookTargetBefore: {
      keySchema: { hookId: "uint256", targetId: "uint256" }, // targetId - uint256(keccak(systemSelector, functionId))
      valueSchema: {
        hasHook: "bool",
        systemSelector: "ResourceId", //Target system to hook against
        functionSelector: "bytes4", //Target function to hook against
      },
      tableIdArgument: true,
    },
    /**
     * Used to map the function to be executed after a existing function in a system by hookId
     */
    HookTargetAfter: {
      keySchema: { hookId: "uint256", targetId: "uint256" },
      valueSchema: {
        hasHook: "bool",
        systemSelector: "ResourceId", //Target system to hook against
        functionSelector: "bytes4", //Target function to hook against
      },
      tableIdArgument: true,
    },
  },
});
