// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

/// @title IFeeHandler Interface
/// @author Enzyme Foundation <security@enzyme.finance>
interface IFeeHandler {
    function getTotalValueOwed() external view returns (uint256 totalValueOwed_);

    function settleDynamicFees(uint256 _totalPositionsValue) external;

    function settleEntranceFee(uint256 _grossSharesAmount) external returns (uint256 feeShares_);

    function settleExitFee(uint256 _grossSharesAmount) external returns (uint256 feeShares_);
}
