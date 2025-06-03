// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IManagementFeeTracker} from "src/components/fees/interfaces/IManagementFeeTracker.sol";
import {IPerformanceFeeTracker} from "src/components/fees/interfaces/IPerformanceFeeTracker.sol";
import {ShareValueHandler} from "src/components/value/ShareValueHandler.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {Shares} from "src/shares/Shares.sol";
import {ONE_HUNDRED_PERCENT_BPS} from "src/utils/Constants.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";
import {ValueHelpersLib} from "src/utils/ValueHelpersLib.sol";

/// @title FeeManager Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice Manages fees for a Shares contract
contract FeeManager is IFeeManager, ComponentHelpersMixin {
    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 private immutable FEE_MANAGER_STORAGE_LOCATION = StorageHelpersLib.deriveErc7201Location("FeeManager");

    /// @custom:storage-location erc7201:enzyme.FeeManager
    struct FeeManagerStorage {
        address managementFeeTracker;
        address performanceFeeTracker;
        address managementFeeRecipient; // cannot be address(0)
        address performanceFeeRecipient; // cannot be address(0)
        address entranceFeeRecipient; // "burned" if address(0)
        uint16 entranceFeeBps;
        address exitFeeRecipient; // "burned" if address(0)
        uint16 exitFeeBps;
        address feeAsset;
        uint256 totalFeesOwed;
        mapping(address => uint256) userFeesOwed;
    }

    function __getFeeManagerStorage() private view returns (FeeManagerStorage storage $) {
        bytes32 location = FEE_MANAGER_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event EntranceFeeSet(uint16 feeBps, address recipient);

    event EntranceFeeSettled(address recipient, uint256 value);

    event ExitFeeSet(uint16 feeBps, address recipient);

    event ExitFeeSettled(address recipient, uint256 value);

    event FeeAssetSet(address asset);

    event FeesClaimed(address caller, address onBehalf, uint256 value, address feeAsset, uint256 feeAssetAmount);

    event ManagementFeeSet(address managementFeeTracker, address recipient);

    event ManagementFeeSettled(address recipient, uint256 value);

    event PerformanceFeeSet(address performanceFeeTracker, address recipient);

    event PerformanceFeeSettled(address recipient, uint256 value);

    event TotalValueOwedUpdated(uint256 value);

    event UserValueOwedUpdated(address user, uint256 value);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error FeeManager__ClaimFees__Unauthorized();

    error FeeManager__ClaimFees__ZeroFeeAsset();

    error FeeManager__SetEntranceFee__ExceedsMax();

    error FeeManager__SetExitFee__ExceedsMax();

    error FeeManager__SetManagementFee__RecipientZeroAddress();

    error FeeManager__SetPerformanceFee__RecipientZeroAddress();

    error FeeManager__SettleDynamicFees__Unauthorized();

    //==================================================================================================================
    // Config (access: Shares admin or owner)
    //==================================================================================================================

    function setEntranceFee(uint16 _feeBps, address _recipient) external onlyAdminOrOwner {
        require(_feeBps < ONE_HUNDRED_PERCENT_BPS, FeeManager__SetEntranceFee__ExceedsMax());

        FeeManagerStorage storage $ = __getFeeManagerStorage();
        $.entranceFeeBps = _feeBps;
        $.entranceFeeRecipient = _recipient;

        emit EntranceFeeSet({feeBps: _feeBps, recipient: _recipient});
    }

    function setExitFee(uint16 _feeBps, address _recipient) external onlyAdminOrOwner {
        require(_feeBps < ONE_HUNDRED_PERCENT_BPS, FeeManager__SetExitFee__ExceedsMax());

        FeeManagerStorage storage $ = __getFeeManagerStorage();
        $.exitFeeBps = _feeBps;
        $.exitFeeRecipient = _recipient;

        emit ExitFeeSet({feeBps: _feeBps, recipient: _recipient});
    }

    function setFeeAsset(address _asset) external onlyAdminOrOwner {
        FeeManagerStorage storage $ = __getFeeManagerStorage();
        $.feeAsset = _asset;

        emit FeeAssetSet({asset: _asset});
    }

    /// @dev _managementFeeTracker can be empty (to disable)
    /// _recipient cannot be empty (unused if disabled)
    function setManagementFee(address _managementFeeTracker, address _recipient) external onlyAdminOrOwner {
        require(_recipient != address(0), FeeManager__SetManagementFee__RecipientZeroAddress());

        FeeManagerStorage storage $ = __getFeeManagerStorage();
        $.managementFeeTracker = _managementFeeTracker;
        $.managementFeeRecipient = _recipient;

        emit ManagementFeeSet({managementFeeTracker: address(_managementFeeTracker), recipient: _recipient});
    }

    /// @dev _performanceFeeTracker can be empty (to disable)
    /// _recipient cannot be empty (unused if disabled)
    function setPerformanceFee(address _performanceFeeTracker, address _recipient) external onlyAdminOrOwner {
        require(_recipient != address(0), FeeManager__SetPerformanceFee__RecipientZeroAddress());

        FeeManagerStorage storage $ = __getFeeManagerStorage();
        $.performanceFeeTracker = _performanceFeeTracker;
        $.performanceFeeRecipient = _recipient;

        emit PerformanceFeeSet({performanceFeeTracker: address(_performanceFeeTracker), recipient: _recipient});
    }

    //==================================================================================================================
    // Claim Fees (access: anybody)
    //==================================================================================================================

    /// @dev Only callable by owed user or admin
    function claimFees(address _onBehalf, uint256 _value) external returns (uint256 feeAssetAmount_) {
        require(msg.sender == _onBehalf || __isAdminOrOwner(msg.sender), FeeManager__ClaimFees__Unauthorized());
        // `_value > owed` reverts in __updateValueOwed()

        Shares shares = Shares(__getShares());
        ShareValueHandler shareValueHandler = ShareValueHandler(shares.getShareValueHandler());
        address feeAsset = getFeeAsset();

        feeAssetAmount_ = shareValueHandler.convertValueToAssetAmount({_value: _value, _asset: feeAsset});
        require(feeAssetAmount_ > 0, FeeManager__ClaimFees__ZeroFeeAsset());

        __updateValueOwed({_user: _onBehalf, _delta: -int256(_value)});

        Shares(__getShares()).withdrawFeeAssetTo({_asset: feeAsset, _to: _onBehalf, _amount: feeAssetAmount_});

        emit FeesClaimed({
            caller: msg.sender,
            onBehalf: _onBehalf,
            value: _value,
            feeAsset: feeAsset,
            feeAssetAmount: feeAssetAmount_
        });
    }

    //==================================================================================================================
    // Settle Fees (access: mixed)
    //==================================================================================================================

    /// @dev Callable by: ShareValueHandler
    function settleDynamicFees(uint256 _totalPositionsValue) external override {
        require(
            msg.sender == Shares(__getShares()).getShareValueHandler(), FeeManager__SettleDynamicFees__Unauthorized()
        );

        // Deduct unclaimed fees
        uint256 netValue = _totalPositionsValue - getTotalValueOwed();

        uint256 managementFeeAmount;
        if (getManagementFeeTracker() != address(0)) {
            managementFeeAmount =
                IManagementFeeTracker(getManagementFeeTracker()).settleManagementFee({_netValue: netValue});

            __updateValueOwed({_user: getManagementFeeRecipient(), _delta: int256(managementFeeAmount)});

            emit ManagementFeeSettled({recipient: getManagementFeeRecipient(), value: managementFeeAmount});
        }

        uint256 performanceFeeAmount;
        if (getPerformanceFeeTracker() != address(0)) {
            // Deduct management fee
            netValue -= managementFeeAmount;

            performanceFeeAmount =
                IPerformanceFeeTracker(getPerformanceFeeTracker()).settlePerformanceFee({_netValue: netValue});

            __updateValueOwed({_user: getPerformanceFeeRecipient(), _delta: int256(performanceFeeAmount)});

            emit PerformanceFeeSettled({recipient: getPerformanceFeeRecipient(), value: performanceFeeAmount});
        }
    }

    function settleEntranceFee(uint256 _grossSharesAmount)
        external
        override
        onlyShares
        returns (uint256 feeSharesAmount_)
    {
        return __settleEntranceExitFee({_grossSharesAmount: _grossSharesAmount, _isEntrance: true});
    }

    function settleExitFee(uint256 _grossSharesAmount)
        external
        override
        onlyShares
        returns (uint256 feeSharesAmount_)
    {
        return __settleEntranceExitFee({_grossSharesAmount: _grossSharesAmount, _isEntrance: false});
    }

    // INTERNAL

    function __calcEntranceExitFee(uint256 _grossSharesAmount, uint16 _feeBps)
        internal
        pure
        returns (uint256 feeShares_)
    {
        return (_grossSharesAmount * _feeBps) / ONE_HUNDRED_PERCENT_BPS;
    }

    function __settleEntranceExitFee(uint256 _grossSharesAmount, bool _isEntrance)
        internal
        returns (uint256 feeSharesAmount_)
    {
        (uint16 feeBps, address recipient) =
            _isEntrance ? (getEntranceFeeBps(), getEntranceFeeRecipient()) : (getExitFeeBps(), getExitFeeRecipient());
        if (feeBps == 0) return 0;

        feeSharesAmount_ = __calcEntranceExitFee({_grossSharesAmount: _grossSharesAmount, _feeBps: feeBps});
        if (feeSharesAmount_ == 0) return 0;

        // Query "share price" rather than "share value", for case of no shares supply on mint
        (uint256 sharePrice,) = Shares(__getShares()).sharePrice();
        uint256 value =
            ValueHelpersLib.calcValueOfSharesAmount({_valuePerShare: sharePrice, _sharesAmount: feeSharesAmount_});

        if (recipient != address(0)) {
            __updateValueOwed({_user: recipient, _delta: int256(value)});
        }
        // Effectively "burn" the fee if no recipient, as shares will be destroyed but no value owed

        if (_isEntrance) {
            emit EntranceFeeSettled({recipient: recipient, value: value});
        } else {
            emit ExitFeeSettled({recipient: recipient, value: value});
        }
    }

    //==================================================================================================================
    // Helpers
    //==================================================================================================================

    function __updateValueOwed(address _user, int256 _delta) internal {
        uint256 userValueOwed = uint256(int256(getValueOwedToUser(_user)) + _delta);
        uint256 totalValueOwed = uint256(int256(getTotalValueOwed()) + _delta);

        FeeManagerStorage storage $ = __getFeeManagerStorage();
        $.userFeesOwed[_user] = userValueOwed;
        $.totalFeesOwed = totalValueOwed;

        emit UserValueOwedUpdated({user: _user, value: userValueOwed});
        emit TotalValueOwedUpdated({value: totalValueOwed});
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    function getEntranceFeeBps() public view returns (uint16 entranceFeeBps_) {
        return __getFeeManagerStorage().entranceFeeBps;
    }

    function getEntranceFeeRecipient() public view returns (address entranceFeeRecipient_) {
        return __getFeeManagerStorage().entranceFeeRecipient;
    }

    function getExitFeeBps() public view returns (uint16 exitFeeBps_) {
        return __getFeeManagerStorage().exitFeeBps;
    }

    function getExitFeeRecipient() public view returns (address exitFeeRecipient_) {
        return __getFeeManagerStorage().exitFeeRecipient;
    }

    function getFeeAsset() public view returns (address feeAsset_) {
        return __getFeeManagerStorage().feeAsset;
    }

    function getManagementFeeRecipient() public view returns (address managementFeeRecipient_) {
        return __getFeeManagerStorage().managementFeeRecipient;
    }

    function getManagementFeeTracker() public view returns (address managementFeeTracker_) {
        return __getFeeManagerStorage().managementFeeTracker;
    }

    function getPerformanceFeeRecipient() public view returns (address performanceFeeRecipient_) {
        return __getFeeManagerStorage().performanceFeeRecipient;
    }

    function getPerformanceFeeTracker() public view returns (address performanceFeeTracker_) {
        return __getFeeManagerStorage().performanceFeeTracker;
    }

    function getTotalValueOwed() public view override returns (uint256 totalValueOwed_) {
        return __getFeeManagerStorage().totalFeesOwed;
    }

    function getValueOwedToUser(address _user) public view returns (uint256 valueOwed_) {
        return __getFeeManagerStorage().userFeesOwed[_user];
    }
}
