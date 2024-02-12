import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
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
  tables: {
    /**
     * Used to register an entity (object or class)
     */
    EntityTable: {
      keySchema: { "entityId": "uint256" },
      valueSchema: {
        doesExists: "bool",
        entityType: "uint8"
      }
    },
    /**
     * Used to tag an object under a class
     */
    ObjectClassMap: {
      keySchema: { "objectId": "uint256" },
      valueSchema: {
        classId: "uint256"
      }
    },
    /**
     * Used to associate a class with a specific set of modules and hooks 
     * to inherit the functionality of those modules(systems) and hooks
     */
    ClassAssociationTable: {
      keySchema: { "classId": "uint256" },
      valueSchema: {
        isAssociated: "bool", // TODO Remove its unnecessary 
        moduleIds: "uint256[]",
        hookIds: "uint256[]"  // TODO reverse lookup
      }
    },
    /**
     * Used to associate a object with a specific set of modules and hooks
     * to inherit the functionality of those modules(systems) and hooks
     */
    ObjectAssociationTable: {
      keySchema: { "objectId": "uint256" },
      valueSchema: {
        isAssociated: "bool",
        moduleIds: "uint256[]",
        hookIds: "uint256[]"
      }
    },
    /**
     * Used to semantically group systems associated with a module
     */
    ModuleTable: {
      keySchema: { "moduleId": "uint256", "systemId": "bytes32" },
      valueSchema: {
        //Can add functions registered in this system if we need granular control
        moduleName: "bytes16",
        doesExists: "bool",
      }
    },

    /************************
     * Hooks
     ************************/
    /**
     * Hook Table is used to register the function to be executed 
     * before or after a existing function in the system
     */
    HookTable: {
      keySchema: { "hookId": "uint256" }, //keccak(hookSystemId, hookFunctionId)
      valueSchema: {
        isHook: "bool",
        namespace: "bytes14",
        hookName: "bytes16",
        systemId: "bytes32",
        functionSelector: "bytes4"
      }
    },
    /**
     * Used to map the function to be executed before a existing function in a system by hookId
     */
    HookTargetBeforeTable: {
      keySchema: { "hookId": "uint256", "targetId": "uint256" }, // targetId - uint256(keccak(systemSelector, functionId))
      valueSchema: {
        hasHook: "bool",
        systemSelector: "bytes32",
        functionSelector: "bytes4"
      }
    },
    /**
     * Used to map the function to be executed after a existing function in a system by hookId
     */
    HookTargetAfterTable: {
      keySchema: { "hookId": "uint256", "targetId": "uint256" },
      valueSchema: {
        hasHook: "bool",
        systemSelector: "bytes32",
        functionSelector: "bytes4"
      }
    },
  },
});
