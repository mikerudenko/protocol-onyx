// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";

abstract contract AdminTargets is
    BaseTargetFunctions,
    Properties
{


    /// CUSTOM TARGET FUNCTIONS - Admin actions for state exploration ///

    /// @dev Change management fee rate to explore different fee scenarios
    function admin_setManagementFeeRate(uint16 newRate) public updateGhosts asAdmin {
        newRate = uint16(_bound(newRate, 0, 2000)); // 0-20% max

        if (address(managementFeeTracker) != address(0)) {
            managementFeeTracker.setRate(newRate);
        }
    }

    /// @dev Change performance fee rate to explore different fee scenarios
    function admin_setPerformanceFeeRate(uint16 newRate) public updateGhosts asAdmin {
        newRate = uint16(_bound(newRate, 0, 5000)); // 0-50% max

        if (address(performanceFeeTracker) != address(0)) {
            performanceFeeTracker.setRate(newRate);
        }
    }

    /// @dev Reset performance fee high water mark to explore different scenarios
    function admin_resetPerformanceHWM() public updateGhosts asAdmin {
        if (address(performanceFeeTracker) != address(0)) {
            performanceFeeTracker.resetHighWaterMark();
        }
    }

    /// @dev Change asset rates to explore valuation scenarios
    function admin_updateAssetRate(uint8 assetIndex, uint128 newRate) public updateGhosts asAdmin {
        newRate = uint128(_bound(newRate, 1e15, 1e21)); // 0.001 to 1000 USD per unit
        assetIndex = uint8(_bound(assetIndex, 0, 2));

        address targetAsset;
        if (assetIndex == 0) targetAsset = address(asset1);
        else if (assetIndex == 1) targetAsset = address(asset2);
        else targetAsset = address(feeAsset);

        if (address(valuationHandler) != address(0) && targetAsset != address(0)) {
            valuationHandler.setAssetRate(ValuationHandler.AssetRateInput({
                asset: targetAsset,
                rate: newRate,
                expiry: uint40(block.timestamp + 1 days)
            }));
        }
    }

    /// @dev Update share value with untracked positions to explore valuation scenarios
    function admin_updateShareValue(int128 untrackedValue) public updateGhosts asAdmin {
        untrackedValue = int128(_boundInt(untrackedValue, -1e24, 1e24)); // Reasonable bounds

        if (address(valuationHandler) != address(0)) {
            valuationHandler.updateShareValue(untrackedValue);
        }
    }

    /// @dev Add credit/debt items to explore linear tracker scenarios
    function admin_addCreditDebtItem(int128 totalValue, uint32 duration) public updateGhosts asAdmin {
        totalValue = int128(_boundInt(totalValue, -1e24, 1e24));
        duration = uint32(_bound(duration, 1 days, 365 days));

        if (address(creditDebtTracker) != address(0)) {
            creditDebtTracker.addItem(totalValue, uint40(block.timestamp), duration, "Admin test item");
        }
    }

    /// @dev Set entrance fee to explore fee scenarios
    function admin_setEntranceFee(uint16 feeBps) public updateGhosts asAdmin {
        feeBps = uint16(_bound(feeBps, 0, 1000)); // 0-10% max

        if (address(feeHandler) != address(0)) {
            feeHandler.setEntranceFee(feeBps, feeRecipient);
        }
    }

    /// @dev Set exit fee to explore fee scenarios
    function admin_setExitFee(uint16 feeBps) public updateGhosts asAdmin {
        feeBps = uint16(_bound(feeBps, 0, 1000)); // 0-10% max

        if (address(feeHandler) != address(0)) {
            feeHandler.setExitFee(feeBps, feeRecipient);
        }
    }

    /// @dev Claim fees to explore fee distribution scenarios
    function admin_claimFees(uint128 valueAmount) public updateGhosts asAdmin {
        if (address(feeHandler) != address(0)) {
            uint256 totalOwed = feeHandler.getTotalValueOwed();
            if (totalOwed > 0) {
                valueAmount = uint128(_bound(valueAmount, 1, totalOwed));
                feeHandler.claimFees(feeRecipient, valueAmount);
            }
        }
    }

    /// @dev Time manipulation to explore time-dependent behaviors
    function admin_warpTime(uint32 timeIncrease) public updateGhosts {
        timeIncrease = uint32(_bound(timeIncrease, 1 hours, 30 days));
        vm.warp(block.timestamp + timeIncrease);
    }

    /// @dev Add assets to ERC20 tracker to explore multi-asset scenarios
    function admin_addTrackedAsset() public updateGhosts asAdmin {
        if (address(erc20Tracker) != address(0)) {
            // Try to add asset2 if not already added
            try erc20Tracker.addAsset(address(asset2)) {} catch {}
        }
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}