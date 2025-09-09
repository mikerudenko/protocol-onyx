// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    struct Vars {
        // Core system state
        uint256 sharesTotalSupply;
        uint256 sharesPrice;
        uint256 sharesValue;

        // Fee system state
        uint256 totalFeesOwed;
        uint256 managementFeeRate;
        uint256 performanceFeeRate;
        uint256 performanceHWM;

        // Position values
        int256 erc20TrackerValue;
        int256 creditDebtTrackerValue;
        int256 totalTrackedValue;

        // Asset balances (for conservation checks)
        uint256 asset1Balance_testAccount;
        uint256 asset2Balance_testAccount;
        uint256 asset1Balance_shares;
        uint256 asset2Balance_shares;
        uint256 feeAssetBalance_feeHandler;

        // System configuration
        address currentFeeHandler;
        address currentValuationHandler;
        bool isSystemInitialized;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts {
        __before();
        _;
        __after();
    }

    function __before() internal {
        _before.sharesTotalSupply = shares.totalSupply();

        if (_before.sharesTotalSupply > 0) {
            (_before.sharesPrice,) = shares.sharePrice();
            (_before.sharesValue,) = shares.shareValue();
        }

        // Fee system state
        if (address(feeHandler) != address(0)) {
            _before.totalFeesOwed = feeHandler.getTotalValueOwed();
            _before.currentFeeHandler = address(feeHandler);
        }

        if (address(managementFeeTracker) != address(0)) {
            _before.managementFeeRate = managementFeeTracker.getRate();
        }

        if (address(performanceFeeTracker) != address(0)) {
            _before.performanceFeeRate = performanceFeeTracker.getRate();
            _before.performanceHWM = performanceFeeTracker.getHighWaterMark();
        }

        // Position values
        if (address(erc20Tracker) != address(0)) {
            _before.erc20TrackerValue = erc20Tracker.getPositionValue();
        }

        if (address(creditDebtTracker) != address(0)) {
            _before.creditDebtTrackerValue = creditDebtTracker.getPositionValue();
        }

        _before.totalTrackedValue = _before.erc20TrackerValue + _before.creditDebtTrackerValue;

        // Asset balances
        _before.asset1Balance_testAccount = asset1.balanceOf(testAccount);
        _before.asset2Balance_testAccount = asset2.balanceOf(testAccount);
        _before.asset1Balance_shares = asset1.balanceOf(address(shares));
        _before.asset2Balance_shares = asset2.balanceOf(address(shares));
        _before.feeAssetBalance_feeHandler = feeAsset.balanceOf(address(feeHandler));

        // System configuration
        _before.currentValuationHandler = shares.getValuationHandler();
        _before.isSystemInitialized = (
            address(shares) != address(0) &&
            _before.currentValuationHandler != address(0) &&
            _before.currentFeeHandler != address(0)
        );
    }

    function __after() internal {
        _after.sharesTotalSupply = shares.totalSupply();

        if (_after.sharesTotalSupply > 0) {
            (_after.sharesPrice,) = shares.sharePrice();
            (_after.sharesValue,) = shares.shareValue();
        }

        // Fee system state
        if (address(feeHandler) != address(0)) {
            _after.totalFeesOwed = feeHandler.getTotalValueOwed();
            _after.currentFeeHandler = address(feeHandler);
        }

        if (address(managementFeeTracker) != address(0)) {
            _after.managementFeeRate = managementFeeTracker.getRate();
        }

        if (address(performanceFeeTracker) != address(0)) {
            _after.performanceFeeRate = performanceFeeTracker.getRate();
            _after.performanceHWM = performanceFeeTracker.getHighWaterMark();
        }

        // Position values
        if (address(erc20Tracker) != address(0)) {
            _after.erc20TrackerValue = erc20Tracker.getPositionValue();
        }

        if (address(creditDebtTracker) != address(0)) {
            _after.creditDebtTrackerValue = creditDebtTracker.getPositionValue();
        }

        _after.totalTrackedValue = _after.erc20TrackerValue + _after.creditDebtTrackerValue;

        // Asset balances
        _after.asset1Balance_testAccount = asset1.balanceOf(testAccount);
        _after.asset2Balance_testAccount = asset2.balanceOf(testAccount);
        _after.asset1Balance_shares = asset1.balanceOf(address(shares));
        _after.asset2Balance_shares = asset2.balanceOf(address(shares));
        _after.feeAssetBalance_feeHandler = feeAsset.balanceOf(address(feeHandler));

        // System configuration
        _after.currentValuationHandler = shares.getValuationHandler();
        _after.isSystemInitialized = (
            address(shares) != address(0) &&
            _after.currentValuationHandler != address(0) &&
            _after.currentFeeHandler != address(0)
        );
    }
}