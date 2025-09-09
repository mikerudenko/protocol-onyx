// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {Utils} from "@recon/Utils.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";

abstract contract ValuationTargets is
    BaseTargetFunctions,
    Properties
{


    /// CUSTOM TARGET FUNCTIONS - Valuation system interactions ///
    
    /// @dev Convert asset amounts to value using current rates
    function valuation_convertAssetToValue(uint8 assetIndex, uint128 amount) public updateGhosts {
        assetIndex = uint8(_bound(assetIndex, 0, 2));
        amount = uint128(_bound(amount, 1e6, 1e24)); // Reasonable asset amounts
        
        address targetAsset;
        if (assetIndex == 0) targetAsset = address(asset1);
        else if (assetIndex == 1) targetAsset = address(asset2);
        else targetAsset = address(feeAsset);
        
        if (address(valuationHandler) != address(0) && targetAsset != address(0)) {
            try valuationHandler.convertAssetAmountToValue(targetAsset, amount) {} catch {}
        }
    }
    
    /// @dev Convert value to asset amounts using current rates
    function valuation_convertValueToAsset(uint8 assetIndex, uint128 value) public updateGhosts {
        assetIndex = uint8(_bound(assetIndex, 0, 2));
        value = uint128(_bound(value, 1e18, 1e30)); // Value in 18 decimals
        
        address targetAsset;
        if (assetIndex == 0) targetAsset = address(asset1);
        else if (assetIndex == 1) targetAsset = address(asset2);
        else targetAsset = address(feeAsset);
        
        if (address(valuationHandler) != address(0) && targetAsset != address(0)) {
            try valuationHandler.convertValueToAssetAmount(value, targetAsset) {} catch {}
        }
    }
    
    /// @dev Get current share price
    function valuation_getSharePrice() public updateGhosts {
        if (address(valuationHandler) != address(0)) {
            try valuationHandler.getSharePrice() {} catch {}
        }
    }
    
    /// @dev Get default share price
    function valuation_getDefaultSharePrice() public updateGhosts {
        if (address(valuationHandler) != address(0)) {
            valuationHandler.getDefaultSharePrice();
        }
    }
    
    /// @dev Get share value with timestamp
    function valuation_getShareValue() public updateGhosts {
        if (address(valuationHandler) != address(0)) {
            try valuationHandler.getShareValue() {} catch {}
        }
    }
    
    /// @dev Add position tracker to valuation
    function valuation_addPositionTracker(address tracker) public updateGhosts asAdmin {
        // Use existing trackers or create mock addresses
        if (tracker == address(0)) {
            tracker = address(erc20Tracker);
        }
        
        if (address(valuationHandler) != address(0) && tracker != address(0)) {
            try valuationHandler.addPositionTracker(tracker) {} catch {}
        }
    }
    
    /// @dev Remove position tracker from valuation
    function valuation_removePositionTracker(address tracker) public updateGhosts asAdmin {
        if (tracker == address(0)) {
            tracker = address(erc20Tracker);
        }
        
        if (address(valuationHandler) != address(0) && tracker != address(0)) {
            try valuationHandler.removePositionTracker(tracker) {} catch {}
        }
    }
    
    /// @dev Update share value with different untracked positions
    function valuation_updateShareValueWithPositions(int128 untrackedValue) public updateGhosts asAdmin {
        untrackedValue = int128(_boundInt(untrackedValue, -1e24, 1e24));
        
        if (address(valuationHandler) != address(0)) {
            try valuationHandler.updateShareValue(untrackedValue) {} catch {}
        }
    }
    
    /// @dev Set multiple asset rates at once
    function valuation_setMultipleAssetRates(uint128 rate1, uint128 rate2, uint128 rate3) public updateGhosts asAdmin {
        rate1 = uint128(_bound(rate1, 1e15, 1e21));
        rate2 = uint128(_bound(rate2, 1e15, 1e21));
        rate3 = uint128(_bound(rate3, 1e15, 1e21));
        
        if (address(valuationHandler) != address(0)) {
            ValuationHandler.AssetRateInput[] memory inputs = new ValuationHandler.AssetRateInput[](3);
            inputs[0] = ValuationHandler.AssetRateInput({
                asset: address(asset1),
                rate: rate1,
                expiry: uint40(block.timestamp + 1 days)
            });
            inputs[1] = ValuationHandler.AssetRateInput({
                asset: address(asset2),
                rate: rate2,
                expiry: uint40(block.timestamp + 1 days)
            });
            inputs[2] = ValuationHandler.AssetRateInput({
                asset: address(feeAsset),
                rate: rate3,
                expiry: uint40(block.timestamp + 1 days)
            });
            
            try valuationHandler.setAssetRatesThenUpdateShareValue(inputs, 0) {} catch {}
        }
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
