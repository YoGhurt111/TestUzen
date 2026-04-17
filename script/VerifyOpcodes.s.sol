// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { OpcodeDeployer, OpcodeVerifier } from "../src/OpcodeProbes.sol";

interface Vm {
    function envString(string calldata name) external returns (string memory);
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract VerifyOpcodesScript {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        VM.envString("RPC_URL");
        uint256 privateKey = VM.envUint("PRIVATE_KEY");

        VM.startBroadcast(privateKey);

        OpcodeDeployer deployer = new OpcodeDeployer();
        OpcodeVerifier verifier = new OpcodeVerifier();

        address tstoreProbe = deployer.deployTloadTstoreProbe();
        verifier.verifyTransientStoreLoad(
            tstoreProbe,
            bytes32(uint256(0xA11CE)),
            bytes32(uint256(0xB0B))
        );

        address mcopyProbe = deployer.deployMcopyProbe();
        verifier.verifyMcopy(mcopyProbe, hex"11223344556677889900aabbccddeeff");

        address clzProbe = deployer.deployClzProbe();
        verifier.verifyClz(clzProbe, bytes32(uint256(1)));

        address blobhashProbe = deployer.deployBlobhashProbe();
        verifier.verifyBlobhash(blobhashProbe, bytes32(uint256(0)));

        address blobbasefeeProbe = deployer.deployBlobbasefeeProbe();
        verifier.verifyBlobbasefee(blobbasefeeProbe);

        VM.stopBroadcast();
    }
}
