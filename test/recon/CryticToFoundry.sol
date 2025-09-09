// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {Properties} from "./Properties.sol";


// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    /// @dev Override to resolve conflict between StdUtils and Properties
    function _bound(uint256 x, uint256 min, uint256 max) internal pure override(StdUtils, Properties) returns (uint256) {
        return Properties._bound(x, min, max);
    }
    function setUp() public {
        setup();
    }

    // forge test --match-test test_crytic -vvv
    function test_crytic() public {
        // TODO: add failing property tests here for debugging
    }
}