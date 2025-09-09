// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";
import {ERC7540LikeDepositQueue} from "src/components/issuance/deposit-handlers/ERC7540LikeDepositQueue.sol";
import {Panic} from "@recon/Panic.sol";
import {Utils} from "@recon/Utils.sol";

abstract contract IssuanceTargets is
    BaseTargetFunctions,
    Properties
{


    /// CUSTOM TARGET FUNCTIONS - Issuance system interactions ///
    
    /// @dev Request deposit through deposit queue
    function issuance_requestDeposit(uint128 assetAmount) public updateGhosts asActor {
        assetAmount = uint128(_bound(assetAmount, 1e18, 100e18)); // 1 to 100 tokens
        
        if (address(depositQueue) != address(0) && address(asset1) != address(0)) {
            address actor = address(_getActor());
            
            // Ensure actor has assets and approval
            vm.prank(testAccount);
            asset1.transfer(actor, assetAmount);
            
            vm.prank(actor);
            asset1.approve(address(depositQueue), assetAmount);
            
            vm.prank(actor);
            try depositQueue.requestDeposit(assetAmount, actor, actor) {} catch {}
        }
    }
    
    /// @dev Execute pending deposit requests
    function issuance_executeDepositRequests(uint256 maxRequests) public updateGhosts asAdmin {
        maxRequests = _bound(maxRequests, 1, 10);
        
        if (address(depositQueue) != address(0)) {
            // Create array of request IDs (simplified - would need to track actual IDs)
            uint256[] memory requestIds = new uint256[](maxRequests);
            for (uint256 i = 0; i < maxRequests; i++) {
                requestIds[i] = i + 1; // Assuming sequential IDs
            }
            
            try depositQueue.executeDepositRequests(requestIds) {} catch {}
        }
    }
    
    /// @dev Cancel a deposit request
    function issuance_cancelDeposit(uint256 requestId) public updateGhosts asActor {
        requestId = _bound(requestId, 1, 100);
        
        if (address(depositQueue) != address(0)) {
            try depositQueue.cancelDeposit(requestId) {} catch {}
        }
    }
    
    /// @dev Request redemption through redeem queue
    function issuance_requestRedeem(uint128 sharesAmount) public updateGhosts asActor {
        sharesAmount = uint128(_bound(sharesAmount, 1e18, 100e18)); // 1 to 100 shares
        
        if (address(redeemQueue) != address(0)) {
            address actor = address(_getActor());
            
            // Ensure actor has shares
            if (shares.balanceOf(actor) < sharesAmount) {
                vm.prank(admin);
                shares.mintFor(actor, sharesAmount);
            }
            
            vm.prank(actor);
            shares.approve(address(redeemQueue), sharesAmount);
            
            vm.prank(actor);
            try redeemQueue.requestRedeem(sharesAmount, actor, actor) {} catch {}
        }
    }
    
    /// @dev Execute pending redeem requests
    function issuance_executeRedeemRequests(uint256 maxRequests) public updateGhosts asAdmin {
        maxRequests = _bound(maxRequests, 1, 10);
        
        if (address(redeemQueue) != address(0)) {
            uint256[] memory requestIds = new uint256[](maxRequests);
            for (uint256 i = 0; i < maxRequests; i++) {
                requestIds[i] = i + 1;
            }
            
            try redeemQueue.executeRedeemRequests(requestIds) {} catch {}
        }
    }
    
    /// @dev Cancel a redeem request
    function issuance_cancelRedeem(uint256 requestId) public updateGhosts asActor {
        requestId = _bound(requestId, 1, 100);
        
        if (address(redeemQueue) != address(0)) {
            try redeemQueue.cancelRedeem(requestId) {} catch {}
        }
    }
    
    /// @dev Direct mint for testing (admin only)
    function issuance_mintShares(address to, uint128 amount) public updateGhosts asAdmin {
        to = address(uint160(_bound(uint160(to), 1, type(uint160).max)));
        amount = uint128(_bound(amount, 1e18, 1000e18));
        
        shares.mintFor(to, amount);
    }
    
    /// @dev Direct burn for testing (admin only)
    function issuance_burnShares(address from, uint128 amount) public updateGhosts asAdmin {
        from = address(uint160(_bound(uint160(from), 1, type(uint160).max)));
        amount = uint128(_bound(amount, 1e18, 1000e18));
        
        uint256 balance = shares.balanceOf(from);
        if (balance >= amount) {
            shares.burnFor(from, amount);
        }
    }
    
    /// @dev Set deposit restrictions
    function issuance_setDepositRestriction(uint8 restriction) public updateGhosts asAdmin {
        restriction = uint8(_bound(restriction, 0, 1)); // 0=None, 1=ControllerAllowlist

        if (address(depositQueue) != address(0)) {
            if (restriction == 0) {
                try depositQueue.setDepositRestriction(ERC7540LikeDepositQueue.DepositRestriction.None) {} catch {}
            } else {
                try depositQueue.setDepositRestriction(ERC7540LikeDepositQueue.DepositRestriction.ControllerAllowlist) {} catch {}
            }
        }
    }
    
    /// @dev Add allowed controller for deposits
    function issuance_addAllowedController(address controller) public updateGhosts asAdmin {
        controller = address(uint160(_bound(uint160(controller), 1, type(uint160).max)));
        
        if (address(depositQueue) != address(0)) {
            try depositQueue.addAllowedController(controller) {} catch {}
        }
    }
    
    /// @dev Set minimum request duration for deposits
    function issuance_setDepositMinRequestDuration(uint32 duration) public updateGhosts asAdmin {
        duration = uint32(_bound(duration, 1 hours, 7 days));
        
        if (address(depositQueue) != address(0)) {
            try depositQueue.setDepositMinRequestDuration(uint24(duration)) {} catch {}
        }
    }
    
    /// @dev Set minimum request duration for redeems
    function issuance_setRedeemMinRequestDuration(uint32 duration) public updateGhosts asAdmin {
        duration = uint32(_bound(duration, 1 hours, 7 days));
        
        if (address(redeemQueue) != address(0)) {
            try redeemQueue.setRedeemMinRequestDuration(uint24(duration)) {} catch {}
        }
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
