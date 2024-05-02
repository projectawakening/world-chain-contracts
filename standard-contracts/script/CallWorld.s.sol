// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ECDSA } from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "openzeppelin-contracts/utils/Nonces.sol";
import { ERC2771Forwarder } from "../src/metatx/ERC2771ForwarderWithHashNonce.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "./types.sol";

struct EntityRecordOffchainTableData {
  string name;
  string dappURL;
  string description;
}

struct EntityRecordTableData {
  uint256 itemId;
  uint256 typeId;
  uint256 volume;
}

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

    uint256 characterId = 12513;
    // The address this character will be minted to
    address characterAddress = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    uint256 typeId = 123;
    uint256 itemId = 234;
    uint256 volume = 100;
    string memory cid = "azerty";
    string memory characterName = "awesome-o";
    bytes memory data = abi.encodeWithSelector(
      0x571478ca,
      characterId,
      characterAddress,
      EntityRecordTableData({ typeId: typeId, itemId: itemId, volume: volume }),
      EntityRecordOffchainTableData({ name: characterName, dappURL: "noURL", description: "." }),
      cid
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
    bytes32 digest = _erc2771Forwarder.structHash(req);

    // Sign the request
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivatekey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    ERC2771Forwarder.ForwardRequestData memory requestData = ERC2771Forwarder.ForwardRequestData({
      from: req.from,
      to: req.to,
      value: req.value,
      gas: req.gas,
      nonce: req.nonce,
      deadline: req.deadline,
      data: req.data,
      signature: signature
    });

    bool verified = _erc2771Forwarder.verify(requestData);
    console.log(verified);

    _erc2771Forwarder.execute(requestData);
    vm.stopBroadcast();
  }
}
