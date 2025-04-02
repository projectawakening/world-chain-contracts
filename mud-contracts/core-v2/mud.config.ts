import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "evefrontier",
  deploy: {
    customWorld: {
      sourcePath: "src/WorldWithEntryContext.sol",
      name: "WorldWithContext",
    },
  },
  systems: {
    DelegationControlSystem: {
      name: "DelegationContro",
      openAccess: true,
    },
    ForwarderSystem: {
      name: "ForwarderSystem",
      openAccess: true,
    },
  },
  tables: {
    GlobalStaticData: {
      schema: {
        trustedForwarder: "address",
        value: "bool",
      },
      key: ["trustedForwarder"],
    },
  },
});
