// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// make sure this matches constants.ts

bytes14 constant SMART_OBJECT_DEPLOYMENT_NAMESPACE = "SmartObjectv0";
bytes14 constant ACCESS_CONTROL_DEPLOYMENT_NAMESPACE = "RBACv0";
bytes14 constant ENTITY_RECORD_DEPLOYMENT_NAMESPACE = "EntityRecordv0";
bytes14 constant STATIC_DATA_DEPLOYMENT_NAMESPACE = "frontier"; //TODO this is weird but it fixes the `mud deploy` issue vs MUD Module deployment
bytes14 constant SMART_CHARACTER_DEPLOYMENT_NAMESPACE = "SmartCharactv0";
bytes14 constant EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE = "ERC721Puppetv0";

bytes16 constant STATIC_DATA_SYSTEM_NAME = "StaticData";
bytes16 constant ENTITY_RECORD_SYSTEM_NAME = "EntityRecord";
bytes16 constant SMART_CHARACTER_SYSTEM_NAME = "SmartCharacter";
bytes16 constant ERC721_SYSTEM_NAME = "ERC721System";
bytes16 constant SMART_STORAGE_UNIT_SYSTEM_NAME = "SmartStorageUnit";