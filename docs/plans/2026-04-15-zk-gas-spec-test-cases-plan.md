# ZK Gas Spec Test Cases Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Generate a reviewable and machine-readable test suite specification for `zk_gas_spec.md` that can be wired into a future zk gas metering implementation.

**Architecture:** Capture the spec in two complementary artifacts: a human-readable matrix grouped by meter hook (`on_opcode`, `on_precompile`, `execute_block`) and a JSON vector file with exact inputs and expected outputs. The cases focus on protocol semantics, boundary behavior, overflow handling, and representative multiplier values from Appendix B.

**Tech Stack:** Markdown, JSON, Foundry-adjacent test vector conventions.

### Task 1: Extract the normative rules from the spec

**Files:**
- Create: `docs/testcases/zk_gas_spec_test_matrix.md`
- Create: `testdata/zk_gas_spec_cases.json`

**Step 1: Enumerate protocol constants and hooks**

Extract:
- `BLOCK_ZK_GAS_LIMIT = 100_000_000`
- `SPAWN_ESTIMATE` constants
- `uint64` arithmetic / overflow semantics
- default multiplier behavior for unlisted opcodes and precompiles

**Step 2: Enumerate mandatory behaviors**

Capture behaviors for:
- plain opcode metering
- spawn opcode metering
- precompile metering
- block abort / remaining tx skip semantics

### Task 2: Write the failing test specification first

**Files:**
- Create: `docs/testcases/zk_gas_spec_test_matrix.md`

**Step 1: Write case matrix grouped by behavior**

List test IDs, setup, input, expected zk gas delta, and expected halt/abort behavior.

**Step 2: Include negative and edge cases**

Include:
- unknown opcode / precompile fail-safe behavior
- `>` vs `>=` limit check
- multiplication overflow
- addition overflow
- terminal opcode zero multiplier

### Task 3: Encode the same cases as machine-readable vectors

**Files:**
- Create: `testdata/zk_gas_spec_cases.json`

**Step 1: Add deterministic vector format**

Include:
- hook name
- inputs
- expected raw gas
- expected zk delta
- expected tx/block post-state

**Step 2: Add representative multiplier anchors**

Use representative values such as:
- `ADD` = 12
- `TLOAD` = 1
- `MCOPY` = 5
- `TSTORE` = 6
- `CALL` = 25
- `CREATE2` = 1
- `modexp` = 1363
- `identity` = 2

### Task 4: Verify consistency against the source spec

**Files:**
- Modify: `docs/testcases/zk_gas_spec_test_matrix.md`
- Modify: `testdata/zk_gas_spec_cases.json`

**Step 1: Cross-check every hardcoded constant against the source spec**

Verify:
- spawn estimates
- multiplier anchors
- block limit
- fail-safe defaults

**Step 2: Confirm behavioral coverage**

Make sure the final output covers:
- `on_opcode`
- `on_precompile`
- `execute_block`
- overflow handling
- system tx inclusion
