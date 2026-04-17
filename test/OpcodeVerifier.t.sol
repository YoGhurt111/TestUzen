// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { OpcodeDeployer, OpcodeVerifier } from "../src/OpcodeProbes.sol";

contract OpcodeVerifierTest {
    OpcodeDeployer internal deployer;
    OpcodeVerifier internal verifier;

    function setUp() public {
        deployer = new OpcodeDeployer();
        verifier = new OpcodeVerifier();
    }

    function testTloadTstoreReturnsWrittenValue() public {
        address probe = deployer.deployTloadTstoreProbe();
        (bool ok, bytes32 value) = verifier.verifyTransientStoreLoad(
            probe,
            bytes32(uint256(0xA11CE)),
            bytes32(uint256(0xB0B))
        );

        _assertTrue(ok, "expected transient opcode probe to succeed");
        _assertEq(value, bytes32(uint256(0xB0B)), "unexpected transient load value");
    }

    function testMcopyReturnsCopiedBytes() public {
        address probe = deployer.deployMcopyProbe();
        bytes memory input = hex"11223344556677889900aabbccddeeff";
        (bool ok, bytes memory output) = verifier.verifyMcopy(probe, input);

        _assertTrue(ok, "expected mcopy probe to succeed");
        _assertBytesEq(output, input, "unexpected mcopy output");
    }

    function testClzFailureIsSurfacedCleanly() public {
        address probe = deployer.deployClzProbe();
        (bool ok, uint256 value, bytes memory raw) = verifier.verifyClz(probe, bytes32(uint256(1)));

        _assertTrue(!ok, "expected clz probe to fail on unsupported local evm");
        _assertEq(value, 0, "unexpected clz decoded value");
        _assertEq(raw.length, 0, "unexpected revert payload length");
    }

    function _assertTrue(bool condition, string memory reason) internal pure {
        require(condition, reason);
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
