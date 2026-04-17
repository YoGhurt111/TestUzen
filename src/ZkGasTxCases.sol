// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract SpawnTarget {
    function plusOne(uint256 value) external pure returns (uint256) {
        return value + 1;
    }
}

contract CreatedChild {
    uint256 public immutable seed;

    constructor(uint256 _seed) {
        seed = _seed;
    }
}

contract ZkGasTxHarness {
    error CaseExecutionFailed(string caseId);

    event CaseExecuted(string caseId, bool success, bytes data, address related);

    SpawnTarget public immutable target;

    constructor() {
        target = new SpawnTarget();
    }

    function caseTransientStoreLoad(bytes32 slot, bytes32 value) external returns (bytes32 loaded) {
        assembly {
            tstore(slot, value)
            loaded := tload(slot)
        }

        emit CaseExecuted("TLOAD_TSTORE", true, abi.encode(loaded), address(0));
    }

    function caseMcopy(bytes memory input) external returns (bytes memory output) {
        output = new bytes(input.length);

        assembly {
            let length := mload(input)
            mcopy(add(output, 0x20), add(input, 0x20), length)
        }

        emit CaseExecuted("MCOPY", true, output, address(0));
    }

    function caseCall(uint256 value) external returns (uint256 result) {
        (bool ok, bytes memory data) = address(target).call(abi.encodeCall(SpawnTarget.plusOne, (value)));
        if (!ok) revert CaseExecutionFailed("CALL");

        result = abi.decode(data, (uint256));
        emit CaseExecuted("CALL", true, abi.encode(result), address(target));
    }

    function caseStaticCall(uint256 value) external returns (uint256 result) {
        (bool ok, bytes memory data) = address(target).staticcall(
            abi.encodeCall(SpawnTarget.plusOne, (value))
        );
        if (!ok) revert CaseExecutionFailed("STATICCALL");

        result = abi.decode(data, (uint256));
        emit CaseExecuted("STATICCALL", true, abi.encode(result), address(target));
    }

    function caseDelegateCall(uint256 value) external returns (uint256 result) {
        (bool ok, bytes memory data) = address(target).delegatecall(
            abi.encodeCall(SpawnTarget.plusOne, (value))
        );
        if (!ok) revert CaseExecutionFailed("DELEGATECALL");

        result = abi.decode(data, (uint256));
        emit CaseExecuted("DELEGATECALL", true, abi.encode(result), address(target));
    }

    function caseCallcode(uint256 value) external returns (uint256 result) {
        bytes memory payload = abi.encodeCall(SpawnTarget.plusOne, (value));
        (bool ok, bytes memory data) = _callcode(address(target), payload);
        if (!ok) revert CaseExecutionFailed("CALLCODE");

        result = abi.decode(data, (uint256));
        emit CaseExecuted("CALLCODE", true, abi.encode(result), address(target));
    }

    function caseCallIdentity(bytes memory input) external returns (bytes memory output) {
        (bool ok, bytes memory data) = address(0x04).call(input);
        if (!ok) revert CaseExecutionFailed("IDENTITY_PRECOMPILE");

        output = data;
        emit CaseExecuted("IDENTITY_PRECOMPILE", true, output, address(0x04));
    }

    function caseModexp(uint256 base, uint256 exponent, uint256 modulus) external returns (uint256 result) {
        bytes memory payload = abi.encode(uint256(32), uint256(32), uint256(32), base, exponent, modulus);
        (bool ok, bytes memory data) = address(0x05).staticcall(payload);
        if (!ok) revert CaseExecutionFailed("MODEXP_PRECOMPILE");

        result = abi.decode(data, (uint256));
        emit CaseExecuted("MODEXP_PRECOMPILE", true, abi.encode(result), address(0x05));
    }

    function caseCreate(uint256 seed) external returns (address child, uint256 storedSeed) {
        child = address(new CreatedChild(seed));
        storedSeed = CreatedChild(child).seed();

        emit CaseExecuted("CREATE", true, abi.encode(child, storedSeed), child);
    }

    function caseCreate2(bytes32 salt, uint256 seed) external returns (address child, uint256 storedSeed) {
        child = address(new CreatedChild{ salt: salt }(seed));
        storedSeed = CreatedChild(child).seed();

        emit CaseExecuted("CREATE2", true, abi.encode(child, storedSeed), child);
    }

    function predictCreate2Address(bytes32 salt, uint256 seed) external view returns (address predicted) {
        bytes memory initCode = abi.encodePacked(type(CreatedChild).creationCode, abi.encode(seed));
        bytes32 digest = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(initCode)));
        predicted = address(uint160(uint256(digest)));
    }

    function _callcode(address callee, bytes memory payload) internal returns (bool ok, bytes memory data) {
        assembly {
            let payloadLength := mload(payload)
            let payloadOffset := add(payload, 0x20)

            ok := callcode(gas(), callee, 0, payloadOffset, payloadLength, 0, 0)

            let size := returndatasize()
            data := mload(0x40)
            mstore(data, size)
            returndatacopy(add(data, 0x20), 0, size)
            mstore(0x40, and(add(add(data, 0x20), add(size, 0x1f)), not(0x1f)))
        }
    }
}
