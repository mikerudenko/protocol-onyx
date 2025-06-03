// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {IPositionTracker} from "src/components/value/position-trackers/IPositionTracker.sol";
import {IChainlinkAggregator} from "src/interfaces/external/IChainlinkAggregator.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IShareValueHandler} from "src/interfaces/IShareValueHandler.sol";
import {Shares} from "src/shares/Shares.sol";
import {VALUE_ASSET_PRECISION} from "src/utils/Constants.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";
import {ValueHelpersLib} from "src/utils/ValueHelpersLib.sol";

/// @title ShareValueHandler Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice An IShareValueHandler implementation that supports share value updates by aggregating
/// untracked (user-input) value and tracked (on-chain) value
contract ShareValueHandler is IShareValueHandler, ComponentHelpersMixin {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCast for int256;
    using SafeCast for uint256;

    //==================================================================================================================
    // Types
    //==================================================================================================================

    struct AssetOracleInfo {
        address oracle;
        bool quotedInValueAsset; // true if, e.g., value asset is USD and oracle is ETH/USD; false if USD/ETH
        uint24 timestampTolerance; // seconds
        uint8 oracleDecimals; // cache
        uint8 assetDecimals; // cache
    }

    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 public immutable SHARE_VALUE_HANDLER_STORAGE_LOCATION =
        StorageHelpersLib.deriveErc7201Location("ShareValueHandler");

    /// @custom:storage-location erc7201:enzyme.ShareValueHandler
    struct ShareValueHandlerStorage {
        EnumerableSet.AddressSet positionTrackers;
        mapping(address => AssetOracleInfo) assetToOracle;
        uint128 lastShareValue;
        uint40 lastShareValueTimestamp;
    }

    function __getShareValueHandlerStorage() internal view returns (ShareValueHandlerStorage storage $) {
        bytes32 location = SHARE_VALUE_HANDLER_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event AssetOracleSet(address asset, address oracle, bool quotedInValueAsset, uint24 timestampTolerance);

    event AssetOracleUnset(address asset);

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

    function setAssetOracle(address _asset, address _oracle, bool _quotedInValueAsset, uint24 _timestampTolerance)
        external
        onlyAdminOrOwner
    {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        $.assetToOracle[_asset] = AssetOracleInfo({
            oracle: _oracle,
            quotedInValueAsset: _quotedInValueAsset,
            timestampTolerance: _timestampTolerance,
            oracleDecimals: IChainlinkAggregator(_oracle).decimals(),
            assetDecimals: IERC20(_asset).decimals()
        });

        emit AssetOracleSet({
            asset: _asset,
            oracle: _oracle,
            quotedInValueAsset: _quotedInValueAsset,
            timestampTolerance: _timestampTolerance
        });
    }

    function unsetAssetOracle(address _asset) external onlyAdminOrOwner {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        delete $.assetToOracle[_asset];

        emit AssetOracleUnset({asset: _asset});
    }

    //==================================================================================================================
    // Valuation
    //==================================================================================================================

    /// @dev Returns 18-decimal precision
    function convertAssetAmountToValue(address _asset, uint256 _assetAmount) public view returns (uint256 value_) {
        AssetOracleInfo memory oracleInfo = getAssetOracleInfo(_asset);

        return ValueHelpersLib.convertToValueAssetWithAggregatorV3({
            _baseAmount: _assetAmount,
            _basePrecision: 10 ** oracleInfo.assetDecimals,
            _oracle: oracleInfo.oracle,
            _oraclePrecision: 10 ** oracleInfo.oracleDecimals,
            _oracleTimestampTolerance: oracleInfo.timestampTolerance,
            _oracleQuotedInValueAsset: oracleInfo.quotedInValueAsset
        });
    }

    /// @dev Returns _asset precision
    function convertValueToAssetAmount(uint256 _value, address _asset) public view returns (uint256 assetAmount_) {
        AssetOracleInfo memory oracleInfo = getAssetOracleInfo(_asset);

        return ValueHelpersLib.convertFromValueAssetWithAggregatorV3({
            _value: _value,
            _quotePrecision: 10 ** oracleInfo.assetDecimals,
            _oracle: oracleInfo.oracle,
            _oraclePrecision: 10 ** oracleInfo.oracleDecimals,
            _oracleTimestampTolerance: oracleInfo.timestampTolerance,
            _oracleQuotedInValueAsset: oracleInfo.quotedInValueAsset
        });
    }

    /// @dev Returns 18-decimal precision
    function getDefaultSharePrice() public pure returns (uint256 sharePrice_) {
        return VALUE_ASSET_PRECISION;
    }

    /// @dev Returns 18-decimal precision.
    /// Returns the price per-share, not value, which is returned by getShareValue().
    function getSharePrice() public view returns (uint256 price_, uint256 timestamp_) {
        uint256 value;
        (value, timestamp_) = getShareValue();

        price_ = value > 0 ? value : getDefaultSharePrice();
    }

    /// @dev Returns _asset precision
    function getSharePriceAsAssetAmount(address _asset)
        public
        view
        returns (uint256 assetAmount_, uint256 timestamp_)
    {
        uint256 value;
        (value, timestamp_) = getSharePrice();

        assetAmount_ = convertValueToAssetAmount({_value: value, _asset: _asset});
    }

    /// @dev Returns 18-decimal precision.
    /// Returns the actual value per share, not the price, which is returned by getSharePrice().
    function getShareValue() public view override returns (uint256 value_, uint256 timestamp_) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return ($.lastShareValue, $.lastShareValueTimestamp);
    }

    //==================================================================================================================
    // Share value updates (access: admin or owner)
    //==================================================================================================================

    /// @dev _untrackedPositionsValue and netShareValue_ are 18-decimal precision.
    /// If no shares exist:
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
        $.lastShareValue = netShareValue_.toUint128();
        $.lastShareValueTimestamp = uint40(block.timestamp);

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

    function getAssetOracleInfo(address _asset) public view returns (AssetOracleInfo memory assetOracleInfo_) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return $.assetToOracle[_asset];
    }

    function getPositionTrackers() public view returns (address[] memory) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return $.positionTrackers.values();
    }

    function isPositionTracker(address _positionTracker) public view returns (bool) {
        ShareValueHandlerStorage storage $ = __getShareValueHandlerStorage();
        return $.positionTrackers.contains(_positionTracker);
    }
}
