import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "RBAC_v0",
  tables: {
    HasRole: {
      keySchema: { role: "bytes32", account: "address" },
      valueSchema: { hasRole: "bool" },
      tableIdArgument: true,
      storeArgument: true,
    },
    RoleAdmin: {
      keySchema: { role: "bytes32" },
      valueSchema: { roleAdmin: "bytes32" },
      tableIdArgument: true,
      storeArgument: true,
    },
    EntityToRole: {
      keySchema: {entity: "uint256" },
      valueSchema: { role: "bytes32" },
      tableIdArgument: true,
      storeArgument: true,
    },
    EntityToRoleAND: {
      keySchema: {entity: "uint256" },
      valueSchema: { roles: "bytes32[]" },
      tableIdArgument: true,
      storeArgument: true,
    },
    EntityToRoleOR: {
      keySchema: {entity: "uint256" },
      valueSchema: { roles: "bytes32[]" },
      tableIdArgument: true,
      storeArgument: true,
    }
  },
  excludeSystems: ["EveSystem"],
});
