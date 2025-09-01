// SPDX-License-Identifier: BUSL-1.1

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

import {IComponentProxy} from "src/interfaces/IComponentProxy.sol";

contract ComponentHarnessMixin is IComponentProxy {
    address public SHARES;

    constructor(address _shares) {
        SHARES = _shares;
    }
}
