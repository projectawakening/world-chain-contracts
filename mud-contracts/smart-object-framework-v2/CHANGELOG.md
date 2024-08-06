# @eveworld/smart-object-framework

## 0.1.0

### Patch Changes

- SOF refactor v0.1.0
  - Added explicit Id types for Entity IDs
  - reworked Entity management for simpler Class-to-Object instantiation and inheritance
  - reworked System-to-Class association and scoped enforcement to use a simpler Tagging pattern
  - removed world.initialMsgSender() - full MUD execution context coming in a future PR
  - removed Hooks - a reworked hook version coming in a future PR
- Updated dependencies
  - latticexyz/cli@2.0.12
  - latticexyz/schema-type@2.0.12
  - latticexyz/store@2.0.12
  - latticexyz/world@2.0.12
  - latticexyz/world-modules@2.0.12
  - prettier@3.2.5
  - prettier-plugin-solidity@1.3.1
  - solhint-config-mud@2.0.12
  - solhint-plugin-mud@2.0.12
  - typescript@5.4.5
  - add types/debug@4.1.7
  - removed @eveworld/common-constants@0.0.7
