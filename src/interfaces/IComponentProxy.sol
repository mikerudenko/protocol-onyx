// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

/// @title IComponentProxy Interface
/// @author Enzyme Foundation <security@enzyme.finance>
interface IComponentProxy {
    function SHARES() external view returns (address);
}
