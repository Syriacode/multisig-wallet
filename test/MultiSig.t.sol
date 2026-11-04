// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract MultiSigTest is Test {
    MultiSig internal multisig;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal mallory = makeAddr("mallory");
    address internal payee = makeAddr("payee");

    function setUp() public {
        multisig = new MultiSig([alice, bob, carol]);
        vm.deal(address(multisig), 5 ether);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _submit() internal returns (uint256 txId) {
        vm.prank(alice);
        txId = multisig.submit(payee, 1 ether, "");
    }

    function _approveBy(uint256 txId, address owner) internal {
        vm.prank(owner);
        multisig.approve(txId);
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    function test_ConstructorSetsOwners() public view {
        assertEq(multisig.owners(0), alice);
        assertEq(multisig.owners(1), bob);
        assertEq(multisig.owners(2), carol);
        assertTrue(multisig.isOwner(alice));
        assertFalse(multisig.isOwner(mallory));
    }

    function test_RevertWhen_OwnerIsZeroAddress() public {
        vm.expectRevert(MultiSig.ZeroAddress.selector);
        new MultiSig([alice, address(0), carol]);
    }

    function test_RevertWhen_OwnersAreDuplicated() public {
        vm.expectRevert(abi.encodeWithSelector(MultiSig.DuplicateOwner.selector, alice));
        new MultiSig([alice, bob, alice]);
    }

    // ---------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------

    function test_ReceiveAcceptsEth() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        vm.expectEmit(address(multisig));
        emit MultiSig.Deposited(alice, 1 ether);
        (bool ok,) = address(multisig).call{value: 1 ether}("");

        assertTrue(ok);
        assertEq(address(multisig).balance, 6 ether);
    }

    // ---------------------------------------------------------------
    // Submit
    // ---------------------------------------------------------------

    function test_SubmitStoresTransaction() public {
        vm.prank(alice);
        vm.expectEmit(address(multisig));
        emit MultiSig.Submitted(0, alice, payee, 1 ether);
        uint256 txId = multisig.submit(payee, 1 ether, "");

        assertEq(txId, 0);
        assertEq(multisig.transactionCount(), 1);

        MultiSig.Transaction memory t = multisig.getTransaction(txId);
        assertEq(t.to, payee);
        assertEq(t.value, 1 ether);
        assertFalse(t.executed);
        assertEq(multisig.approvalCount(txId), 0);
    }

    function test_RevertWhen_NonOwnerSubmits() public {
        vm.prank(mallory);
        vm.expectRevert(MultiSig.NotOwner.selector);
        multisig.submit(payee, 1 ether, "");
    }

    // ---------------------------------------------------------------
    // Approve
    // ---------------------------------------------------------------

    function test_ApproveCountsOwner() public {
        uint256 txId = _submit();

        vm.prank(bob);
        vm.expectEmit(address(multisig));
        emit MultiSig.Approved(txId, bob);
        multisig.approve(txId);

        assertTrue(multisig.hasApproved(txId, bob));
        assertEq(multisig.approvalCount(txId), 1);
    }

    function test_RevertWhen_ApprovingTwice() public {
        uint256 txId = _submit();
        _approveBy(txId, bob);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.AlreadyApproved.selector, txId));
        multisig.approve(txId);
    }

    function test_RevertWhen_ApprovingMissingTx() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.TxNotFound.selector, 99));
        multisig.approve(99);
    }

    // ---------------------------------------------------------------
    // Revoke
    // ---------------------------------------------------------------

    function test_RevokeRemovesApproval() public {
        uint256 txId = _submit();
        _approveBy(txId, bob);

        vm.prank(bob);
        vm.expectEmit(address(multisig));
        emit MultiSig.Revoked(txId, bob);
        multisig.revoke(txId);

        assertFalse(multisig.hasApproved(txId, bob));
        assertEq(multisig.approvalCount(txId), 0);
    }

    function test_RevertWhen_RevokingWithoutApproval() public {
        uint256 txId = _submit();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.NotApproved.selector, txId));
        multisig.revoke(txId);
    }

    // ---------------------------------------------------------------
    // Execute
    // ---------------------------------------------------------------

    function test_ExecuteSendsEthWithTwoApprovals() public {
        uint256 txId = _submit();
        _approveBy(txId, alice);
        _approveBy(txId, bob);

        vm.prank(carol);
        vm.expectEmit(address(multisig));
        emit MultiSig.Executed(txId);
        multisig.execute(txId);

        assertEq(payee.balance, 1 ether);
        assertEq(address(multisig).balance, 4 ether);
        assertTrue(multisig.getTransaction(txId).executed);
    }

    function test_RevertWhen_ExecutingWithOneApproval() public {
        uint256 txId = _submit();
        _approveBy(txId, alice);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.NotEnoughApprovals.selector, 1, 2));
        multisig.execute(txId);
    }

    function test_RevertWhen_ExecutingTwice() public {
        uint256 txId = _submit();
        _approveBy(txId, alice);
        _approveBy(txId, bob);
        vm.prank(carol);
        multisig.execute(txId);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.AlreadyExecuted.selector, txId));
        multisig.execute(txId);

        assertEq(payee.balance, 1 ether);
    }

    function test_RevertWhen_ApprovingExecutedTx() public {
        uint256 txId = _submit();
        _approveBy(txId, alice);
        _approveBy(txId, bob);
        vm.prank(alice);
        multisig.execute(txId);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(MultiSig.AlreadyExecuted.selector, txId));
        multisig.approve(txId);
    }

    function test_FailedCallCanBeRetried() public {
        vm.prank(alice);
        uint256 txId = multisig.submit(payee, 10 ether, "");
        _approveBy(txId, alice);
        _approveBy(txId, bob);

        vm.prank(carol);
        vm.expectRevert(MultiSig.ExecutionFailed.selector);
        multisig.execute(txId);

        assertFalse(multisig.getTransaction(txId).executed);

        vm.deal(address(multisig), 10 ether);
        vm.prank(carol);
        multisig.execute(txId);

        assertEq(payee.balance, 10 ether);
    }
}
