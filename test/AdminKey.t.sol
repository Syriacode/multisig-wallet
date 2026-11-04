// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";
import {FeeController} from "../src/FeeController.sol";

contract AdminKeyTest is Test {
    MultiSig internal multisig;
    FeeController internal controller;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        multisig = new MultiSig([alice, bob, carol]);
        controller = new FeeController(address(multisig));
    }

    function _submitSetFee(address submitter) internal returns (uint256 txId) {
        vm.prank(submitter);
        txId = multisig.submit(address(controller), 0, abi.encodeCall(FeeController.setFee, (500)));
    }

    function test_OwnerKeyCannotCallControllerDirectly() public {
        vm.prank(carol);
        vm.expectRevert(FeeController.NotAdmin.selector);
        controller.setFee(500);
    }

    function test_OneStolenKeyCannotChangeFee() public {
        uint256 txId = _submitSetFee(carol);
        vm.prank(carol);
        multisig.approve(txId);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.NotEnoughApprovals.selector, 1, 2));
        multisig.execute(txId);

        assertEq(controller.feeBps(), 0);
    }

    function test_TwoOwnersChangeFee() public {
        uint256 txId = _submitSetFee(alice);
        vm.prank(alice);
        multisig.approve(txId);
        vm.prank(bob);
        multisig.approve(txId);

        vm.prank(bob);
        multisig.execute(txId);

        assertEq(controller.feeBps(), 500);
    }

    function testFuzz_AnyTwoOwnersCanExecute(uint256 first, uint256 offset) public {
        address[3] memory owners = [alice, bob, carol];
        first = bound(first, 0, 2);
        offset = bound(offset, 1, 2);
        address ownerA = owners[first];
        address ownerB = owners[(first + offset) % 3];

        uint256 txId = _submitSetFee(ownerA);
        vm.prank(ownerA);
        multisig.approve(txId);
        vm.prank(ownerB);
        multisig.approve(txId);

        vm.prank(ownerB);
        multisig.execute(txId);

        assertEq(controller.feeBps(), 500);
    }
}
