# @eveworld/world-v2

## 0.1.0

### Major Changes

- removing module implementation 
- implemented cross system calls using world.call(systemId, callData). `systemIds` is being generated from the Utils
- renaming all on-chain ids to smartObjectIds
- changed deployment namespace from `eveworld` to `evefrontier`
- changed the struct definition for external interfaces to reduce dependancy on table defined structs 
- defined all errors in System to include all errors in abi by default