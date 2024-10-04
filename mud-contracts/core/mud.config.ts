import { defineWorld } from "@latticexyz/world";
import constants = require("./node_modules/@eveworld/common-constants/src/constants.json");

export default defineWorld({
  namespace: constants.namespace.FRONTIER_WORLD_DEPLOYMENT,
  deploy: {
    customWorld: {
      sourcePath: "src/WorldWithEntryContext.sol",
      name: "WorldWithEntryContext",
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
    Role: {
      schema: {
        role: "bytes32",
        value: "address",
      },
      key: ["role"],
    },
  },
});
