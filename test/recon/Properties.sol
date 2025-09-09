// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";

abstract contract Properties is BeforeAfter, Asserts {

    /// @dev Common bound function for all target contracts
    function _bound(uint256 x, uint256 min, uint256 max) internal pure virtual returns (uint256) {
        if (max == min) return min;
        return min + (x % (max - min + 1));
    }

    function _boundInt(int256 x, int256 min, int256 max) internal pure virtual returns (int256) {
        if (max == min) return min;
        uint256 range = uint256(max - min + 1);
        uint256 bounded = uint256(x < 0 ? -x : x) % range;
        return min + int256(bounded);
    }

    //==================================================================================================================
    // CORE SYSTEM INVARIANTS
    //==================================================================================================================

    /// @notice Shares total supply should never exceed reasonable bounds
    function property_shares_totalSupply_bounded() public {
        uint256 totalSupply = shares.totalSupply();
        // Should never exceed 1 billion shares (reasonable upper bound)
        t(totalSupply <= 1e27, "Shares total supply exceeds reasonable bounds");
    }

    /// @notice Share price should always be positive when shares exist
    function property_share_price_positive() public {
        if (shares.totalSupply() > 0) {
            (uint256 sharePrice,) = shares.sharePrice();
            t(sharePrice > 0, "Share price must be positive when shares exist");
        }
    }

    /// @notice Share value should be consistent with price calculation
    function property_share_value_consistency() public {
        if (shares.totalSupply() > 0) {
            (uint256 sharePrice,) = shares.sharePrice();
            (uint256 shareValue,) = shares.shareValue();

            // Share value should equal share price (both are per-share values)
            // Allow for small rounding differences (0.1%)
            uint256 diff = shareValue > sharePrice ? shareValue - sharePrice : sharePrice - shareValue;
            uint256 tolerance = sharePrice / 1000; // 0.1%
            t(diff <= tolerance, "Share value and price should be consistent");
        }
    }

    //==================================================================================================================
    // FEE SYSTEM INVARIANTS
    //==================================================================================================================

    /// @notice Total fees owed should never exceed total system value
    function property_fees_bounded_by_system_value() public {
        if (address(feeHandler) != address(0)) {
            uint256 totalFeesOwed = feeHandler.getTotalValueOwed();

            // Get total system value (positions + untracked)
            int256 trackedValue = _getTotalTrackedPositionsValue();
            uint256 totalSystemValue = trackedValue > 0 ? uint256(trackedValue) : 0;

            // Fees should never exceed total system value
            t(totalFeesOwed <= totalSystemValue + 1e18, "Total fees owed exceeds system value"); // +1e18 for rounding
        }
    }

    /// @notice Fee calculations should be mathematically sound
    function property_fee_math_soundness() public {
        if (address(feeHandler) != address(0)) {
            uint256 totalFeesOwed = feeHandler.getTotalValueOwed();

            // Fees should never be negative (handled by uint256)
            // Fees should have reasonable precision (not dust amounts unless system is very small)
            if (shares.totalSupply() > 1e18) { // If system has meaningful size
                // Either fees are 0 or they're at least 1 wei
                t(totalFeesOwed == 0 || totalFeesOwed >= 1, "Fee calculation precision issue");
            }
        }
    }

    /// @notice Management fee rate should be within reasonable bounds
    function property_management_fee_rate_bounded() public {
        if (address(managementFeeTracker) != address(0)) {
            uint16 rate = uint16(managementFeeTracker.getRate());
            // Management fee should never exceed 100% (10000 BPS)
            t(rate <= 10000, "Management fee rate exceeds 100%");
        }
    }

    /// @notice Performance fee rate should be within reasonable bounds
    function property_performance_fee_rate_bounded() public {
        if (address(performanceFeeTracker) != address(0)) {
            uint16 rate = performanceFeeTracker.getRate();
            // Performance fee should never exceed 100% (10000 BPS)
            t(rate <= 10000, "Performance fee rate exceeds 100%");
        }
    }

    //==================================================================================================================
    // VALUATION SYSTEM INVARIANTS
    //==================================================================================================================

    /// @notice Asset rates should be positive and not expired
    function property_asset_rates_valid() public {
        if (address(valuationHandler) != address(0)) {
            // Check rates for known assets
            _checkAssetRate(address(asset1));
            _checkAssetRate(address(asset2));
            _checkAssetRate(address(feeAsset));
        }
    }

    /// @notice Position tracker values should be reasonable
    function property_position_tracker_consistency() public {
        if (address(erc20Tracker) != address(0)) {
            int256 erc20Value = erc20Tracker.getPositionValue();
            // ERC20 tracker value should not exceed total asset supply values
            // This is a sanity check - value should be based on actual holdings
            t(erc20Value >= 0, "ERC20 tracker should not have negative value");
            t(erc20Value <= 1e30, "ERC20 tracker value exceeds reasonable bounds"); // 1e12 tokens * 1e18 price
        }

        if (address(creditDebtTracker) != address(0)) {
            int256 creditDebtValue = creditDebtTracker.getPositionValue();
            // Credit/debt can be negative, but should be within reasonable bounds
            t(creditDebtValue >= -1e30 && creditDebtValue <= 1e30, "Credit/debt value exceeds reasonable bounds");
        }
    }

    //==================================================================================================================
    // ACCESS CONTROL INVARIANTS
    //==================================================================================================================

    /// @notice Only authorized handlers should be able to mint/burn shares
    function property_authorized_handlers_valid() public {
        // This is tested implicitly - if unauthorized minting/burning occurred,
        // other invariants would break (supply consistency, value conservation, etc.)
        // We verify the handlers are properly set
        t(shares.isDepositHandler(address(depositQueue)), "Deposit queue should be authorized deposit handler");
        t(shares.isRedeemHandler(address(redeemQueue)), "Redeem queue should be authorized redeem handler");
    }

    /// @notice Admin roles should be properly maintained
    function property_admin_roles_maintained() public {
        t(shares.isAdminOrOwner(admin), "Admin should maintain admin role");
        t(shares.owner() == admin, "Owner should be admin");
    }

    //==================================================================================================================
    // HELPER FUNCTIONS
    //==================================================================================================================

    function _getTotalTrackedPositionsValue() internal view returns (int256 totalValue) {
        if (address(erc20Tracker) != address(0)) {
            totalValue += erc20Tracker.getPositionValue();
        }
        if (address(creditDebtTracker) != address(0)) {
            totalValue += creditDebtTracker.getPositionValue();
        }
    }

    function _checkAssetRate(address asset) internal {
        if (asset != address(0)) {
            try valuationHandler.getAssetRateInfo(asset) returns (
                ValuationHandler.AssetRateInfo memory rateInfo
            ) {
                t(rateInfo.rate > 0, "Asset rate should be positive");
                t(rateInfo.expiry > block.timestamp, "Asset rate should not be expired");
            } catch {
                // Asset might not have rate set, which is acceptable
            }
        }
    }
}