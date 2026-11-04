// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";

/// An owner contract that tries to re-enter execute() when it receives ETH.
contract ReentrantOwner {
    MultiSig public multisig;
    uint256 public txId;

    function setMultisig(MultiSig multisig_) external {
        multisig = multisig_;
    }

    function approveAndExecute(uint256 txId_) external {
        txId = txId_;
        multisig.approve(txId_);
        multisig.execute(txId_);
    }

    receive() external payable {
        if (address(multisig).balance >= 1 ether) {
            try multisig.execute(txId) {} catch {}
        }
    }
}

contract ReentrancyTest is Test {
    MultiSig internal multisig;
    ReentrantOwner internal attacker;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        attacker = new ReentrantOwner();
        multisig = new MultiSig([address(attacker), alice, bob]);
        attacker.setMultisig(multisig);
        vm.deal(address(multisig), 5 ether);
    }

    function test_ReentrantExecutePaysOnce() public {
        vm.prank(alice);
        uint256 txId = multisig.submit(address(attacker), 1 ether, "");
        vm.prank(alice);
        multisig.approve(txId);

        attacker.approveAndExecute(txId);

        assertEq(address(attacker).balance, 1 ether, "attacker was paid more than once");
        assertEq(address(multisig).balance, 4 ether, "wallet was drained");
    }
}
