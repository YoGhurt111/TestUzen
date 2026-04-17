// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library OpcodeRuntimes {
    error RuntimeTooLarge();

    function tloadTstoreRuntime() internal pure returns (bytes memory) {
        // 60 20    PUSH1 0x20
        // 35       CALLDATALOAD
        // 5f       PUSH0
        // 35       CALLDATALOAD
        // 5d       TSTORE
        // 5f       PUSH0
        // 35       CALLDATALOAD
        // 5c       TLOAD
        // 5f       PUSH0
        // 52       MSTORE
        // 60 20    PUSH1 0x20
        // 5f       PUSH0
        // f3       RETURN
        return hex"6020355f355d5f355c5f5260205ff3";
    }

    function mcopyRuntime() internal pure returns (bytes memory) {
        // 36       CALLDATASIZE
        // 80       DUP1
        // 5f       PUSH0
        // 5f       PUSH0
        // 37       CALLDATACOPY
        // 80       DUP1
        // 5f       PUSH0
        // 81       DUP2
        // 5e       MCOPY
        // 80       DUP1
        // f3       RETURN
        return hex"36805f5f37805f815e80f3";
    }

    function clzRuntime() internal pure returns (bytes memory) {
        // 5f       PUSH0
        // 35       CALLDATALOAD
        // 1e       CLZ
        // 5f       PUSH0
        // 52       MSTORE
        // 60 20    PUSH1 0x20
        // 5f       PUSH0
        // f3       RETURN
        return hex"5f351e5f5260205ff3";
    }

    function toInitCode(bytes memory runtime) internal pure returns (bytes memory) {
        if (runtime.length > type(uint8).max) revert RuntimeTooLarge();

        bytes1 lengthByte = bytes1(uint8(runtime.length));
        return abi.encodePacked(hex"60", lengthByte, hex"600c60003960", lengthByte, hex"6000f3", runtime);
    }
}

contract OpcodeDeployer {
    error DeploymentFailed();

    event ProbeDeployed(string opcode, address probe);

    function deploy(bytes memory runtime) public returns (address probe) {
        bytes memory initCode = OpcodeRuntimes.toInitCode(runtime);

        assembly {
            probe := create(0, add(initCode, 0x20), mload(initCode))
        }

        if (probe == address(0)) revert DeploymentFailed();
    }

    function deployTloadTstoreProbe() external returns (address probe) {
        probe = deploy(OpcodeRuntimes.tloadTstoreRuntime());
        emit ProbeDeployed("TLOAD_TSTORE", probe);
    }

    function deployMcopyProbe() external returns (address probe) {
        probe = deploy(OpcodeRuntimes.mcopyRuntime());
        emit ProbeDeployed("MCOPY", probe);
    }

    function deployClzProbe() external returns (address probe) {
        probe = deploy(OpcodeRuntimes.clzRuntime());
        emit ProbeDeployed("CLZ", probe);
    }
}

contract OpcodeVerifier {
    event ProbeResult(string opcode, address probe, bool success, bytes raw);

    function verifyTransientStoreLoad(address probe, bytes32 slot, bytes32 value)
        external
        returns (bool ok, bytes32 loaded)
    {
        bytes memory raw;
        (ok, raw) = probe.call(abi.encode(slot, value));
        if (ok && raw.length == 32) {
            loaded = abi.decode(raw, (bytes32));
        }
        emit ProbeResult("TLOAD_TSTORE", probe, ok, raw);
    }

    function verifyMcopy(address probe, bytes memory input) external returns (bool ok, bytes memory output) {
        bytes memory raw;
        (ok, raw) = probe.call(input);
        if (ok) {
            output = raw;
        }
        emit ProbeResult("MCOPY", probe, ok, raw);
    }

    function verifyClz(address probe, bytes32 input)
        external
        returns (bool ok, uint256 value, bytes memory raw)
    {
        (ok, raw) = probe.call(abi.encode(input));
        if (ok && raw.length == 32) {
            value = abi.decode(raw, (uint256));
        }
        emit ProbeResult("CLZ", probe, ok, raw);
    }
}
