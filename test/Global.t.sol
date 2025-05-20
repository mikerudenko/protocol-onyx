// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Global} from "src/global/Global.sol";

contract GlobalTest is Test {
    address globalOwner;

    function test_init_success() public {
        Global global = new Global();
        address owner = makeAddr("test_init:owner");

        global.init({_owner: owner});

        assertEq(global.owner(), owner);
    }
}
