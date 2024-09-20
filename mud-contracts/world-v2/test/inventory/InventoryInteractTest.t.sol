// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { EveSystem } from "../../../src/systems/EveSystem.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { World } from "@latticexyz/world/src/World.sol";

import { EphemeralInvCapacity } from "../../src/codegen/tables/EphemeralInvCapacity.sol";
import { EphemeralInventorySystem } from "../../src/systems/inventory/EphemeralInventorySystem.sol";
import { EphemeralInv, EphemeralInvData } from "../../src/codegen/tables/EphemeralInv.sol";
import { EphemeralInvItem, EphemeralInvItemData } from "../../src/codegen/tables/EphemeralInvItem.sol";
import { InventoryInteractSystem } from "../../src/systems/inventory/InventoryInteractSystem.sol";
import { DeployableTokenTable } from "../../src/codegen/index.sol";
import { IInventoryErrors } from "../../src/systems/inventory/IInventoryErrors.sol";
import { InventoryItem } from "../../src/systems/inventory/types.sol";
import { EntityRecordSystem } from "../../src/systems/entity-record/EntityRecordSystem.sol";
import { IERC721 } from "../../src/systems/eve-erc721-puppet/IERC721.sol";

import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { EntityRecordUtils } from "../../src/systems/entity-record/EntityRecordUtils.sol";
import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";

contract VendingMachineTestSystem is EveSystem {
  using InventoryUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;

  function interactHandler(uint256 smartObjectId, uint256 quantity) public {
    // NOTE: Store the IN and OUT item details in table by configuring in a seperate function.
    uint256 inItemId = uint256(keccak256(abi.encode("item:46")));
    uint256 outItemId = uint256(keccak256(abi.encode("item:45")));
    uint256 ratio = 1;
    address ephItemOwner = address(2);

    address inventoryOwner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);

    //Below Data should be stored in a table and fetched from there
    InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem(inItemId, ephItemOwner, 46, 2, 70, quantity * ratio);

    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem(outItemId, inventoryOwner, 45, 1, 50, quantity * ratio);

    ResourceId interactSystemId = InventoryUtils.inventoryInteractSystemId();
    world().call(
      interactSystemId,
      abi.encodeCall(InventoryInteractSystem.ephemeralToInventoryTransfer, (smartObjectId, inItems))
    );
    world().call(
      interactSystemId,
      abi.encodeCall(
        InventoryInteractSystem.inventoryToEphemeralTransferWithParam,
        (smartObjectId, ephItemOwner, outItems)
      )
    );
  }
}

// contract InventoryInteractTest is MudTest {
//   IBaseWorld world;
//   using InventoryUtils for bytes14;
//   using EntityRecordUtils for bytes14;
//   using SmartDeployableUtils for bytes14;

//   VendingMachineTestSystem private vendingMachineSystem = new VendingMachineTestSystem();

//   uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
//   uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
//   uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
//   uint256 storageCapacity = 100000;
//   uint256 ephemeralStorageCapacity = 100000;
//   address inventoryOwner = address(1);
//   address ephItemOwner = address(2);

//   function setUp() public virtual override {
//     super.setUp();
//     world = IBaseWorld(worldAddress);
//   }

//   function testWorldExists() public {
//     uint256 codeSize;
//     address addr = worldAddress;
//     assembly {
//       codeSize := extcodesize(addr)
//     }
//     assertTrue(codeSize > 0);
//   }

//   function testInteractHandler() public {}
// }
