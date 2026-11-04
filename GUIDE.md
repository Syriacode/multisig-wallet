# GUIDE: building the 2-of-3 multisig, test-first

Each step follows the same loop:

1. **Red**: write a failing test in `test/MultiSig.t.sol` for one behaviour.
2. **Green**: write the smallest change to `src/MultiSig.sol` that makes it pass.
3. **Refactor**: tidy up, then run the full check:

```bash
forge build
forge test -vv
forge fmt --check
```

Commit after every green step.

## Step 0: Clean slate

- [x] Remove the sample `Counter` files that `forge init` created.
- [x] Add this guide.

## Step 1: Owners

- Constructor takes exactly 3 owner addresses.
- Reject the zero address and duplicate owners (revert with custom errors).
- Expose `isOwner(address)` and `getOwners()`.
- Threshold is fixed at 2 (a `constant`).

## Step 2: Receiving ETH

- The wallet accepts ETH through `receive()`.
- Emit a `Deposit(sender, amount, balance)` event.

## Step 3: Submitting a transaction

- `submitTransaction(to, value, data)`, owners only, returns a `txId`.
- Store `to`, `value`, `data`, `executed`, `numConfirmations`.
- Emit `SubmitTransaction`.
- Non-owners revert with `NotOwner`.

## Step 4: Confirming

- `confirmTransaction(txId)`, owners only.
- Revert on an unknown `txId`, an already-executed tx, or a second confirmation from the same owner.
- Track confirmations in `mapping(uint256 => mapping(address => bool))`.
- Emit `ConfirmTransaction`.

## Step 5: Revoking

- `revokeConfirmation(txId)` lets an owner withdraw a confirmation before execution.
- Revert if that owner hadn't confirmed.
- Emit `RevokeConfirmation`.

## Step 6: Executing

- `executeTransaction(txId)`, owners only.
- Require at least 2 confirmations and not already executed.
- Follow checks-effects-interactions: set `executed = true` **before** the external call.
- Make the call with `to.call{value: value}(data)` and revert if it fails.
- Emit `ExecuteTransaction`.

## Step 7: Attack and edge-case tests

- Re-entrancy: a malicious receiver that tries to call `executeTransaction` again.
- Executing with only 1 confirmation.
- Executing after a revoke drops the count below 2.
- Calling a contract (non-empty `data`), not just sending ETH.
- Fuzz test: random `value` amounts up to the wallet balance.

## Step 8: Deploy script

- `script/MultiSig.s.sol` deploys with 3 owners read from environment variables.
- Dry-run it against a local `anvil` node.

## Step 9: Write-up

- Fill in "Design decisions" and "Known limitations" in `README.md`.
- Answer the questions in `INTERVIEW.md`.
