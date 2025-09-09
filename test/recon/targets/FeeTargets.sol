// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {Utils} from "@recon/Utils.sol";

abstract contract FeeTargets is
    BaseTargetFunctions,
    Properties
{


    /// CUSTOM TARGET FUNCTIONS - Fee system interactions ///
    
    /// @dev Settle entrance fees during share minting
    function fee_settleEntranceFee(uint128 grossShares) public updateGhosts asActor {
        grossShares = uint128(_bound(grossShares, 1e18, 1000e18)); // 1 to 1000 shares
        
        if (address(feeHandler) != address(0) && shares.isDepositHandler(address(_getActor()))) {
            try feeHandler.settleEntranceFeeGivenGrossShares(grossShares) {} catch {}
        }
    }
    
    /// @dev Settle exit fees during share burning
    function fee_settleExitFee(uint128 grossShares) public updateGhosts asActor {
        grossShares = uint128(_bound(grossShares, 1e18, 1000e18)); // 1 to 1000 shares
        
        if (address(feeHandler) != address(0) && shares.isRedeemHandler(address(_getActor()))) {
            try feeHandler.settleExitFeeGivenGrossShares(grossShares) {} catch {}
        }
    }
    
    /// @dev Settle dynamic fees (management + performance)
    function fee_settleDynamicFees(uint128 totalPositionsValue) public updateGhosts {
        totalPositionsValue = uint128(_bound(totalPositionsValue, 1e18, 1e30));
        
        if (address(feeHandler) != address(0) && address(valuationHandler) != address(0)) {
            vm.prank(address(valuationHandler));
            try feeHandler.settleDynamicFeesGivenPositionsValue(totalPositionsValue) {} catch {}
        }
    }
    
    /// @dev Settle management fees specifically
    function fee_settleManagementFee(uint128 netValue) public updateGhosts {
        netValue = uint128(_bound(netValue, 1e18, 1e30));
        
        if (address(managementFeeTracker) != address(0)) {
            vm.prank(address(feeHandler));
            try managementFeeTracker.settleManagementFee(netValue) {} catch {}
        }
    }
    
    /// @dev Settle performance fees specifically
    function fee_settlePerformanceFee(uint128 netValue) public updateGhosts {
        netValue = uint128(_bound(netValue, 1e18, 1e30));
        
        if (address(performanceFeeTracker) != address(0)) {
            vm.prank(address(feeHandler));
            try performanceFeeTracker.settlePerformanceFee(netValue) {} catch {}
        }
    }
    
    /// @dev Reset management fee settlement timestamp
    function fee_resetManagementFeeSettlement() public updateGhosts asAdmin {
        if (address(managementFeeTracker) != address(0)) {
            managementFeeTracker.resetLastSettled();
        }
    }
    
    /// @dev Increase value owed to a user (internal fee accounting)
    function fee_increaseValueOwed(address user, uint128 delta) public updateGhosts {
        user = address(uint160(_bound(uint160(user), 1, type(uint160).max)));
        delta = uint128(_bound(delta, 1e15, 1e24)); // Small to large amounts
        
        if (address(feeHandler) != address(0)) {
            vm.prank(address(feeHandler));
            try feeHandler.exposed_increaseValueOwed(user, delta) {} catch {}
        }
    }
    
    /// @dev Decrease value owed to a user (internal fee accounting)
    function fee_decreaseValueOwed(address user, uint128 delta) public updateGhosts {
        user = address(uint160(_bound(uint160(user), 1, type(uint160).max)));
        delta = uint128(_bound(delta, 1e15, 1e24));
        
        if (address(feeHandler) != address(0)) {
            vm.prank(address(feeHandler));
            try feeHandler.exposed_decreaseValueOwed(user, delta) {} catch {}
        }
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
