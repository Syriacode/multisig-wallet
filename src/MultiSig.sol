// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MultiSig {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvals;
    }

    uint256 public constant THRESHOLD = 2;

    address[3] public owners;
    mapping(address => bool) public isOwner;
    Transaction[] private transactions;
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    event Deposited(address indexed sender, uint256 amount);
    event Submitted(uint256 indexed txId, address indexed owner, address indexed to, uint256 value);
    event Approved(uint256 indexed txId, address indexed owner);
    event Revoked(uint256 indexed txId, address indexed owner);
    event Executed(uint256 indexed txId);

    error NotImplemented();
    error NotOwner();
    error ZeroAddress();
    error DuplicateOwner(address owner);
    error TxNotFound(uint256 txId);
    error AlreadyExecuted(uint256 txId);
    error AlreadyApproved(uint256 txId);
    error NotApproved(uint256 txId);
    error NotEnoughApprovals(uint256 have, uint256 need);
    error ExecutionFailed();

    constructor(address[3] memory initialOwners) {}

    receive() external payable {}

    function submit(address to, uint256 value, bytes calldata data) external returns (uint256 txId) {
        revert NotImplemented();
    }

    function approve(uint256 txId) external {
        revert NotImplemented();
    }

    function revoke(uint256 txId) external {
        revert NotImplemented();
    }

    function execute(uint256 txId) external {
        revert NotImplemented();
    }

    function approvalCount(uint256 txId) public view returns (uint256) {
        revert NotImplemented();
    }

    function getTransaction(uint256 txId) external view returns (Transaction memory) {
        revert NotImplemented();
    }

    function transactionCount() external view returns (uint256) {
        revert NotImplemented();
    }
}
