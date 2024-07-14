// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

// Import store internals
import { IStore } from "@latticexyz/store/src/IStore.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { StoreCore } from "@latticexyz/store/src/StoreCore.sol";
import { Bytes } from "@latticexyz/store/src/Bytes.sol";
import { Memory } from "@latticexyz/store/src/Memory.sol";
import { SliceLib } from "@latticexyz/store/src/Slice.sol";
import { EncodeArray } from "@latticexyz/store/src/tightcoder/EncodeArray.sol";
import { FieldLayout } from "@latticexyz/store/src/FieldLayout.sol";
import { Schema } from "@latticexyz/store/src/Schema.sol";
import { EncodedLengths, EncodedLengthsLib } from "@latticexyz/store/src/EncodedLengths.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Import user types
import { Id } from "./../../libs/Id.sol";

struct ClassObjectMapData {
  bool instanceOf;
  uint256 objectIndex;
}

library ClassObjectMap {
  // Hex below is the result of `WorldResourceIdLib.encode({ namespace: "eveworld", name: "ClassObjectMap", typeId: RESOURCE_TABLE });`
  ResourceId constant _tableId = ResourceId.wrap(0x7462657665776f726c64000000000000436c6173734f626a6563744d61700000);

  FieldLayout constant _fieldLayout =
    FieldLayout.wrap(0x0021020001200000000000000000000000000000000000000000000000000000);

  // Hex-encoded key schema of (bytes32, bytes32)
  Schema constant _keySchema = Schema.wrap(0x004002005f5f0000000000000000000000000000000000000000000000000000);
  // Hex-encoded value schema of (bool, uint256)
  Schema constant _valueSchema = Schema.wrap(0x00210200601f0000000000000000000000000000000000000000000000000000);

  /**
   * @notice Get the table's key field names.
   * @return keyNames An array of strings with the names of key fields.
   */
  function getKeyNames() internal pure returns (string[] memory keyNames) {
    keyNames = new string[](2);
    keyNames[0] = "classId";
    keyNames[1] = "objectId";
  }

  /**
   * @notice Get the table's value field names.
   * @return fieldNames An array of strings with the names of value fields.
   */
  function getFieldNames() internal pure returns (string[] memory fieldNames) {
    fieldNames = new string[](2);
    fieldNames[0] = "instanceOf";
    fieldNames[1] = "objectIndex";
  }

  /**
   * @notice Register the table with its config.
   */
  function register() internal {
    StoreSwitch.registerTable(_tableId, _fieldLayout, _keySchema, _valueSchema, getKeyNames(), getFieldNames());
  }

  /**
   * @notice Register the table with its config.
   */
  function _register() internal {
    StoreCore.registerTable(_tableId, _fieldLayout, _keySchema, _valueSchema, getKeyNames(), getFieldNames());
  }

  /**
   * @notice Get instanceOf.
   */
  function getInstanceOf(Id classId, Id objectId) internal view returns (bool instanceOf) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    bytes32 _blob = StoreSwitch.getStaticField(_tableId, _keyTuple, 0, _fieldLayout);
    return (_toBool(uint8(bytes1(_blob))));
  }

  /**
   * @notice Get instanceOf.
   */
  function _getInstanceOf(Id classId, Id objectId) internal view returns (bool instanceOf) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    bytes32 _blob = StoreCore.getStaticField(_tableId, _keyTuple, 0, _fieldLayout);
    return (_toBool(uint8(bytes1(_blob))));
  }

  /**
   * @notice Set instanceOf.
   */
  function setInstanceOf(Id classId, Id objectId, bool instanceOf) internal {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreSwitch.setStaticField(_tableId, _keyTuple, 0, abi.encodePacked((instanceOf)), _fieldLayout);
  }

  /**
   * @notice Set instanceOf.
   */
  function _setInstanceOf(Id classId, Id objectId, bool instanceOf) internal {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreCore.setStaticField(_tableId, _keyTuple, 0, abi.encodePacked((instanceOf)), _fieldLayout);
  }

  /**
   * @notice Get objectIndex.
   */
  function getObjectIndex(Id classId, Id objectId) internal view returns (uint256 objectIndex) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    bytes32 _blob = StoreSwitch.getStaticField(_tableId, _keyTuple, 1, _fieldLayout);
    return (uint256(bytes32(_blob)));
  }

  /**
   * @notice Get objectIndex.
   */
  function _getObjectIndex(Id classId, Id objectId) internal view returns (uint256 objectIndex) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    bytes32 _blob = StoreCore.getStaticField(_tableId, _keyTuple, 1, _fieldLayout);
    return (uint256(bytes32(_blob)));
  }

  /**
   * @notice Set objectIndex.
   */
  function setObjectIndex(Id classId, Id objectId, uint256 objectIndex) internal {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreSwitch.setStaticField(_tableId, _keyTuple, 1, abi.encodePacked((objectIndex)), _fieldLayout);
  }

  /**
   * @notice Set objectIndex.
   */
  function _setObjectIndex(Id classId, Id objectId, uint256 objectIndex) internal {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreCore.setStaticField(_tableId, _keyTuple, 1, abi.encodePacked((objectIndex)), _fieldLayout);
  }

  /**
   * @notice Get the full data.
   */
  function get(Id classId, Id objectId) internal view returns (ClassObjectMapData memory _table) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    (bytes memory _staticData, EncodedLengths _encodedLengths, bytes memory _dynamicData) = StoreSwitch.getRecord(
      _tableId,
      _keyTuple,
      _fieldLayout
    );
    return decode(_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Get the full data.
   */
  function _get(Id classId, Id objectId) internal view returns (ClassObjectMapData memory _table) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    (bytes memory _staticData, EncodedLengths _encodedLengths, bytes memory _dynamicData) = StoreCore.getRecord(
      _tableId,
      _keyTuple,
      _fieldLayout
    );
    return decode(_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using individual values.
   */
  function set(Id classId, Id objectId, bool instanceOf, uint256 objectIndex) internal {
    bytes memory _staticData = encodeStatic(instanceOf, objectIndex);

    EncodedLengths _encodedLengths;
    bytes memory _dynamicData;

    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreSwitch.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using individual values.
   */
  function _set(Id classId, Id objectId, bool instanceOf, uint256 objectIndex) internal {
    bytes memory _staticData = encodeStatic(instanceOf, objectIndex);

    EncodedLengths _encodedLengths;
    bytes memory _dynamicData;

    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreCore.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData, _fieldLayout);
  }

  /**
   * @notice Set the full data using the data struct.
   */
  function set(Id classId, Id objectId, ClassObjectMapData memory _table) internal {
    bytes memory _staticData = encodeStatic(_table.instanceOf, _table.objectIndex);

    EncodedLengths _encodedLengths;
    bytes memory _dynamicData;

    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreSwitch.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using the data struct.
   */
  function _set(Id classId, Id objectId, ClassObjectMapData memory _table) internal {
    bytes memory _staticData = encodeStatic(_table.instanceOf, _table.objectIndex);

    EncodedLengths _encodedLengths;
    bytes memory _dynamicData;

    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreCore.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData, _fieldLayout);
  }

  /**
   * @notice Decode the tightly packed blob of static data using this table's field layout.
   */
  function decodeStatic(bytes memory _blob) internal pure returns (bool instanceOf, uint256 objectIndex) {
    instanceOf = (_toBool(uint8(Bytes.getBytes1(_blob, 0))));

    objectIndex = (uint256(Bytes.getBytes32(_blob, 1)));
  }

  /**
   * @notice Decode the tightly packed blobs using this table's field layout.
   * @param _staticData Tightly packed static fields.
   *
   *
   */
  function decode(
    bytes memory _staticData,
    EncodedLengths,
    bytes memory
  ) internal pure returns (ClassObjectMapData memory _table) {
    (_table.instanceOf, _table.objectIndex) = decodeStatic(_staticData);
  }

  /**
   * @notice Delete all data for given keys.
   */
  function deleteRecord(Id classId, Id objectId) internal {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreSwitch.deleteRecord(_tableId, _keyTuple);
  }

  /**
   * @notice Delete all data for given keys.
   */
  function _deleteRecord(Id classId, Id objectId) internal {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    StoreCore.deleteRecord(_tableId, _keyTuple, _fieldLayout);
  }

  /**
   * @notice Tightly pack static (fixed length) data using this table's schema.
   * @return The static data, encoded into a sequence of bytes.
   */
  function encodeStatic(bool instanceOf, uint256 objectIndex) internal pure returns (bytes memory) {
    return abi.encodePacked(instanceOf, objectIndex);
  }

  /**
   * @notice Encode all of a record's fields.
   * @return The static (fixed length) data, encoded into a sequence of bytes.
   * @return The lengths of the dynamic fields (packed into a single bytes32 value).
   * @return The dynamic (variable length) data, encoded into a sequence of bytes.
   */
  function encode(
    bool instanceOf,
    uint256 objectIndex
  ) internal pure returns (bytes memory, EncodedLengths, bytes memory) {
    bytes memory _staticData = encodeStatic(instanceOf, objectIndex);

    EncodedLengths _encodedLengths;
    bytes memory _dynamicData;

    return (_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Encode keys as a bytes32 array using this table's field layout.
   */
  function encodeKeyTuple(Id classId, Id objectId) internal pure returns (bytes32[] memory) {
    bytes32[] memory _keyTuple = new bytes32[](2);
    _keyTuple[0] = Id.unwrap(classId);
    _keyTuple[1] = Id.unwrap(objectId);

    return _keyTuple;
  }
}

/**
 * @notice Cast a value to a bool.
 * @dev Boolean values are encoded as uint8 (1 = true, 0 = false), but Solidity doesn't allow casting between uint8 and bool.
 * @param value The uint8 value to convert.
 * @return result The boolean value.
 */
function _toBool(uint8 value) pure returns (bool result) {
  assembly {
    result := value
  }
}
