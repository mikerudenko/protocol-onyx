// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";
import {Utils} from "@recon/Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/shares/Shares.sol";

abstract contract SharesTargets is
    BaseTargetFunctions,
    Properties
{


    /// CUSTOM TARGET FUNCTIONS - Meaningful shares interactions ///

    /// @dev Transfer shares between actors
    function shares_transferBetweenActors(uint128 amount) public updateGhosts asActor {
        amount = uint128(_bound(amount, 1e15, 1000e18)); // Small to large amounts
        address from = address(_getActor());
        address to = address(uint160(_bound(uint160(from) + 1, 1, type(uint160).max)));

        uint256 balance = shares.balanceOf(from);
        if (balance >= amount) {
            shares.transfer(to, amount);
        }
    }

    /// @dev Approve and transferFrom pattern
    function shares_approveAndTransferFrom(uint128 amount) public updateGhosts asActor {
        amount = uint128(_bound(amount, 1e15, 1000e18));
        address owner = address(_getActor());
        address spender = address(uint160(_bound(uint160(owner) + 1, 1, type(uint160).max)));
        address to = address(uint160(_bound(uint160(owner) + 2, 1, type(uint160).max)));

        uint256 balance = shares.balanceOf(owner);
        if (balance >= amount) {
            shares.approve(spender, amount);

            vm.prank(spender);
            shares.transferFrom(owner, to, amount);
        }
    }

    /// @dev Authorized transfer (by deposit/redeem handlers)
    function shares_authTransferAsHandler(uint128 amount) public updateGhosts {
        amount = uint128(_bound(amount, 1e15, 1000e18));
        address from = address(_getActor());
        address to = address(uint160(_bound(uint160(from) + 1, 1, type(uint160).max)));

        // Use deposit handler for auth transfer
        if (shares.isDepositHandler(address(depositQueue))) {
            uint256 balance = shares.balanceOf(from);
            if (balance >= amount) {
                vm.prank(address(depositQueue));
                shares.authTransfer(to, amount);
            }
        }
    }

    /// @dev Withdraw assets from shares contract
    function shares_withdrawAsset(uint8 assetIndex, uint128 amount) public updateGhosts asAdmin {
        assetIndex = uint8(_bound(assetIndex, 0, 2));
        amount = uint128(_bound(amount, 1e15, 1000e18));

        address targetAsset;
        if (assetIndex == 0) targetAsset = address(asset1);
        else if (assetIndex == 1) targetAsset = address(asset2);
        else targetAsset = address(feeAsset);

        if (targetAsset != address(0)) {
            uint256 balance = IERC20(targetAsset).balanceOf(address(shares));
            if (balance >= amount) {
                shares.withdrawAssetTo(targetAsset, admin, amount);
            }
        }
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function shares_acceptOwnership() public asActor {
        shares.acceptOwnership();
    }

    function shares_addAdmin(address _admin) public asActor {
        shares.addAdmin(_admin);
    }

    function shares_addDepositHandler(address _handler) public asActor {
        shares.addDepositHandler(_handler);
    }

    function shares_addRedeemHandler(address _handler) public asActor {
        shares.addRedeemHandler(_handler);
    }

    function shares_approve(address spender, uint256 value) public asActor {
        shares.approve(spender, value);
    }

    function shares_authTransfer(address _to, uint256 _amount) public asActor {
        shares.authTransfer(_to, _amount);
    }

    function shares_authTransferFrom(address _from, address _to, uint256 _amount) public asActor {
        shares.authTransferFrom(_from, _to, _amount);
    }

    function shares_burnFor(address _from, uint256 _sharesAmount) public asActor {
        shares.burnFor(_from, _sharesAmount);
    }

    function shares_init(address _owner, string memory _name, string memory _symbol, bytes32 _valueAsset) public asActor {
        shares.init(_owner, _name, _symbol, _valueAsset);
    }

    function shares_mintFor(address _to, uint256 _sharesAmount) public asActor {
        shares.mintFor(_to, _sharesAmount);
    }

    function shares_removeAdmin(address _admin) public asActor {
        shares.removeAdmin(_admin);
    }

    function shares_removeDepositHandler(address _handler) public asActor {
        shares.removeDepositHandler(_handler);
    }

    function shares_removeRedeemHandler(address _handler) public asActor {
        shares.removeRedeemHandler(_handler);
    }

    function shares_renounceOwnership() public asActor {
        shares.renounceOwnership();
    }

    function shares_setFeeHandler(address _feeHandler) public asActor {
        shares.setFeeHandler(_feeHandler);
    }

    function shares_setSharesTransferValidator(address _sharesTransferValidator) public asActor {
        shares.setSharesTransferValidator(_sharesTransferValidator);
    }

    function shares_setValuationHandler(address _valuationHandler) public asActor {
        shares.setValuationHandler(_valuationHandler);
    }

    function shares_transfer(address _to, uint256 _amount) public asActor {
        shares.transfer(_to, _amount);
    }

    function shares_transferFrom(address _from, address _to, uint256 _amount) public asActor {
        shares.transferFrom(_from, _to, _amount);
    }

    function shares_transferOwnership(address newOwner) public asActor {
        shares.transferOwnership(newOwner);
    }

    function shares_withdrawAssetTo(address _asset, address _to, uint256 _amount) public asActor {
        shares.withdrawAssetTo(_asset, _to, _amount);
    }
}