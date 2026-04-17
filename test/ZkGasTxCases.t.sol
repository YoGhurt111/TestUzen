// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ZkGasTxHarness } from "../src/ZkGasTxCases.sol";

contract ZkGasTxCasesTest {
    ZkGasTxHarness internal harness;

    function setUp() public {
        harness = new ZkGasTxHarness();
    }

    function testTransientStoreLoadCaseReturnsWrittenValue() public {
        bytes32 value = harness.caseTransientStoreLoad(bytes32(uint256(0xA11CE)), bytes32(uint256(0xB0B)));
        _assertEq(value, bytes32(uint256(0xB0B)), "unexpected transient value");
    }

    function testMcopyCaseEchoesBytes() public {
        bytes memory input = hex"11223344556677889900aabbccddeeff";
        bytes memory output = harness.caseMcopy(input);
        _assertBytesEq(output, input, "unexpected mcopy bytes");
    }

    function testSpawnOpcodeCasesReturnExpectedValues() public {
        _assertEq(harness.caseCall(7), 8, "unexpected CALL result");
        _assertEq(harness.caseStaticCall(8), 9, "unexpected STATICCALL result");
        _assertEq(harness.caseDelegateCall(9), 10, "unexpected DELEGATECALL result");
        _assertEq(harness.caseCallcode(10), 11, "unexpected CALLCODE result");
    }

    function testIdentityPrecompileEchoesPayload() public {
        bytes memory input = abi.encodePacked(bytes4(0xdeadbeef), bytes32(uint256(123)));
        bytes memory output = harness.caseCallIdentity(input);
        _assertBytesEq(output, input, "unexpected identity output");
    }

    function testModexpPrecompileReturnsExpectedValue() public {
        uint256 result = harness.caseModexp(2, 5, 13);
        _assertEq(result, 6, "unexpected modexp result");
    }

    function testCreateAndCreate2DeployChildren() public {
        (address created, uint256 seed) = harness.caseCreate(41);
        _assertTrue(created != address(0), "expected CREATE child");
        _assertEq(seed, 41, "unexpected CREATE seed");

        bytes32 salt = keccak256("zk-gas-case");
        address predicted = harness.predictCreate2Address(salt, 42);
        (address created2, uint256 seed2) = harness.caseCreate2(salt, 42);
        _assertEq(created2, predicted, "unexpected CREATE2 address");
        _assertEq(seed2, 42, "unexpected CREATE2 seed");
    }

    function _assertTrue(bool condition, string memory reason) internal pure {
        require(condition, reason);
    }

    function _assertEq(address left, address right, string memory reason) internal pure {
        require(left == right, reason);
    }

    function _assertEq(bytes32 left, bytes32 right, string memory reason) internal pure {
        require(left == right, reason);
    }

    function _assertEq(uint256 left, uint256 right, string memory reason) internal pure {
        require(left == right, reason);
    }

    function _assertBytesEq(bytes memory left, bytes memory right, string memory reason) internal pure {
        require(keccak256(left) == keccak256(right), reason);
    }
}
