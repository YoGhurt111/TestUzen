# Test Case Overview

TL;DR:
This document is the single index for all test cases and validation scenarios currently represented in the codebase. It covers local Foundry tests, real-node broadcast scripts, the executable Appendix B coverage set, and the `zk_gas_spec` vector cases.

## Code Sources

| Type | File | Description |
| --- | --- | --- |
| Raw opcode probes | `src/OpcodeProbes.sol` | Defines runtimes, deployers, and verifiers for `TLOAD/TSTORE`, `MCOPY`, `CLZ`, `BLOBHASH`, and `BLOBBASEFEE`. |
| zk gas transaction harness | `src/ZkGasTxCases.sol` | Defines transaction-triggered opcode, precompile, spawn, `CREATE`, and `CREATE2` scenarios. |
| Appendix B coverage contract | `src/AppendixBZkCases.sol` | Defines executable coverage for 17 precompiles and 149 opcodes. |
| Local tests | `test/*.t.sol` | Verifies the contracts in a local Foundry environment. |
| Real-node scripts | `script/*.s.sol` | Deploys contracts and broadcasts validation transactions against a real RPC endpoint. |
| Spec vectors | `testdata/zk_gas_spec_cases.json` | Machine-readable `zk_gas_spec` test vectors. |
| Spec matrix | `docs/testcases/zk_gas_spec_test_matrix.md` | Human-readable `zk_gas_spec` test matrix. |

## How To Run

Run all local tests:

```bash
forge test --offline -vv
```

Run only the zk gas transaction harness tests:

```bash
forge test --offline --match-path test/ZkGasTxCases.t.sol -vv
```

Validate opcode support on a real node:

```bash
forge script script/VerifyOpcodes.s.sol:VerifyOpcodesScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

Run zk gas trigger scenarios on a real node:

```bash
forge script script/RunZkGasTxCases.s.sol:RunZkGasTxCasesScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

## Local Foundry Tests

### `test/OpcodeVerifier.t.sol`

These tests cover `OpcodeDeployer` and `OpcodeVerifier`. Each test deploys a raw opcode probe, calls it through the verifier, and checks the decoded result.

| Test function | Covered code | Input | Expected result |
| --- | --- | --- | --- |
| `testTloadTstoreReturnsWrittenValue` | `deployTloadTstoreProbe`, `verifyTransientStoreLoad` | slot `0xA11CE`, value `0xB0B` | Probe call succeeds and returns `0xB0B`. |
| `testMcopyReturnsCopiedBytes` | `deployMcopyProbe`, `verifyMcopy` | `0x11223344556677889900aabbccddeeff` | Probe call succeeds and returns the same bytes. |
| `testClzReturnsLeadingZeroCount` | `deployClzProbe`, `verifyClz` | `bytes32(uint256(1))` | Probe call succeeds, decoded value is `255`, raw return length is `32`. |
| `testBlobhashReturnsZeroWhenNoBlobHashesArePresent` | `deployBlobhashProbe`, `verifyBlobhash` | index `0` | Outside a blob transaction context, the probe returns `bytes32(0)`. |
| `testBlobbasefeeReturnsNonZeroValue` | `deployBlobbasefeeProbe`, `verifyBlobbasefee` | empty calldata | Probe call succeeds and returns a non-zero blob base fee. |

Related events:

```solidity
event ProbeDeployed(string opcode, address probe);
event ProbeResult(string opcode, address probe, bool success, bytes raw);
```

### `test/ZkGasTxCases.t.sol`

These tests cover the transaction-level entrypoints exposed by `ZkGasTxHarness`. Each successful entrypoint emits `CaseExecuted`.

```solidity
event CaseExecuted(string caseId, bool success, bytes data, address related);
```

| Test function | Covered entrypoint | Input | Expected result |
| --- | --- | --- | --- |
| `testTransientStoreLoadCaseReturnsWrittenValue` | `caseTransientStoreLoad` | slot `0xA11CE`, value `0xB0B` | Returns `0xB0B`; emits `caseId=TLOAD_TSTORE`. |
| `testMcopyCaseEchoesBytes` | `caseMcopy` | `0x11223344556677889900aabbccddeeff` | Returns the same bytes; emits `caseId=MCOPY`. |
| `testSpawnOpcodeCasesReturnExpectedValues` | `caseCall`, `caseStaticCall`, `caseDelegateCall`, `caseCallcode` | `7`, `8`, `9`, `10` | Returns `8`, `9`, `10`, and `11`; emits `CALL`, `STATICCALL`, `DELEGATECALL`, and `CALLCODE`. |
| `testIdentityPrecompileEchoesPayload` | `caseCallIdentity` | `bytes4(0xdeadbeef)` plus `uint256(123)` | Identity precompile returns the same payload; emits `caseId=IDENTITY_PRECOMPILE`. |
| `testModexpPrecompileReturnsExpectedValue` | `caseModexp` | base `2`, exponent `5`, modulus `13` | Returns `6`; emits `caseId=MODEXP_PRECOMPILE`. |
| `testCreateAndCreate2DeployChildren` | `caseCreate`, `predictCreate2Address`, `caseCreate2` | seed `41`; salt `keccak256("zk-gas-case")`, seed `42` | `CREATE` returns a non-zero child address and seed `41`; `CREATE2` returns the predicted address and seed `42`. |

