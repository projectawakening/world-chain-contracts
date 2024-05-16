// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

// Import schema type
import { SchemaType } from "@latticexyz/schema-type/src/solidity/SchemaType.sol";

// Import store internals
import { IStore } from "@latticexyz/store/src/IStore.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { StoreCore } from "@latticexyz/store/src/StoreCore.sol";
import { Bytes } from "@latticexyz/store/src/Bytes.sol";
import { Memory } from "@latticexyz/store/src/Memory.sol";
import { SliceLib } from "@latticexyz/store/src/Slice.sol";
import { EncodeArray } from "@latticexyz/store/src/tightcoder/EncodeArray.sol";
import { FieldLayout, FieldLayoutLib } from "@latticexyz/store/src/FieldLayout.sol";
import { Schema, SchemaLib } from "@latticexyz/store/src/Schema.sol";
import { PackedCounter, PackedCounterLib } from "@latticexyz/store/src/PackedCounter.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

FieldLayout constant _fieldLayout = FieldLayout.wrap(
  0x0040020120200000000000000000000000000000000000000000000000000000
);

struct InventoryTableData {
  uint256 capacity;
  uint256 usedCapacity;
  uint256[] items;
}

library InventoryTable {
  /**
   * @notice Get the table values' field layout.
   * @return _fieldLayout The field layout for the table.
   */
  function getFieldLayout() internal pure returns (FieldLayout) {
    return _fieldLayout;
  }

  /**
   * @notice Get the table's key schema.
   * @return _keySchema The key schema for the table.
   */
  function getKeySchema() internal pure returns (Schema) {
    SchemaType[] memory _keySchema = new SchemaType[](1);
    _keySchema[0] = SchemaType.UINT256;

    return SchemaLib.encode(_keySchema);
  }

  /**
   * @notice Get the table's value schema.
   * @return _valueSchema The value schema for the table.
   */
  function getValueSchema() internal pure returns (Schema) {
    SchemaType[] memory _valueSchema = new SchemaType[](3);
    _valueSchema[0] = SchemaType.UINT256;
    _valueSchema[1] = SchemaType.UINT256;
    _valueSchema[2] = SchemaType.UINT256_ARRAY;

    return SchemaLib.encode(_valueSchema);
  }

  /**
   * @notice Get the table's key field names.
   * @return keyNames An array of strings with the names of key fields.
   */
  function getKeyNames() internal pure returns (string[] memory keyNames) {
    keyNames = new string[](1);
    keyNames[0] = "smartObjectId";
  }

  /**
   * @notice Get the table's value field names.
   * @return fieldNames An array of strings with the names of value fields.
   */
  function getFieldNames() internal pure returns (string[] memory fieldNames) {
    fieldNames = new string[](3);
    fieldNames[0] = "capacity";
    fieldNames[1] = "usedCapacity";
    fieldNames[2] = "items";
  }

  /**
   * @notice Register the table with its config.
   */
  function register(ResourceId _tableId) internal {
    StoreSwitch.registerTable(_tableId, _fieldLayout, getKeySchema(), getValueSchema(), getKeyNames(), getFieldNames());
  }

  /**
   * @notice Register the table with its config.
   */
  function _register(ResourceId _tableId) internal {
    StoreCore.registerTable(_tableId, _fieldLayout, getKeySchema(), getValueSchema(), getKeyNames(), getFieldNames());
  }

  /**
   * @notice Get capacity.
   */
  function getCapacity(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256 capacity) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    bytes32 _blob = StoreSwitch.getStaticField(_tableId, _keyTuple, 0, _fieldLayout);
    return (uint256(bytes32(_blob)));
  }

  /**
   * @notice Get capacity.
   */
  function _getCapacity(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256 capacity) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    bytes32 _blob = StoreCore.getStaticField(_tableId, _keyTuple, 0, _fieldLayout);
    return (uint256(bytes32(_blob)));
  }

  /**
   * @notice Set capacity.
   */
  function setCapacity(ResourceId _tableId, uint256 smartObjectId, uint256 capacity) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.setStaticField(_tableId, _keyTuple, 0, abi.encodePacked((capacity)), _fieldLayout);
  }

  /**
   * @notice Set capacity.
   */
  function _setCapacity(ResourceId _tableId, uint256 smartObjectId, uint256 capacity) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.setStaticField(_tableId, _keyTuple, 0, abi.encodePacked((capacity)), _fieldLayout);
  }

  /**
   * @notice Get usedCapacity.
   */
  function getUsedCapacity(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256 usedCapacity) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    bytes32 _blob = StoreSwitch.getStaticField(_tableId, _keyTuple, 1, _fieldLayout);
    return (uint256(bytes32(_blob)));
  }

  /**
   * @notice Get usedCapacity.
   */
  function _getUsedCapacity(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256 usedCapacity) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    bytes32 _blob = StoreCore.getStaticField(_tableId, _keyTuple, 1, _fieldLayout);
    return (uint256(bytes32(_blob)));
  }

  /**
   * @notice Set usedCapacity.
   */
  function setUsedCapacity(ResourceId _tableId, uint256 smartObjectId, uint256 usedCapacity) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.setStaticField(_tableId, _keyTuple, 1, abi.encodePacked((usedCapacity)), _fieldLayout);
  }

  /**
   * @notice Set usedCapacity.
   */
  function _setUsedCapacity(ResourceId _tableId, uint256 smartObjectId, uint256 usedCapacity) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.setStaticField(_tableId, _keyTuple, 1, abi.encodePacked((usedCapacity)), _fieldLayout);
  }

  /**
   * @notice Get items.
   */
  function getItems(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256[] memory items) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    bytes memory _blob = StoreSwitch.getDynamicField(_tableId, _keyTuple, 0);
    return (SliceLib.getSubslice(_blob, 0, _blob.length).decodeArray_uint256());
  }

  /**
   * @notice Get items.
   */
  function _getItems(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256[] memory items) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    bytes memory _blob = StoreCore.getDynamicField(_tableId, _keyTuple, 0);
    return (SliceLib.getSubslice(_blob, 0, _blob.length).decodeArray_uint256());
  }

  /**
   * @notice Set items.
   */
  function setItems(ResourceId _tableId, uint256 smartObjectId, uint256[] memory items) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.setDynamicField(_tableId, _keyTuple, 0, EncodeArray.encode((items)));
  }

  /**
   * @notice Set items.
   */
  function _setItems(ResourceId _tableId, uint256 smartObjectId, uint256[] memory items) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.setDynamicField(_tableId, _keyTuple, 0, EncodeArray.encode((items)));
  }

  /**
   * @notice Get the length of items.
   */
  function lengthItems(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    uint256 _byteLength = StoreSwitch.getDynamicFieldLength(_tableId, _keyTuple, 0);
    unchecked {
      return _byteLength / 32;
    }
  }

  /**
   * @notice Get the length of items.
   */
  function _lengthItems(ResourceId _tableId, uint256 smartObjectId) internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    uint256 _byteLength = StoreCore.getDynamicFieldLength(_tableId, _keyTuple, 0);
    unchecked {
      return _byteLength / 32;
    }
  }

  /**
   * @notice Get an item of items.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function getItemItems(ResourceId _tableId, uint256 smartObjectId, uint256 _index) internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    unchecked {
      bytes memory _blob = StoreSwitch.getDynamicFieldSlice(_tableId, _keyTuple, 0, _index * 32, (_index + 1) * 32);
      return (uint256(bytes32(_blob)));
    }
  }

  /**
   * @notice Get an item of items.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function _getItemItems(ResourceId _tableId, uint256 smartObjectId, uint256 _index) internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    unchecked {
      bytes memory _blob = StoreCore.getDynamicFieldSlice(_tableId, _keyTuple, 0, _index * 32, (_index + 1) * 32);
      return (uint256(bytes32(_blob)));
    }
  }

  /**
   * @notice Push an element to items.
   */
  function pushItems(ResourceId _tableId, uint256 smartObjectId, uint256 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.pushToDynamicField(_tableId, _keyTuple, 0, abi.encodePacked((_element)));
  }

  /**
   * @notice Push an element to items.
   */
  function _pushItems(ResourceId _tableId, uint256 smartObjectId, uint256 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.pushToDynamicField(_tableId, _keyTuple, 0, abi.encodePacked((_element)));
  }

  /**
   * @notice Pop an element from items.
   */
  function popItems(ResourceId _tableId, uint256 smartObjectId) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.popFromDynamicField(_tableId, _keyTuple, 0, 32);
  }

  /**
   * @notice Pop an element from items.
   */
  function _popItems(ResourceId _tableId, uint256 smartObjectId) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.popFromDynamicField(_tableId, _keyTuple, 0, 32);
  }

  /**
   * @notice Update an element of items at `_index`.
   */
  function updateItems(ResourceId _tableId, uint256 smartObjectId, uint256 _index, uint256 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    unchecked {
      bytes memory _encoded = abi.encodePacked((_element));
      StoreSwitch.spliceDynamicData(_tableId, _keyTuple, 0, uint40(_index * 32), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Update an element of items at `_index`.
   */
  function _updateItems(ResourceId _tableId, uint256 smartObjectId, uint256 _index, uint256 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    unchecked {
      bytes memory _encoded = abi.encodePacked((_element));
      StoreCore.spliceDynamicData(_tableId, _keyTuple, 0, uint40(_index * 32), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Get the full data.
   */
  function get(ResourceId _tableId, uint256 smartObjectId) internal view returns (InventoryTableData memory _table) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    (bytes memory _staticData, PackedCounter _encodedLengths, bytes memory _dynamicData) = StoreSwitch.getRecord(
      _tableId,
      _keyTuple,
      _fieldLayout
    );
    return decode(_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Get the full data.
   */
  function _get(ResourceId _tableId, uint256 smartObjectId) internal view returns (InventoryTableData memory _table) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    (bytes memory _staticData, PackedCounter _encodedLengths, bytes memory _dynamicData) = StoreCore.getRecord(
      _tableId,
      _keyTuple,
      _fieldLayout
    );
    return decode(_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using individual values.
   */
  function set(
    ResourceId _tableId,
    uint256 smartObjectId,
    uint256 capacity,
    uint256 usedCapacity,
    uint256[] memory items
  ) internal {
    bytes memory _staticData = encodeStatic(capacity, usedCapacity);

    PackedCounter _encodedLengths = encodeLengths(items);
    bytes memory _dynamicData = encodeDynamic(items);

    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using individual values.
   */
  function _set(
    ResourceId _tableId,
    uint256 smartObjectId,
    uint256 capacity,
    uint256 usedCapacity,
    uint256[] memory items
  ) internal {
    bytes memory _staticData = encodeStatic(capacity, usedCapacity);

    PackedCounter _encodedLengths = encodeLengths(items);
    bytes memory _dynamicData = encodeDynamic(items);

    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData, _fieldLayout);
  }

  /**
   * @notice Set the full data using the data struct.
   */
  function set(ResourceId _tableId, uint256 smartObjectId, InventoryTableData memory _table) internal {
    bytes memory _staticData = encodeStatic(_table.capacity, _table.usedCapacity);

    PackedCounter _encodedLengths = encodeLengths(_table.items);
    bytes memory _dynamicData = encodeDynamic(_table.items);

    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using the data struct.
   */
  function _set(ResourceId _tableId, uint256 smartObjectId, InventoryTableData memory _table) internal {
    bytes memory _staticData = encodeStatic(_table.capacity, _table.usedCapacity);

    PackedCounter _encodedLengths = encodeLengths(_table.items);
    bytes memory _dynamicData = encodeDynamic(_table.items);

    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData, _fieldLayout);
  }

  /**
   * @notice Decode the tightly packed blob of static data using this table's field layout.
   */
  function decodeStatic(bytes memory _blob) internal pure returns (uint256 capacity, uint256 usedCapacity) {
    capacity = (uint256(Bytes.slice32(_blob, 0)));

    usedCapacity = (uint256(Bytes.slice32(_blob, 32)));
  }

  /**
   * @notice Decode the tightly packed blob of dynamic data using the encoded lengths.
   */
  function decodeDynamic(
    PackedCounter _encodedLengths,
    bytes memory _blob
  ) internal pure returns (uint256[] memory items) {
    uint256 _start;
    uint256 _end;
    unchecked {
      _end = _encodedLengths.atIndex(0);
    }
    items = (SliceLib.getSubslice(_blob, _start, _end).decodeArray_uint256());
  }

  /**
   * @notice Decode the tightly packed blobs using this table's field layout.
   * @param _staticData Tightly packed static fields.
   * @param _encodedLengths Encoded lengths of dynamic fields.
   * @param _dynamicData Tightly packed dynamic fields.
   */
  function decode(
    bytes memory _staticData,
    PackedCounter _encodedLengths,
    bytes memory _dynamicData
  ) internal pure returns (InventoryTableData memory _table) {
    (_table.capacity, _table.usedCapacity) = decodeStatic(_staticData);

    (_table.items) = decodeDynamic(_encodedLengths, _dynamicData);
  }

  /**
   * @notice Delete all data for given keys.
   */
  function deleteRecord(ResourceId _tableId, uint256 smartObjectId) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreSwitch.deleteRecord(_tableId, _keyTuple);
  }

  /**
   * @notice Delete all data for given keys.
   */
  function _deleteRecord(ResourceId _tableId, uint256 smartObjectId) internal {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    StoreCore.deleteRecord(_tableId, _keyTuple, _fieldLayout);
  }

  /**
   * @notice Tightly pack static (fixed length) data using this table's schema.
   * @return The static data, encoded into a sequence of bytes.
   */
  function encodeStatic(uint256 capacity, uint256 usedCapacity) internal pure returns (bytes memory) {
    return abi.encodePacked(capacity, usedCapacity);
  }

  /**
   * @notice Tightly pack dynamic data lengths using this table's schema.
   * @return _encodedLengths The lengths of the dynamic fields (packed into a single bytes32 value).
   */
  function encodeLengths(uint256[] memory items) internal pure returns (PackedCounter _encodedLengths) {
    // Lengths are effectively checked during copy by 2**40 bytes exceeding gas limits
    unchecked {
      _encodedLengths = PackedCounterLib.pack(items.length * 32);
    }
  }

  /**
   * @notice Tightly pack dynamic (variable length) data using this table's schema.
   * @return The dynamic data, encoded into a sequence of bytes.
   */
  function encodeDynamic(uint256[] memory items) internal pure returns (bytes memory) {
    return abi.encodePacked(EncodeArray.encode((items)));
  }

  /**
   * @notice Encode all of a record's fields.
   * @return The static (fixed length) data, encoded into a sequence of bytes.
   * @return The lengths of the dynamic fields (packed into a single bytes32 value).
   * @return The dynamic (variable length) data, encoded into a sequence of bytes.
   */
  function encode(
    uint256 capacity,
    uint256 usedCapacity,
    uint256[] memory items
  ) internal pure returns (bytes memory, PackedCounter, bytes memory) {
    bytes memory _staticData = encodeStatic(capacity, usedCapacity);

    PackedCounter _encodedLengths = encodeLengths(items);
    bytes memory _dynamicData = encodeDynamic(items);

    return (_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Encode keys as a bytes32 array using this table's field layout.
   */
  function encodeKeyTuple(uint256 smartObjectId) internal pure returns (bytes32[] memory) {
    bytes32[] memory _keyTuple = new bytes32[](1);
    _keyTuple[0] = bytes32(uint256(smartObjectId));

    return _keyTuple;
  }
}
