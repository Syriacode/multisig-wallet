# multisig-wallet

This repo is multisig-wallet: A 2-of-3 multisig wallet in Solidity where any transaction needs approval from two of three owners, built test-first with Foundry.

Language: solidity

## How to work with me
- Test-driven development:
Tests are written first and describe the behavior we want.
When implementing, never edit, delete, or skip a test to make it pass. If a test looks wrong, stop and tell me why.
Write the smallest code that makes the tests pass. Don't add features no test asks for.
- I'm learning, so explain each change and the reasoning behind it.
- Always run the tests after changing code, and show me the output:

```bash
forge build
forge test -vv
forge fmt --check
```

## Plan

- `GUIDE.md` holds the step-by-step plan once it's added.

## Environment

- My machine runs Windows with Git Bash. Shell commands are POSIX bash.