### `test/AppendixBFullZkMultipliers.t.sol`

These tests cover the script-facing execution API exposed by `AppendixBZkCases`.

| Test function | Covered entrypoint | Expected result |
| --- | --- | --- |
| `testAppendixBPrecompileCases` | `runPrecompileCases` | All 17 precompile entries are callable. |
| `testAppendixBOpcodeCases` | `runOpcodeCases` | All 149 opcode entries match their expected success or failure behavior. |
| `testAppendixBAllCasesAreCallableFromScript` | `runAll` | Both precompile and opcode groups execute from the unified entrypoint. |
| `testAppendixBIndividualCasesAreCallableFromScript` | `precompileCaseCount`, `opcodeCaseCount`, `runPrecompileCase`, `runOpcodeCase` | Precompile count is `17`, opcode count is `149`, and first/last boundary entries are callable. |

Related events:

```solidity
event AppendixBPrecompileCaseExecuted(uint256 indexed index, address indexed precompile, bool ok);
event AppendixBOpcodeCaseExecuted(uint256 indexed index, bytes1 indexed opcode, bool ok);
```

## Real-Node Script Cases

### `script/VerifyOpcodes.s.sol`

Script flow:

1. Read `RPC_URL` and `PRIVATE_KEY`.
2. Deploy `OpcodeDeployer` and `OpcodeVerifier`.
3. Deploy each opcode probe.
4. Send real transactions through the verifier.

| Case | Target opcode | Input | Expected observable |
| --- | --- | --- | --- |
| `TLOAD/TSTORE` | `TSTORE` plus `TLOAD` | slot `0xA11CE`, value `0xB0B` | `ProbeResult("TLOAD_TSTORE", ..., true, raw)`, where `raw` decodes to `0xB0B`. |
| `MCOPY` | `MCOPY` | `0x11223344556677889900aabbccddeeff` | `ProbeResult("MCOPY", ..., true, raw)`, where `raw` equals the input bytes. |
| `CLZ` | `CLZ` | `bytes32(uint256(1))` | `ProbeResult("CLZ", ..., true, raw)`, where `raw` decodes to `255`. |
| `BLOBHASH` | `BLOBHASH` | index `0` | `ProbeResult("BLOBHASH", ..., true, raw)`, where `raw` is zero outside a blob transaction context. |
| `BLOBBASEFEE` | `BLOBBASEFEE` | empty calldata | `ProbeResult("BLOBBASEFEE", ..., true, raw)`, where `raw` decodes to the current blob base fee. |

### `script/RunZkGasTxCases.s.sol`

Script flow:

1. Read `RPC_URL` and `PRIVATE_KEY`.
2. Deploy `ZkGasTxHarness`.
3. Execute 10 zk gas transaction trigger entrypoints in order.
4. Deploy `AppendixBZkCases`.
5. Execute 17 precompile cases and 149 opcode cases in order.

| Case | Entrypoint | Input | Expected observable |
| --- | --- | --- | --- |
| `TLOAD/TSTORE` | `caseTransientStoreLoad` | slot `0xA11CE`, value `0xB0B` | `CaseExecuted("TLOAD_TSTORE", true, abi.encode(0xB0B), address(0))`. |
| `MCOPY` | `caseMcopy` | `0x11223344556677889900aabbccddeeff` | `CaseExecuted("MCOPY", true, output, address(0))`, where `output` equals the input. |
| `CALL` | `caseCall` | `7` | `CaseExecuted("CALL", true, abi.encode(8), target)`. |
| `STATICCALL` | `caseStaticCall` | `8` | `CaseExecuted("STATICCALL", true, abi.encode(9), target)`. |
| `DELEGATECALL` | `caseDelegateCall` | `9` | `CaseExecuted("DELEGATECALL", true, abi.encode(10), target)`. |
| `CALLCODE` | `caseCallcode` | `10` | `CaseExecuted("CALLCODE", true, abi.encode(11), target)`. |
| `identity` precompile | `caseCallIdentity` | `bytes4(0xdeadbeef)` plus `uint256(123)` | `CaseExecuted("IDENTITY_PRECOMPILE", true, output, address(0x04))`. |
| `modexp` precompile | `caseModexp` | base `2`, exponent `5`, modulus `13` | `CaseExecuted("MODEXP_PRECOMPILE", true, abi.encode(6), address(0x05))`. |
| `CREATE` | `caseCreate` | seed `41` | `CaseExecuted("CREATE", true, abi.encode(child, 41), child)`. |
| `CREATE2` | `caseCreate2` | salt `keccak256("zk-gas-case")`, seed `42` | `CaseExecuted("CREATE2", true, abi.encode(child, 42), child)`. |
| Appendix B precompile sweep | `runPrecompileCase(i)` | `i = 0..16` | Emits `AppendixBPrecompileCaseExecuted` for each case. |
| Appendix B opcode sweep | `runOpcodeCase(i)` | `i = 0..148` | Emits `AppendixBOpcodeCaseExecuted` for each case. |

