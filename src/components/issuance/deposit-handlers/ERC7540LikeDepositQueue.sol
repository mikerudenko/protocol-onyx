// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <security@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC7540LikeDepositHandler} from "src/components/issuance/deposit-handlers/IERC7540LikeDepositHandler.sol";
import {ERC7540LikeIssuanceBase} from "src/components/issuance/utils/ERC7540LikeIssuanceBase.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";
import {IFeeHandler} from "src/interfaces/IFeeHandler.sol";
import {Shares} from "src/shares/Shares.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";
import {ValueHelpersLib} from "src/utils/ValueHelpersLib.sol";

/// @title ERC7540LikeDepositQueue Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice A IERC7540LikeDepositHandler implementation that manages requests as an ordered queue
/// @dev Does not enforce request execution in any particular order. If desired, this must be done peripherally.
/// Does not validate the sharePrice() timestamp.
contract ERC7540LikeDepositQueue is IERC7540LikeDepositHandler, ERC7540LikeIssuanceBase {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    //==================================================================================================================
    // Types
    //==================================================================================================================

    /// @param controller The user who owns the request
    /// @param canCancelTime The time when the request can be canceled
    /// @param assetAmount The amount of the asset to deposit
    struct DepositRequestInfo {
        address controller;
        uint40 canCancelTime;
        uint256 assetAmount;
    }

    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 private immutable DEPOSIT_QUEUE_STORAGE_LOCATION = StorageHelpersLib.deriveErc7201Location("DepositQueue");

    /// @custom:storage-location erc7201:enzyme.DepositQueue
    /// @param lastId Incrementing id for the most recent request (starts from `1`)
    /// @param minRequestDuration The minimum time between a request and the ability to cancel it
    /// @param idToRequest Mapping of request id to DepositRequestInfo
    struct DepositQueueStorage {
        uint128 lastId;
        uint24 minRequestDuration;
        mapping(uint256 => DepositRequestInfo) idToRequest;
    }

    function __getDepositQueueStorage() private view returns (DepositQueueStorage storage $) {
        bytes32 location = DEPOSIT_QUEUE_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event DepositMinRequestDurationSet(uint24 minRequestDuration);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error ERC7540LikeDepositQueue__CancelRequest__MinRequestDurationNotElapsed();

    error ERC7540LikeDepositQueue__CancelRequest__Unauthorized();

    error ERC7540LikeDepositQueue__ExecuteDepositRequests__ZeroShares();

    error ERC7540LikeDepositQueue__RequestDeposit__ControllerNotAllowedDepositor();

    error ERC7540LikeDepositQueue__RequestDeposit__OwnerNotController();

    error ERC7540LikeDepositQueue__RequestDeposit__OwnerNotSender();

    error ERC7540LikeDepositQueue__RequestDeposit__ZeroAssets();

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function setDepositMinRequestDuration(uint24 _minRequestDuration) external onlyAdminOrOwner {
        __getDepositQueueStorage().minRequestDuration = _minRequestDuration;

        emit DepositMinRequestDurationSet({minRequestDuration: _minRequestDuration});
    }

    //==================================================================================================================
    // Required: IERC7540DepositHandler
    //==================================================================================================================

    function cancelDeposit(uint256 _requestId) external returns (uint256 assets_) {
        DepositRequestInfo memory request = getDepositRequest({_requestId: _requestId});

        require(msg.sender == request.controller, ERC7540LikeDepositQueue__CancelRequest__Unauthorized());
        require(
            block.timestamp >= request.canCancelTime,
            ERC7540LikeDepositQueue__CancelRequest__MinRequestDurationNotElapsed()
        );

        // Get asset amount to refund
        assets_ = request.assetAmount;

        // Remove request
        __removeDepositRequest(_requestId);

        // Refund deposit asset to the controller
        IERC20(asset()).safeTransfer(request.controller, assets_);

        emit DepositRequestCanceled({requestId: _requestId});
    }

    function requestDeposit(uint256 _assets, address _controller, address _owner)
        external
        returns (uint256 requestId_)
    {
        return __requestDeposit({_assets: _assets, _controller: _controller, _owner: _owner});
    }

    function requestDepositReferred(uint256 _assets, address _controller, address _owner, bytes32 _referrer)
        external
        returns (uint256 requestId_)
    {
        requestId_ = __requestDeposit({_assets: _assets, _controller: _controller, _owner: _owner});

        emit DepositRequestReferred({requestId: requestId_, referrer: _referrer});
    }

    /// @dev _controller, _owner, and msg.sender must all be the same. Support for distinct values may be added later.
    function __requestDeposit(uint256 _assets, address _controller, address _owner)
        internal
        returns (uint256 requestId_)
    {
        require(_assets > 0, ERC7540LikeDepositQueue__RequestDeposit__ZeroAssets());
        require(_owner == msg.sender, ERC7540LikeDepositQueue__RequestDeposit__OwnerNotSender());
        require(_owner == _controller, ERC7540LikeDepositQueue__RequestDeposit__OwnerNotController());
        require(
            Shares(__getShares()).isAllowedDepositRecipient({_who: _controller}),
            ERC7540LikeDepositQueue__RequestDeposit__ControllerNotAllowedDepositor()
        );

        uint40 canCancelTime = uint40(block.timestamp + getDepositMinRequestDuration());

        // Increment id counter and add request to queue
        DepositQueueStorage storage $ = __getDepositQueueStorage();
        requestId_ = ++$.lastId; // Starts from 1
        $.idToRequest[requestId_] =
            DepositRequestInfo({controller: _controller, assetAmount: _assets, canCancelTime: canCancelTime});

        // Take deposit asset from owner
        IERC20(asset()).safeTransferFrom(_owner, address(this), _assets);

        // Required event for ERC7540
        emit DepositRequest({
            controller: _controller,
            owner: _owner,
            requestId: requestId_,
            sender: msg.sender,
            assets: _assets
        });
    }

    //==================================================================================================================
    // Request fulfillment
    //==================================================================================================================

    function executeDepositRequests(uint256[] memory _requestIds) external onlyAdminOrOwner {
        Shares shares = Shares(__getShares());
        IFeeHandler feeHandler = IFeeHandler(shares.getFeeHandler());
        ValuationHandler valuationHandler = ValuationHandler(shares.getValuationHandler());

        // Calculate the share price in the deposit asset
        (uint256 sharePriceInDepositAsset,) = valuationHandler.getSharePriceAsAssetAmount({_asset: asset()});

        // Fulfill requests
        uint256 totalAssetsDeposited;
        for (uint256 i; i < _requestIds.length; i++) {
            uint128 requestId = _requestIds[i].toUint128();
            DepositRequestInfo memory request = getDepositRequest({_requestId: requestId});

            // Remove request
            __removeDepositRequest({_requestId: requestId});

            // Add to total assets deposited
            totalAssetsDeposited += request.assetAmount;

            // Calculate gross shares
            uint256 grossSharesAmount = ValueHelpersLib.calcSharesAmountForValue({
                _valuePerShare: sharePriceInDepositAsset,
                _value: request.assetAmount
            });
            // Settle any entrance fee
            uint256 feeSharesAmount = address(feeHandler) == address(0)
                ? 0
                : feeHandler.settleEntranceFee({_grossSharesAmount: grossSharesAmount});

            // Calculate net shares
            uint256 netShares = grossSharesAmount - feeSharesAmount;
            require(netShares > 0, ERC7540LikeDepositQueue__ExecuteDepositRequests__ZeroShares());

            // Mint net shares to user
            shares.mintFor({_to: request.controller, _sharesAmount: netShares});

            // Required event for ERC7540
            emit Deposit({
                sender: request.controller,
                owner: request.controller,
                assets: request.assetAmount,
                shares: netShares
            });

            emit DepositRequestExecuted({requestId: requestId, sharesAmount: netShares});
        }

        // Send the total deposit asset amount to the designated account
        IERC20(asset()).safeTransfer(shares.getDepositAssetsDest(), totalAssetsDeposited);
    }

    //==================================================================================================================
    // Misc helpers
    //==================================================================================================================

    /// @dev Helper to remove (zero-out) a deposit request
    function __removeDepositRequest(uint256 _requestId) internal {
        DepositQueueStorage storage $ = __getDepositQueueStorage();
        delete $.idToRequest[_requestId];
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    /// @notice Gets the id of the most recent deposit request
    /// @return requestId_ The id
    function getDepositLastId() public view returns (uint256 requestId_) {
        return __getDepositQueueStorage().lastId;
    }

    /// @notice Gets the min time duration before a deposit request is cancelable
    /// @return minRequestDuration_ The duration
    function getDepositMinRequestDuration() public view returns (uint24 minRequestDuration_) {
        return __getDepositQueueStorage().minRequestDuration;
    }

    /// @notice Gets the deposit request for a given id
    /// @param _requestId The id of the request
    /// @return request_ The request
    function getDepositRequest(uint256 _requestId) public view returns (DepositRequestInfo memory request_) {
        return __getDepositQueueStorage().idToRequest[_requestId];
    }
}
