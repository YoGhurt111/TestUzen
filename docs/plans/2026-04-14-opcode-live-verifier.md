# Opcode Live Verifier Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a minimal Foundry project that can deploy raw-bytecode opcode probes and send real transactions to a live Taiko-compatible RPC to verify whether specific post-Cancun opcodes execute correctly.

**Architecture:** Use raw EVM runtime bytecode for each opcode probe so the project does not depend on Solidity exposing those opcodes or the selected `evm_version`. A small Solidity deployer/verifier layer deploys probe contracts, executes them, decodes results, and emits machine-readable events. Local Foundry tests validate deploy/call/result decoding logic, while a broadcast script sends real transactions to a node and prints the observed support matrix.

**Tech Stack:** Solidity, Foundry (`forge`, `cast`), raw EVM bytecode, broadcast scripts.

### Task 1: Bootstrap the Foundry project

**Files:**
- Create: `foundry.toml`
- Create: `README.md`

**Step 1: Write the minimal project config**

Create a Foundry config with `src`, `test`, `script`, and `out` directories.

**Step 2: Document runtime assumptions**

Document required environment variables: `RPC_URL`, `PRIVATE_KEY`, optional `CHAIN_NAME`.

### Task 2: Write failing tests for the probe orchestration

**Files:**
- Create: `test/OpcodeVerifier.t.sol`
- Test: `test/OpcodeVerifier.t.sol`

**Step 1: Write tests against missing production contracts**

Write tests that expect:
- deployer can deploy a `TLOAD/TSTORE` probe and return the stored transient value
- deployer can deploy an `MCOPY` probe and return copied bytes
- deployer can deploy a `CLZ` probe and surface unsupported-opcode failure cleanly

**Step 2: Run test to verify it fails**

Run: `forge test`

Expected: FAIL because `src/OpcodeProbes.sol` or equivalent implementation does not exist yet.

### Task 3: Implement minimal probe/deployer/verifier contracts

**Files:**
- Create: `src/OpcodeProbes.sol`

**Step 1: Add raw runtime bytecode builders**

Implement byte builders for:
- `TLOAD/TSTORE`
- `MCOPY`
- `CLZ`

**Step 2: Add deploy and verify helpers**

Implement a deployer that wraps runtime bytecode with initcode and deploys it via `create`, plus a verifier that calls the probe and decodes `(success, bytes)` into typed results.

**Step 3: Run tests**

Run: `forge test`

Expected: PASS for local behavior checks.

### Task 4: Add a broadcastable live-node script

**Files:**
- Create: `script/VerifyOpcodes.s.sol`

**Step 1: Build a script entrypoint**

Deploy the verifier, deploy each opcode probe, execute each probe via on-chain transactions, and print a result summary.

**Step 2: Encode real transaction probes**

Use non-view verifier functions so `forge script --broadcast` sends real transactions to the target node.

**Step 3: Add a sample command**

Document a command such as:

```bash
RPC_URL=... PRIVATE_KEY=... forge script script/VerifyOpcodes.s.sol:VerifyOpcodesScript --rpc-url "$RPC_URL" --broadcast
```

### Task 5: Verify end-to-end locally

**Files:**
- Modify: `README.md`

**Step 1: Run local tests**

Run: `forge test -vv`

Expected: PASS

**Step 2: Build script without broadcasting**

Run: `forge script script/VerifyOpcodes.s.sol:VerifyOpcodesScript`

Expected: Script compiles and simulates successfully.