## Appendix B Coverage Set

`src/AppendixBZkCases.sol` hardcodes the coverage set. Tests assert the counts to detect accidental drift.

Precompile coverage:

| Range | Addresses |
| --- | --- |
| `0..16` | `0x01` through `0x11` |

Opcode coverage:

| Group | Opcodes |
| --- | --- |
| Stop and arithmetic | `0x00..0x0b` |
| Comparison and bitwise | `0x10..0x1d` |
| Hashing | `0x20` |
| Environment and block context | `0x30..0x4a` |
| Stack, memory, storage, transient storage, and jumps | `0x50..0x5f` |
| Push, dup, and swap | `0x60..0x9f` |
| Log | `0xa0..0xa4` |
| Create, call, return, revert, invalid, selfdestruct | `0xf0..0xf5`, `0xfa`, `0xfd`, `0xfe`, `0xff` |

Expected behavior:

- The opcode set contains exactly `149` entries.
- `REVERT(0xfd)` and `INVALID(0xfe)` are expected to fail.
- All other opcodes are expected to execute successfully under the generated probe runtime.

## `zk_gas_spec` Vector Cases

Vector sources:

- Human-readable matrix: `docs/testcases/zk_gas_spec_test_matrix.md`
- Machine-readable data: `testdata/zk_gas_spec_cases.json`

| ID | Hook | Scenario |
| --- | --- | --- |
| `OP-001` | `on_opcode` | Normal opcode uses `step_gas * opcode_multiplier`. |
| `OP-002` | `on_opcode` | Dynamic gas opcode still uses observed `step_gas` outside spawn special cases. |
| `OP-003` | `on_opcode` | `CALL` that creates a child frame uses fixed spawn estimate instead of observed step gas. |
| `OP-004` | `on_opcode` | `STATICCALL` to precompile uses fixed spawn estimate. |
| `OP-005` | `on_opcode` | Short-circuited spawn opcode falls back to `step_gas` when no child frame and no precompile are created. |
| `OP-006` | `on_opcode` | `CREATE2` uses fixed spawn estimate and its low multiplier. |
| `OP-007` | `on_opcode` | Terminal opcode with zero multiplier adds no zk gas. |
| `OP-008` | `on_opcode` | `TLOAD` multiplier anchor is applied as listed in Appendix B. |
| `OP-009` | `on_opcode` | `TSTORE` multiplier anchor is applied as listed in Appendix B. |
| `OP-010` | `on_opcode` | `MCOPY` multiplier anchor is applied as listed in Appendix B. |
| `OP-011` | `on_opcode` | Unknown opcode uses fail-safe multiplier `max(uint16)`. |
| `PC-001` | `on_precompile` | `modexp` uses its explicit precompile multiplier. |
| `PC-002` | `on_precompile` | `identity` precompile uses its low multiplier. |
| `PC-003` | `on_precompile` | Unknown precompile uses fail-safe multiplier `max(uint16)`. |
| `PC-004` | `combined` | `CALL` to precompile must charge both opcode-side spawn estimate and precompile-side gas. |
| `PC-005` | `combined` | Precompile gas used excludes `CALL`-family overhead, cold access, memory expansion, and value stipend already handled at opcode side. |
| `BLK-001` | `execute_block` | Equality with the block limit does not halt because the comparison is strict greater-than. |
| `BLK-002` | `execute_block` | Exceeding the block limit by one halts immediately. |
| `BLK-003` | `execute_block` | The offending transaction is fully aborted and remaining transactions are skipped. |
| `BLK-004` | `execute_block` | System and anchor transactions are included in block-level zk gas accounting. |
| `OVF-001` | `on_opcode` | Multiplication overflow is treated as immediate halt. |
| `OVF-002` | `limit_check` | Addition overflow in `block_zk_gas_used + tx_zk_gas_used` is treated as immediate halt. |

## Counts

| Category | Count |
| --- | ---: |
| Local Foundry test functions | 15 |
| Real-node opcode validation script cases | 5 |
| Explicit real-node zk gas trigger script cases | 10 |
| Appendix B precompile executable entries | 17 |
| Appendix B opcode executable entries | 149 |
| `zk_gas_spec` vector cases | 22 |
