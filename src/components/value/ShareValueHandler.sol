// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {IPositionTracker} from "src/components/value/position-trackers/IPositionTracker.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IShareValueHandler} from "src/interfaces/IShareValueHandler.sol";
import {Shares} from "src/shares/Shares.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";
import {ValueHelpersLib} from "src/utils/ValueHelpersLib.sol";

/// @title ShareValueHandler Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice An IShareValueHandler implementation that aggregates tracked and untracked position values
contract ShareValueHandler is IShareValueHandler, ComponentHelpersMixin {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCast for int256;
    using SafeCast for uint256;

    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 private immutable SHARE_VALUE_HANDLER_STORAGE_LOCATION =
        StorageHelpersLib.deriveErc7201Location("ShareValueHandler");

    /// @custom:storage-location erc7201:enzyme.ShareValueHandler
    struct ShareValueHandlerStorage {
        EnumerableSet.AddressSet positionTrackers;
        uint128 value;
        uint40 valueTimestamp;
    }

    function __getShareValueHandlerStorage() private view returns (ShareValueHandlerStorage storage $) {
        bytes32 location = SHARE_VALUE_HANDLER_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event PositionTrackerAdded(address positionTracker);

    event PositionTrackerRemoved(address positionTracker);

    event ShareValueUpdated(
        uint256 netShareValue, int256 trackedPositionsValue, int256 untrackedPositionsValue, uint256 totalFeesOwed
    );

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error ShareValueHandler__AddPositionTracker__AlreadyAdded();

    error ShareValueHandler__RemovePositionTracker__AlreadyRemoved();

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function addPositionTracker(address _positionTracker) external onlyAdminOrOwner {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();

        bool added = $.positionTrackers.add(_positionTracker);
        require(added, ShareValueHandler__AddPositionTracker__AlreadyAdded());

        emit PositionTrackerAdded(_positionTracker);
    }

    function removePositionTracker(address _positionTracker) external onlyAdminOrOwner {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();

        bool removed = $.positionTrackers.remove(_positionTracker);
        require(removed, ShareValueHandler__RemovePositionTracker__AlreadyRemoved());

        emit PositionTrackerRemoved(_positionTracker);
    }

    //==================================================================================================================
    // Share value updates (access: admin or owner)
    //==================================================================================================================

    /// @dev If no shares exist:
    /// - logic still runs
    /// - FeeManager is still called to settle fees
    /// - lastShareValue is set to 0
    /// Reverts if:
    /// - totalPositionsValue < 0
    /// - totalPositionsValue < totalFeesOwed
    function updateShareValue(int256 _untrackedPositionsValue)
        external
        onlyAdminOrOwner
        returns (uint256 netShareValue_)
    {
        Shares shares = Shares(__getShares());

        // Sum tracked positions
        int256 trackedPositionsValue;
        address[] memory positionTrackers = getPositionTrackers();
        for (uint256 i; i < positionTrackers.length; i++) {
            trackedPositionsValue += IPositionTracker(positionTrackers[i]).getPositionValue();
        }

        // Sum tracked + untracked positions
        uint256 totalPositionsValue = (trackedPositionsValue + _untrackedPositionsValue).toUint256();

        // Settle dynamic fees and get total fees owed
        uint256 totalFeesOwed;
        address feeManager = shares.getFeeManager();
        if (feeManager != address(0)) {
            IFeeManager(feeManager).settleDynamicFees({_totalPositionsValue: totalPositionsValue});
            totalFeesOwed = IFeeManager(feeManager).getTotalValueOwed();
        }

        // Calculate net share value (inclusive of total fees owed)
        uint256 sharesSupply = shares.totalSupply();
        if (sharesSupply > 0) {
            netShareValue_ = ValueHelpersLib.calcValuePerShare({
                _totalValue: totalPositionsValue - totalFeesOwed,
                _totalSharesAmount: sharesSupply
            });
        }
        // else: no shares, netShareValue_ = 0

        // Store share value
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        $.value = netShareValue_.toUint128();
        $.valueTimestamp = uint40(block.timestamp);

        emit ShareValueUpdated({
            netShareValue: netShareValue_,
            trackedPositionsValue: trackedPositionsValue,
            untrackedPositionsValue: _untrackedPositionsValue,
            totalFeesOwed: totalFeesOwed
        });
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    function getPositionTrackers() public view returns (address[] memory) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return $.positionTrackers.values();
    }

    function getShareValue() public view override returns (uint256 value_, uint256 timestamp_) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return ($.value, $.valueTimestamp);
    }

    function isPositionTracker(address _positionTracker) public view returns (bool) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return $.positionTrackers.contains(_positionTracker);
    }
}
