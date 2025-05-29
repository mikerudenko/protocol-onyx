// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <security@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {IChainlinkAggregator} from "src/interfaces/external/IChainlinkAggregator.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";

/// @title ERC7540LikeIssuanceBase Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice A base contract for the common functions of ERC7540-like deposit and redeem handlers
contract ERC7540LikeIssuanceBase is ComponentHelpersMixin {
    struct AssetInfo {
        address asset;
        uint8 assetDecimals; // cache
    }

    struct OracleInfo {
        address oracle; // valueAsset => asset
        uint32 oracleTimestampTolerance; // seconds
        uint8 oracleDecimals; // cache
    }

    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 private immutable ERC7540_LIKE_ISSUANCE_BASE_STORAGE_LOCATION =
        StorageHelpersLib.deriveErc7201Location("ERC7540LikeIssuanceBase");

    /// @custom:storage-location erc7201:enzyme.ERC7540LikeIssuanceBase
    /// @param assetInfo Asset and oracle info
    struct ERC7540LikeIssuanceBaseStorage {
        AssetInfo assetInfo;
        OracleInfo assetOracleInfo;
    }

    function __getERC7540LikeIssuanceBaseStorage() private view returns (ERC7540LikeIssuanceBaseStorage storage $) {
        bytes32 location = ERC7540_LIKE_ISSUANCE_BASE_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event AssetOracleSet(address oracle, uint32 timestampTolerance);

    event AssetSet(address asset);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error ERC7540LikeIssuanceBase__SetAsset__AlreadySet();

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    /// @dev Can only be set once
    function setAsset(address _asset) external onlyAdminOrOwner {
        require(asset() == address(0), ERC7540LikeIssuanceBase__SetAsset__AlreadySet());

        ERC7540LikeIssuanceBaseStorage storage $ = __getERC7540LikeIssuanceBaseStorage();
        $.assetInfo = AssetInfo({asset: _asset, assetDecimals: IERC20(_asset).decimals()});

        emit AssetSet({asset: _asset});
    }

    function setAssetOracle(address _oracle, uint32 _oracleTimestampTolerance) external onlyAdminOrOwner {
        ERC7540LikeIssuanceBaseStorage storage $ = __getERC7540LikeIssuanceBaseStorage();
        $.assetOracleInfo = OracleInfo({
            oracle: _oracle,
            oracleTimestampTolerance: _oracleTimestampTolerance,
            oracleDecimals: IChainlinkAggregator(_oracle).decimals()
        });

        emit AssetOracleSet({oracle: _oracle, timestampTolerance: _oracleTimestampTolerance});
    }

    //==================================================================================================================
    // IERC4626
    //==================================================================================================================

    function asset() public view returns (address asset_) {
        return getAssetInfo().asset;
    }

    //==================================================================================================================
    // IERC7575
    //==================================================================================================================

    function share() public view returns (address share_) {
        return __getShares();
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    /// @notice Gets values used for the asset
    /// @return assetInfo_ The values
    function getAssetInfo() public view returns (AssetInfo memory assetInfo_) {
        return __getERC7540LikeIssuanceBaseStorage().assetInfo;
    }

    /// @notice Gets values used for the asset oracle
    /// @return oracleInfo_ The values
    function getAssetOracleInfo() public view returns (OracleInfo memory oracleInfo_) {
        return __getERC7540LikeIssuanceBaseStorage().assetOracleInfo;
    }
}
