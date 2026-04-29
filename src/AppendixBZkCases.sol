// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract AppendixBZkCases {
    error DeploymentFailed(bytes runtime);
    error OpcodeCaseFailed(uint256 index, bytes1 opcode, bool ok, bytes data);
    error PrecompileCaseFailed(uint256 index, address precompile);

    event AppendixBPrecompileCaseExecuted(
        uint256 indexed index, address indexed precompile, bool ok
    );
    event AppendixBOpcodeCaseExecuted(uint256 indexed index, bytes1 indexed opcode, bool ok);

    function runAll() external {
        runPrecompileCases();
        runOpcodeCases();
    }

    function precompileCaseCount() external pure returns (uint256) {
        return 17;
    }

    function opcodeCaseCount() external pure returns (uint256) {
        return _appendixBOpcodes().length;
    }

    function runPrecompileCases() public {
        for (uint256 i; i < 17; ++i) {
            runPrecompileCase(i);
        }
    }

    function runPrecompileCase(uint256 index) public {
        address precompile = _appendixBPrecompile(index);
        (bool reached,) =
            address(this).staticcall(abi.encodeCall(this.invokeAppendixBPrecompile, (precompile)));
        if (!reached) revert PrecompileCaseFailed(index, precompile);

        emit AppendixBPrecompileCaseExecuted(index, precompile, reached);
    }

    function runOpcodeCases() public {
        bytes memory opcodes = _appendixBOpcodes();
        require(opcodes.length == 149, "Appendix B opcode count changed");

        for (uint256 i; i < opcodes.length; ++i) {
            runOpcodeCase(i);
        }
    }

    function runOpcodeCase(uint256 index) public {
        bytes memory opcodes = _appendixBOpcodes();
        require(opcodes.length == 149, "Appendix B opcode count changed");

        bytes1 opcode = opcodes[index];
        bytes memory runtime = _runtimeForOpcode(opcode);
        address probe = _deploy(runtime);
        (bool ok, bytes memory data) =
            probe.call{ gas: 100_000 }(hex"11223344556677889900aabbccddeeff");

        if (ok != _expectsSuccess(opcode)) revert OpcodeCaseFailed(index, opcode, ok, data);
        emit AppendixBOpcodeCaseExecuted(index, opcode, ok);
    }

    function invokeAppendixBPrecompile(address precompile)
        external
        view
        returns (bool ok, bytes memory output)
    {
        bytes memory input = _precompileInput(precompile);
        (ok, output) = precompile.staticcall{ gas: 1_000_000 }(input);
    }

    function _appendixBPrecompile(uint256 index) internal pure returns (address) {
        address[17] memory precompiles = [
            address(0x01),
            address(0x02),
            address(0x03),
            address(0x04),
            address(0x05),
            address(0x06),
            address(0x07),
            address(0x08),
            address(0x09),
            address(0x0a),
            address(0x0b),
            address(0x0c),
            address(0x0d),
            address(0x0e),
            address(0x0f),
            address(0x10),
            address(0x11)
        ];

        return precompiles[index];
    }

    function _appendixBOpcodes() internal pure returns (bytes memory) {
        return hex"000102030405060708090a0b101112131415161718191a1b1c1d20303132333435363738393a3b3c3d3e3f404142434445464748494a505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4f0f1f2f3f4f5fafdfeff";
    }

    function _runtimeForOpcode(bytes1 opcode) internal pure returns (bytes memory) {
        uint8 op = uint8(opcode);

        if (op == 0x00) return hex"00";
        if (op >= 0x01 && op <= 0x07) return abi.encodePacked(hex"60026003", opcode, hex"5000");
        if (op == 0x08 || op == 0x09) {
            return abi.encodePacked(hex"600760036002", opcode, hex"5000");
        }
        if (op == 0x0a || op == 0x0b) return abi.encodePacked(hex"60026003", opcode, hex"5000");
        if (op >= 0x10 && op <= 0x1d) return abi.encodePacked(hex"60026003", opcode, hex"5000");
        if (op == 0x20) return abi.encodePacked(hex"60006000", opcode, hex"5000");
        if (op == 0x30 || (op >= 0x32 && op <= 0x34) || op == 0x36) {
            return abi.encodePacked(opcode, hex"5000");
        }
        if (op == 0x31 || op == 0x35) return abi.encodePacked(hex"6000", opcode, hex"5000");
        if (op == 0x37) return abi.encodePacked(hex"600160006000", opcode, hex"00");
        if (op == 0x38 || op == 0x3a) return abi.encodePacked(opcode, hex"5000");
        if (op == 0x39) return abi.encodePacked(hex"600160006000", opcode, hex"00");
        if (op == 0x3b) return abi.encodePacked(hex"6000", opcode, hex"5000");
        if (op == 0x3c) return abi.encodePacked(hex"6001600060006000", opcode, hex"00");
        if (op == 0x3d) return abi.encodePacked(opcode, hex"5000");
        if (op == 0x3e) return abi.encodePacked(hex"600060006000", opcode, hex"00");
        if (op == 0x3f) return abi.encodePacked(hex"6000", opcode, hex"5000");
        if (op == 0x40) return abi.encodePacked(hex"6000", opcode, hex"5000");
        if (op >= 0x41 && op <= 0x48) return abi.encodePacked(opcode, hex"5000");
        if (op == 0x49) return abi.encodePacked(hex"6000", opcode, hex"5000");
        if (op == 0x4a) return abi.encodePacked(opcode, hex"5000");
        if (op == 0x50) return abi.encodePacked(hex"6001", opcode, hex"00");
        if (op == 0x51 || op == 0x59 || op == 0x5c) {
            return abi.encodePacked(hex"6000", opcode, hex"5000");
        }
        if (op == 0x52 || op == 0x53 || op == 0x55 || op == 0x5d) {
            return abi.encodePacked(hex"60016000", opcode, hex"00");
        }
        if (op == 0x54) return abi.encodePacked(hex"6000", opcode, hex"5000");
        if (op == 0x56) return abi.encodePacked(hex"6003565b00");
        if (op == 0x57) return abi.encodePacked(hex"60016005575b00");
        if (op == 0x58 || op == 0x5a || op == 0x5f) return abi.encodePacked(opcode, hex"5000");
        if (op == 0x5b) return abi.encodePacked(opcode, hex"00");
        if (op == 0x5e) return abi.encodePacked(hex"600160006000", opcode, hex"00");
        if (op >= 0x60 && op <= 0x7f) return _pushRuntime(op);
        if (op >= 0x80 && op <= 0x8f) return abi.encodePacked(_pushes(op - 0x7f), opcode, hex"00");
        if (op >= 0x90 && op <= 0x9f) return abi.encodePacked(_pushes(op - 0x8e), opcode, hex"00");
        if (op >= 0xa0 && op <= 0xa4) {
            return abi.encodePacked(_pushes(op - 0x9f), hex"60006000", opcode, hex"00");
        }
        if (op == 0xf0) return abi.encodePacked(hex"600060006000", opcode, hex"5000");
        if (op == 0xf1 || op == 0xf2) {
            return abi.encodePacked(hex"6000600060006000600060045a", opcode, hex"5000");
        }
        if (op == 0xf3 || op == 0xfd) return abi.encodePacked(hex"60006000", opcode);
        if (op == 0xf4 || op == 0xfa) {
            return abi.encodePacked(hex"600060006000600060045a", opcode, hex"5000");
        }
        if (op == 0xf5) return abi.encodePacked(hex"6000600060006000", opcode, hex"5000");
        if (op == 0xfe) return abi.encodePacked(opcode);
        if (op == 0xff) return abi.encodePacked(hex"6000", opcode);

        revert OpcodeCaseFailed(type(uint256).max, opcode, false, "");
    }

    function _deploy(bytes memory runtime) internal returns (address probe) {
        bytes memory initCode = abi.encodePacked(
            hex"61", bytes2(uint16(runtime.length)), hex"80600c6000396000f3", runtime
        );

        assembly {
            probe := create(0, add(initCode, 0x20), mload(initCode))
        }

        if (probe == address(0)) revert DeploymentFailed(runtime);
    }

    function _expectsSuccess(bytes1 opcode) internal pure returns (bool) {
        return opcode != 0xfd && opcode != 0xfe;
    }

    function _pushRuntime(uint8 opcode) internal pure returns (bytes memory runtime) {
        uint256 pushBytes = opcode - 0x5f;
        runtime = new bytes(1 + pushBytes + 1);
        runtime[0] = bytes1(opcode);
        runtime[runtime.length - 1] = 0x00;
    }

    function _pushes(uint256 count) internal pure returns (bytes memory runtime) {
        runtime = new bytes(count * 2);
        for (uint256 i; i < count; ++i) {
            runtime[i * 2] = 0x60;
            runtime[i * 2 + 1] = bytes1(uint8(i + 1));
        }
    }

    function _precompileInput(address precompile) internal pure returns (bytes memory) {
        if (precompile == address(0x02)) return "abc";
        if (precompile == address(0x03)) return "abc";
        if (precompile == address(0x04)) return hex"11223344556677889900aabbccddeeff";
        if (precompile == address(0x05)) {
            return abi.encode(
                uint256(32), uint256(32), uint256(32), uint256(2), uint256(5), uint256(13)
            );
        }
        if (precompile == address(0x08)) return "";
        return "";
    }
}
