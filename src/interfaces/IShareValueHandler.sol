// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

/// @title IShareValueHandler Interface
/// @author Enzyme Foundation <security@enzyme.finance>
interface IShareValueHandler {
    function getShareValue() external view returns (uint256 value_, uint256 timestamp_);
}
