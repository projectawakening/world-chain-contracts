import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "SmartChar_v0",
  excludeSystems: ["EveSystem"],
  systems: {
    SmartCharacter: {
      name: "SmartCharacter",
      openAccess: true,
    },
  },
  tables: {
    CharactersTable: {
      valueSchema: {
        createdAt: "uint256",
        name: "string",
      },
      storeArgument: true,
      tableIdArgument: true,
    },
  },
});
