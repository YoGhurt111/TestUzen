// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ZkGasTxHarness } from "../src/ZkGasTxCases.sol";

interface Vm {
    function envString(string calldata name) external returns (string memory);
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract RunZkGasTxCasesScript {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        VM.envString("RPC_URL");
        uint256 privateKey = VM.envUint("PRIVATE_KEY");

        VM.startBroadcast(privateKey);

        ZkGasTxHarness harness = new ZkGasTxHarness();

        harness.caseTransientStoreLoad(bytes32(uint256(0xA11CE)), bytes32(uint256(0xB0B)));
        harness.caseMcopy(hex"11223344556677889900aabbccddeeff");
        harness.caseCall(7);
        harness.caseStaticCall(8);
        harness.caseDelegateCall(9);
        harness.caseCallcode(10);
        harness.caseCallIdentity(abi.encodePacked(bytes4(0xdeadbeef), bytes32(uint256(123))));
        harness.caseModexp(2, 5, 13);
        harness.caseCreate(41);
        harness.caseCreate2(keccak256("zk-gas-case"), 42);

        VM.stopBroadcast();
    }
}
