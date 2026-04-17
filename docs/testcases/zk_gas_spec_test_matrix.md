# ZK Gas Spec Test Matrix

Source document:
- `taikoxyz/taiko-mono`
- `packages/protocol/docs/zk_gas_spec.md`
- `ref: main`
- `sha: f31286f5b760ef29bcc06e2fd2559a0ee952a670`

TL;DR:
This matrix breaks the rules in `zk_gas_spec.md` into 22 core test cases covering `on_opcode`, `on_precompile`, `execute_block`, overflow protection, default multiplier fail-safe behavior, and the special metering paths for spawn opcodes and precompiles.

## Fixed Constants

- `BLOCK_ZK_GAS_LIMIT = 100_000_000`
- `SPAWN_ESTIMATE[CALL] = 12_500`
- `SPAWN_ESTIMATE[CALLCODE] = 12_500`
- `SPAWN_ESTIMATE[DELEGATECALL] = 3_500`
- `SPAWN_ESTIMATE[STATICCALL] = 3_500`
- `SPAWN_ESTIMATE[CREATE] = 37_000`
- `SPAWN_ESTIMATE[CREATE2] = 44_500`
- Unlisted opcode multipliers default to `65535`
- Unlisted precompile multipliers default to `65535`
- All zk gas arithmetic uses `uint64`
- The limit check is strict-greater-than: `block_zk_gas_used + tx_zk_gas_used > BLOCK_ZK_GAS_LIMIT`

## Coverage Goals

- Normal opcodes use `step_gas * opcode_multiplier`
- Spawn opcodes use fixed `SPAWN_ESTIMATE` only when they actually create a child frame or invoke a precompile
- Short-circuited spawn opcodes still use `step_gas`
- Precompiles require double charging:
  `CALL-family spawn estimate * opcode multiplier`
  plus `precompile_gas_used * precompile multiplier`
- The offending transaction is fully reverted, all following transactions are skipped, and earlier completed transactions are kept
- Any multiplication or addition overflow is treated as exceed-limit and halts immediately

## Test Cases

