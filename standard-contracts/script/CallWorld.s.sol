// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ECDSA } from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "openzeppelin-contracts/utils/Nonces.sol";
import { ERC2771Forwarder } from "../src/metatx/ERC2771ForwarderWithHashNonce.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "./types.sol";

contract CallWorld is Script {
  ERC2771Forwarder internal _erc2771Forwarder;
  uint256 _signerPrivatekey;
  address internal _signer;

  function setUp() public {
    _erc2771Forwarder = ERC2771Forwarder(vm.envOr("FORWARDER_ADDRESS", address(0x0)));
  }

  function run(address worldAddress) public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    _signerPrivatekey = 0xA11CE;
    _signer = vm.addr(_signerPrivatekey);

    uint256 nonce = uint256(keccak256(abi.encodePacked("a")));
    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
    uint256 storageCapacity = 100000000;
    uint256 ephemeralStorageCapacity = 100000000000;
    EntityRecordData memory entityRecordData = EntityRecordData({ typeId: 7888, itemId: 111, volume: 10 });
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: _signer, tokenURI: "test" });
    WorldPosition memory worldPosition = WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) });

    bytes memory data = abi.encodeWithSelector(
      0x9da298e5,
      smartObjectId,
      entityRecordData,
      smartObjectData,
      worldPosition,
      storageCapacity,
      ephemeralStorageCapacity
    );

    ERC2771Forwarder.ForwardRequest memory req = ERC2771Forwarder.ForwardRequest({
      from: _signer,
      to: worldAddress,
      value: 0,
      gas: 200000,
      nonce: nonce,
      deadline: uint48(block.timestamp + 1000),
      data: data
    });

    //Make this EIP712 complaint
    // bytes32 digest = _erc2771Forwarder.structHash(req);

    //Sign the request
    // (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivatekey, digest);
    // bytes memory signature = abi.encodePacked(r, s, v);

    // ERC2771Forwarder.ForwardRequestData memory requestData = ERC2771Forwarder.ForwardRequestData({
    //   from: req.from,
    //   to: req.to,
    //   value: req.value,
    //   gas: req.gas,
    //   nonce: req.nonce,
    //   deadline: req.deadline,
    //   data: req.data,
    //   signature: signature
    // });

    // bool verified = _erc2771Forwarder.verify(requestData);
    // console.log(verified);

    // _erc2771Forwarder.execute(requestData);
    vm.stopBroadcast();
  }
}
