// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AppendixBZkCases } from "../src/AppendixBZkCases.sol";

contract AppendixBFullZkMultipliersTest {
    AppendixBZkCases internal cases;

    function setUp() public {
        cases = new AppendixBZkCases();
    }

    function testAppendixBPrecompileCases() public {
        cases.runPrecompileCases();
    }

    function testAppendixBOpcodeCases() public {
        cases.runOpcodeCases();
    }

    function testAppendixBAllCasesAreCallableFromScript() public {
        cases.runAll();
    }

    function testAppendixBIndividualCasesAreCallableFromScript() public {
        require(cases.precompileCaseCount() == 17, "unexpected precompile count");
        require(cases.opcodeCaseCount() == 149, "unexpected opcode count");

        cases.runPrecompileCase(0);
        cases.runPrecompileCase(cases.precompileCaseCount() - 1);
        cases.runOpcodeCase(0);
        cases.runOpcodeCase(cases.opcodeCaseCount() - 1);
    }
}