| ID | Hook/Layer | Scenario | Input Summary | Expected |
| --- | --- | --- | --- | --- |
| `OP-001` | `on_opcode` | Basic metering for a normal opcode | `ADD(0x01)`, `step_gas=3`, `child_frame_created=false`, `precompile_invoked=false`, `multiplier=12` | `raw_gas=3`, `zk_delta=36`, no halt |
| `OP-002` | `on_opcode` | Dynamic-gas opcode uses real `step_gas` | `KECCAK256(0x20)`, `step_gas=42`, `multiplier=85` | `zk_delta=3570`, no halt |
| `OP-003` | `on_opcode` | Spawn opcode uses fixed estimate when it creates a child frame | `CALL(0xf1)`, `step_gas=50000`, `child_frame_created=true`, `precompile_invoked=false`, `multiplier=25` | `raw_gas=12500`, `zk_delta=312500`, does not use `step_gas` |
| `OP-004` | `on_opcode` | Spawn opcode uses fixed estimate when it hits a precompile | `STATICCALL(0xfa)`, `step_gas=19000`, `child_frame_created=false`, `precompile_invoked=true`, `multiplier=24` | `raw_gas=3500`, `zk_delta=84000` |
| `OP-005` | `on_opcode` | Short-circuited spawn opcode still uses `step_gas` | `DELEGATECALL(0xf4)`, `step_gas=2600`, `child_frame_created=false`, `precompile_invoked=false`, `multiplier=21` | `raw_gas=2600`, `zk_delta=54600` |
| `OP-006` | `on_opcode` | `CREATE2` uses fixed estimation | `CREATE2(0xf5)`, `step_gas=80000`, `child_frame_created=true`, `multiplier=1` | `raw_gas=44500`, `zk_delta=44500` |
| `OP-007` | `on_opcode` | Terminal opcode multiplier is zero | `RETURN(0xf3)`, `step_gas=0`, `multiplier=0` | `zk_delta=0`, no extra zk gas is charged |
| `OP-008` | `on_opcode` | Newly listed opcode multiplier anchor from the document | `TLOAD(0x5c)`, `step_gas=100`, `multiplier=1` | `zk_delta=100` |
| `OP-009` | `on_opcode` | `TSTORE` multiplier anchor | `TSTORE(0x5d)`, `step_gas=100`, `multiplier=6` | `zk_delta=600` |
| `OP-010` | `on_opcode` | `MCOPY` multiplier anchor | `MCOPY(0x5e)`, `step_gas=100`, `multiplier=5` | `zk_delta=500` |
| `OP-011` | `on_opcode` | Unknown opcode fail-safe | `opcode=0xab` not present in Appendix B, `step_gas=1` | `multiplier=65535`, `zk_delta=65535`, intentionally near the limit to expose missing table entries |
| `PC-001` | `on_precompile` | Precompile metered on its own | `modexp(0x05)`, `gas_used=200`, `multiplier=1363` | `zk_delta=272600`, no halt |
| `PC-002` | `on_precompile` | Low-multiplier precompile anchor | `identity(0x04)`, `gas_used=300`, `multiplier=2` | `zk_delta=600` |
| `PC-003` | `on_precompile` | Unknown precompile fail-safe | `addr=0xfe`, `gas_used=1` | `multiplier=65535`, `zk_delta=65535` |
| `PC-004` | `opcode + precompile` | Double charging for a precompile path | `CALL` hits `modexp`, `CALL step` uses `12500*25`, `precompile_gas_used=200`, `modexp=1363` | opcode side `312500`, precompile side `272600`, total `585100` |
| `PC-005` | `opcode + precompile` | Precompile gas must exclude CALL-side overhead | `CALL to identity`, `step_gas=15000`, `precompile_gas_used=300` | opcode side charges only `12500*25`, precompile side charges only `300*2`; cold access / memory expansion must not be double-counted inside precompile metering |
| `BLK-001` | `execute_block` | Execution continues when the limit is reached exactly but not exceeded | initial `block_zk_gas_used=99_999_964`, current opcode `ADD step_gas=3 -> zk_delta=36` | total is exactly `100_000_000`, no halt |
| `BLK-002` | `execute_block` | Immediate halt when the limit is exceeded | initial `block_zk_gas_used=99_999_965`, current opcode `ADD step_gas=3 -> zk_delta=36` | total `100_000_001`, immediate halt |
| `BLK-003` | `execute_block` | Offending transaction is fully reverted | block contains `tx1` succeeds, `tx2` exceeds mid-execution, `tx3` would otherwise be executable | keep `tx1`, discard all state changes from `tx2`, skip `tx3` |
| `BLK-004` | `execute_block` | All transactions are charged, including system/anchor txs | first block tx is a system tx, which consumes zk gas before a normal tx approaches the limit | the normal tx’s limit check must include zk gas already consumed by the system tx |
| `OVF-001` | arithmetic | Multiplication overflow is treated as exceed-limit | `step_gas = 2^64 - 1`, `multiplier = 2` | `raw_gas * multiplier` overflows and halts immediately |
| `OVF-002` | arithmetic | Addition overflow is treated as exceed-limit | `block_zk_gas_used = 2^64 - 10`, `tx_zk_gas_used = 20` | addition overflows and halts immediately |

## Recommended Implementation Order

1. Start with pure-function unit tests:
   `computeOpcodeZkDelta`
   `computePrecompileZkDelta`
   `shouldHalt`
2. Then add transaction-level tests:
   offending transaction rollback
   remaining transaction skip
3. Finally add system tx / anchor tx coverage and unknown opcode/precompile fail-safe tests.

## Minimum Acceptance Criteria

- Cover the normal `on_opcode` path, spawn path, and short-circuit path
- Cover standalone `on_precompile` charging and combined double-charging
- Cover `>` rather than `>=`
- Cover multiplication overflow and addition overflow
- Cover default `65535` for unknown opcodes and precompiles
