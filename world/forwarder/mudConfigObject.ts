export default {
  namespace: "frontier",
  tables: {
    GlobalStaticData: {
      keySchema: {
        trustedForwarder: "address",
      },
      valueSchema: "bool",
    },
  },
};
