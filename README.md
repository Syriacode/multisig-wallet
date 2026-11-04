# multisig-wallet

A 2-of-3 multisig wallet in Solidity where any transaction needs approval from two of three owners, built test-first with Foundry.

Part of my [learning roadmap](https://github.com/Syriacode/Mini-Blockchain/blob/main/ROADMAP.md).

| | |
|---|---|
| Language | solidity |
| Claude Code technique practiced | **test-driven**: failing tests first |

## Run it

```bash
forge build
forge test -vv
forge fmt --check
```

## Design decisions

- **Approvals are counted over current owners, not stored.** `approvalCount` loops over the three current owners and checks `hasApproved`. An earlier version cached a counter on each transaction, and rotating an owner out didn't subtract their approval. A stolen key's approval could then combine with one honest mistake to pass the threshold. Deriving the count leaves one source of truth, with no second copy to forget to update.
- **`execute` follows checks-effects-interactions.** It checks the approvals, then sets `executed = true`, and only then makes the external call. If the recipient calls back into `execute` during the payment, it hits `AlreadyExecuted`. Moving that one line after the call lets a malicious owner contract drain the whole wallet, and `test_ReentrantExecutePaysOnce` catches it.
- **A failed call leaves the transaction retryable.** If the call fails, `execute` reverts with `ExecutionFailed`, which also undoes `executed = true`. A temporary problem, such as not enough ETH yet, doesn't block an approved transaction forever.
- **`replaceOwner` only accepts calls from the wallet itself.** It reverts with `NotSelf` unless `msg.sender == address(this)`, so the only way to change owners is a normal transaction approved by 2 of 3 owners. Changing the owner list is held to the same rule as moving funds.
- **The multisig is `FeeController`'s admin.** The fee can be changed only by the multisig, never directly by an owner's key. A single stolen key can submit and approve, but it can't reach the threshold alone, so holding a key no longer means holding the power to change the fee.

## Known limitations

- **Owners and threshold are fixed at 2-of-3.** `owners` is an `address[3]` and `THRESHOLD` is a constant, so another configuration such as 3-of-5 means deploying a new wallet.
- **Approvals happen on-chain.** Every approval is its own transaction and costs gas. Safe collects approvals as off-chain signatures instead and checks them all in a single `execute`.
- **Transactions have no expiry or cancel.** A submitted or approved transaction stays pending forever and can be executed whenever it reaches the threshold.
- **Rotating an owner back in restores their old approvals.** `hasApproved` is never cleared, so if a removed owner is added again, their earlier approvals count again.
- **There's no delay before execution.** A transaction runs as soon as it has 2 approvals, so there's no window to notice and react. Thursday's timelock project addresses this.
- **Two colluding or compromised owners can do anything.** The wallet protects against one bad key, not two. Those two can move all funds and replace the third owner.

## How I used Claude Code

### What I delegated

### What I reviewed

### A bug I caught

### Something I changed by hand

### What I'd do differently
