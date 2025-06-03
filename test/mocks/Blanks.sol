// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

/// @dev This file contains "blank" interface implementations, i.e., with no logic.
/// To be used in conjunction with mocked calls in tests.

import {IManagementFeeTracker} from "src/components/fees/interfaces/IManagementFeeTracker.sol";
import {IPerformanceFeeTracker} from "src/components/fees/interfaces/IPerformanceFeeTracker.sol";
import {IPositionTracker} from "src/components/value/position-trackers/IPositionTracker.sol";
import {IFeeHandler} from "src/interfaces/IFeeHandler.sol";

contract BlankFeeHandler is IFeeHandler {
    function getTotalValueOwed() external view returns (uint256 totalValueOwed_) {}

    function settleDynamicFees(uint256 _totalPositionsValue) external {}

    function settleEntranceFee(uint256 _grossSharesAmount) external returns (uint256 feeShares_) {}

    function settleExitFee(uint256 _grossSharesAmount) external returns (uint256 feeShares_) {}
}

contract BlankManagementFeeTracker is IManagementFeeTracker {
    function settleManagementFee(uint256 _netValue) external returns (uint256 valueDue_) {}
}

contract BlankPerformanceFeeTracker is IPerformanceFeeTracker {
    function settlePerformanceFee(uint256 _netValue) external returns (uint256 valueDue_) {}
}

contract BlankPositionTracker is IPositionTracker {
    function getPositionValue() external view returns (int256 value_) {}
}
