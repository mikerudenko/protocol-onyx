// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

import {FeeManager} from "src/components/fees/FeeManager.sol";
import {ComponentHarnessMixin} from "test/harnesses/utils/ComponentHarnessMixin.sol";

contract FeeManagerHarness is FeeManager, ComponentHarnessMixin {
    constructor(address _shares) ComponentHarnessMixin(_shares) {}

    function exposed_updateValueOwed(address _user, int256 _delta) external {
        __updateValueOwed({_user: _user, _delta: _delta});
    }
}
