// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract RotationTest is Test {
    MultiSig internal multisig;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal mallory = makeAddr("mallory");

    function setUp() public {
        multisig = new MultiSig([alice, bob, carol]);
        vm.deal(address(multisig), 5 ether);
    }

    function _rotate(address oldOwner, address newOwner) internal {
        vm.prank(alice);
        uint256 txId =
            multisig.submit(address(multisig), 0, abi.encodeCall(MultiSig.replaceOwner, (oldOwner, newOwner)));
        vm.prank(alice);
        multisig.approve(txId);
        vm.prank(bob);
        multisig.approve(txId);
        vm.prank(alice);
        multisig.execute(txId);
    }

    function test_TwoOwnersRotateAKey() public {
        vm.prank(alice);
        uint256 txId = multisig.submit(address(multisig), 0, abi.encodeCall(MultiSig.replaceOwner, (carol, dave)));
        vm.prank(alice);
        multisig.approve(txId);
        vm.prank(bob);
        multisig.approve(txId);

        vm.prank(alice);
        vm.expectEmit(address(multisig));
        emit MultiSig.OwnerReplaced(carol, dave);
        multisig.execute(txId);

        assertFalse(multisig.isOwner(carol));
        assertTrue(multisig.isOwner(dave));
        assertEq(multisig.owners(2), dave);
    }

    function test_RevertWhen_OwnerCallsReplaceDirectly() public {
        vm.prank(alice);
        vm.expectRevert(MultiSig.NotSelf.selector);
        multisig.replaceOwner(carol, dave);
    }

    function test_RevertWhen_NewOwnerIsAlreadyAnOwner() public {
        vm.prank(address(multisig));
        vm.expectRevert(abi.encodeWithSelector(MultiSig.DuplicateOwner.selector, bob));
        multisig.replaceOwner(carol, bob);
    }

    function test_RemovedOwnerLosesAccess() public {
        _rotate(carol, dave);
        vm.prank(alice);
        uint256 txId = multisig.submit(mallory, 1 ether, "");

        vm.prank(carol);
        vm.expectRevert(MultiSig.NotOwner.selector);
        multisig.approve(txId);

        vm.prank(dave);
        multisig.approve(txId);

        assertEq(multisig.approvalCount(txId), 1);
    }

    function test_StaleApprovalDoesNotCount() public {
        // Mallory stole Carol's key and approved a drain.
        vm.prank(carol);
        uint256 drainId = multisig.submit(mallory, 5 ether, "");
        vm.prank(carol);
        multisig.approve(drainId);

        // Alice and Bob rotate Carol out.
        _rotate(carol, dave);

        // Alice approves the old transaction by mistake. Only one current owner has approved it.
        vm.prank(alice);
        multisig.approve(drainId);

        assertEq(multisig.approvalCount(drainId), 1, "removed owner's approval still counts");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.NotEnoughApprovals.selector, 1, 2));
        multisig.execute(drainId);

        assertEq(mallory.balance, 0, "drain went through");
    }
}
