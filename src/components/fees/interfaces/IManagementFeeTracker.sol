// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

/// @title IManagementFeeTracker Interface
/// @author Enzyme Foundation <security@enzyme.finance>
/// @dev Keep namespaces specific so management and performance fee could be handled by same contract
interface IManagementFeeTracker {
    function settleManagementFee(uint256 _netValue) external returns (uint256 valueDue_);
}
