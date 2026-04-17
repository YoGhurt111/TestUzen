# Opcode Live Verifier

TL;DR:
This project deploys raw EVM probe contracts and verifies through real transactions whether `TLOAD`, `TSTORE`, `MCOPY`, and `CLZ` actually execute on a target node. It also includes a `zk_gas_spec` scenario suite in a "deploy contract + trigger via tx" form.

## Contents

- `src/OpcodeProbes.sol`: probe runtimes, deployer, and verifier
- `src/ZkGasTxCases.sol`: on-chain trigger case contract for `zk_gas_spec`
- `test/OpcodeVerifier.t.sol`: local regression tests
- `test/ZkGasTxCases.t.sol`: local regression tests for the on-chain trigger cases
- `script/VerifyOpcodes.s.sol`: broadcast script for real RPC validation
- `script/RunZkGasTxCases.s.sol`: zk gas trigger script for real RPC validation

## Local Tests

```bash
forge test --offline -vv
```

The local `evm_version` is `cancun`:
- `TLOAD/TSTORE` and `MCOPY` are expected to succeed
- `CLZ` belongs to a later fork and is expected to fail locally by default, which helps verify that the script can correctly identify "unsupported"

`--offline` is used to avoid a Foundry crash in this environment when it attempts online signature decoding. This does not affect the project’s local tests themselves.

To run only the zk gas trigger case tests:

```bash
forge test --offline --match-path test/ZkGasTxCases.t.sol -vv
```

## Real Node Validation

Prepare:

```bash
export RPC_URL=https://your-node
export PRIVATE_KEY=0x...
```

Then run:

```bash
forge script script/VerifyOpcodes.s.sol:VerifyOpcodesScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

To execute the `zk_gas_spec` "deploy contract + tx trigger" cases:

```bash
forge script script/RunZkGasTxCases.s.sol:RunZkGasTxCasesScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

The opcode verification script sends real transactions in this order:

1. Deploy `OpcodeDeployer`
2. Deploy `OpcodeVerifier`
3. Deploy the `TLOAD/TSTORE`, `MCOPY`, and `CLZ` probes
4. Send real invocation transactions through `OpcodeVerifier`

Each verification emits:

`ProbeResult(string opcode, address probe, bool success, bytes raw)`

Interpretation:

- `TLOAD_TSTORE`: `success = true` and decoded `raw` equals the written value means supported
- `MCOPY`: `success = true` and `raw` equals the input byte string means supported
- `CLZ`: `success = true` and returns the leading-zero count means supported; `success = false` means the current node has not enabled that opcode

## Reading Results

You can inspect the transaction hash from the script output, then run:

```bash
cast receipt <TX_HASH> --rpc-url "$RPC_URL"
```

Or inspect the `ProbeResult` event in a block explorer.

## ZK Gas Tx Cases

`RunZkGasTxCases.s.sol` deploys a `ZkGasTxHarness` and then sends real transactions to trigger these scenarios one by one:

1. `TLOAD/TSTORE`
2. `MCOPY`
3. `CALL`
4. `STATICCALL`
5. `DELEGATECALL`
6. `CALLCODE`
7. `identity` precompile
8. `modexp` precompile
9. `CREATE`
10. `CREATE2`

Each entrypoint emits:

```solidity
event CaseExecuted(string caseId, bool success, bytes data, address related);
```

Where:
- `caseId` is the scenario name
- `data` is the ABI-encoded result
- `related` is the target address or the newly created child contract address

This script does not depend on a fixed network name. It only depends on configuration values:

```bash
export RPC_URL=https://your-endpoint
export PRIVATE_KEY=0x...
```
