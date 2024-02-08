import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  tables: {
    HasRole: {
      keySchema: { role: "bytes32", account: "address" },
      valueSchema: { hasRole: "bool" },
      tableIdArgument: true,  // allows table registration with tableId definition at runtime
      storeArgument: true,    // forces tableId input on getters/setters (abstracts out which namespace we deploy to)
    },
    RoleAdmin: {
      keySchema: { role: "bytes32" },
      valueSchema: { roleAdmin: "bytes32" },
      tableIdArgument: true,  // allows table registration with tableId definition at runtime
      storeArgument: true,    // forces tableId input on getters/setters (abstracts out which namespace we deploy to)
    },
  },
  excludeSystems: ["AccessControlSystem", "EveSystem"],
});
