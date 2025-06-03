// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ERC7540LikeDepositQueue} from "src/components/issuance/deposit-handlers/ERC7540LikeDepositQueue.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {IERC7540LikeDepositHandler} from "src/components/issuance/deposit-handlers/IERC7540LikeDepositHandler.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";
import {Shares} from "src/shares/Shares.sol";

import {ERC7540LikeDepositQueueHarness} from "test/harnesses/ERC7540LikeDepositQueueHarness.sol";
import {ValuationHandlerHarness} from "test/harnesses/ValuationHandlerHarness.sol";
import {MockChainlinkAggregator} from "test/mocks/MockChainlinkAggregator.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract ERC7540LikeDepositQueueTest is TestHelpers {
    Shares shares;
    address owner;
    address admin = makeAddr("admin");
    ValuationHandler valuationHandler;

    ERC7540LikeDepositQueueHarness depositQueue;

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        vm.prank(owner);
        shares.addAdmin(admin);

        // Deploy harness contract and set it on Shares
        depositQueue = new ERC7540LikeDepositQueueHarness(address(shares));
        vm.prank(admin);
        shares.addDepositHandler(address(depositQueue));

        // Create a mock ValuationHandler and set it on Shares
        valuationHandler = ValuationHandler(address(new ValuationHandlerHarness(address(shares))));
        vm.prank(admin);
        shares.setValuationHandler(address(valuationHandler));
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_setDepositMinRequestDuration_fail_notAdminOrOwner() public {
        address randomUser = makeAddr("randomUser");
        uint24 minRequestDuration = 123;

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        depositQueue.setDepositMinRequestDuration(minRequestDuration);
    }

    function test_setDepositMinRequestDuration_success() public {
        uint24 minRequestDuration = 123;

        vm.expectEmit();
        emit ERC7540LikeDepositQueue.DepositMinRequestDurationSet(minRequestDuration);

        vm.prank(admin);
        depositQueue.setDepositMinRequestDuration(minRequestDuration);

        assertEq(depositQueue.getDepositMinRequestDuration(), minRequestDuration);
    }

    //==================================================================================================================
    // Required: IERC7540LikeDepositHandler
    //==================================================================================================================

    function test_cancelDeposit_fail_notRequestOwner() public {
        uint256 requestId = __test_cancelDeposit_setup();

        address randomUser = makeAddr("randomUser");
        vm.expectRevert(ERC7540LikeDepositQueue.ERC7540LikeDepositQueue__CancelRequest__Unauthorized.selector);
        vm.prank(randomUser);
        depositQueue.cancelDeposit(requestId);
    }

    function test_cancelDeposit_fail_minRequestDurationNotElapsed() public {
        uint256 requestId = __test_cancelDeposit_setup();
        address controller = depositQueue.getDepositRequest(requestId).controller;

        vm.expectRevert(
            ERC7540LikeDepositQueue.ERC7540LikeDepositQueue__CancelRequest__MinRequestDurationNotElapsed.selector
        );
        vm.prank(controller);
        depositQueue.cancelDeposit(requestId);
    }

    function test_cancelDeposit_success() public {
        uint256 requestId = __test_cancelDeposit_setup();

        // cancelable condition
        vm.warp(block.timestamp + depositQueue.getDepositMinRequestDuration());

        __test_cancelDeposit_success({_requestId: requestId});
    }

    function __test_cancelDeposit_setup() internal returns (uint256 requestId_) {
        // Create and set the deposit asset
        uint8 assetDecimals = 6;
        address depositAsset = address(new MockERC20(assetDecimals));
        vm.prank(admin);
        depositQueue.setAsset({_asset: depositAsset});

        // Define a controller, seed it with deposit asset, and grant allowance to the deposit queue
        address controller = makeAddr("controller");
        deal(depositAsset, controller, 1000 * 10 ** IERC20(depositAsset).decimals(), true);
        vm.prank(controller);
        IERC20(depositAsset).approve(address(depositQueue), type(uint256).max);

        // Set a min request time
        vm.prank(admin);
        depositQueue.setDepositMinRequestDuration(11);

        // Warp to an arbitrary time for the request
        uint256 requestTime = 123456;
        vm.warp(requestTime);

        // Create a request
        vm.prank(controller);
        return depositQueue.requestDeposit({_assets: 123, _controller: controller, _owner: controller});
    }

    function __test_cancelDeposit_success(uint256 _requestId) internal {
        address controller = depositQueue.getDepositRequest(_requestId).controller;
        uint256 depositAssetAmount = depositQueue.getDepositRequest(_requestId).assetAmount;
        IERC20 depositAsset = IERC20(depositQueue.asset());

        uint256 preControllerBalance = depositAsset.balanceOf(controller);

        vm.expectEmit();
        emit IERC7540LikeDepositHandler.DepositRequestCanceled(_requestId);

        vm.prank(controller);
        uint256 assetAmountRefunded = depositQueue.cancelDeposit(_requestId);

        // Deposit asset should be refunded
        assertEq(assetAmountRefunded, depositAssetAmount);
        assertEq(depositAsset.balanceOf(controller), preControllerBalance + depositAssetAmount);

        // Request should be zeroed out
        assertEq(depositQueue.getDepositRequest(_requestId).controller, address(0));
    }

    function test_requestDeposit_fail_ownerNotSender() public {
        address sender = makeAddr("sender");
        address controller = makeAddr("controller");
        address tokenOwner = controller;
        uint256 assetAmount = 123;
        __test_requestDeposit_setup({_tokenOwner: tokenOwner});

        vm.expectRevert(ERC7540LikeDepositQueue.ERC7540LikeDepositQueue__RequestDeposit__OwnerNotSender.selector);
        vm.prank(sender);
        depositQueue.requestDeposit({_assets: assetAmount, _controller: controller, _owner: tokenOwner});
    }

    function test_requestDeposit_fail_ownerNotController() public {
        address controller = makeAddr("controller");
        address tokenOwner = makeAddr("tokenOwner");
        uint256 assetAmount = 123;
        __test_requestDeposit_setup({_tokenOwner: tokenOwner});

        vm.expectRevert(ERC7540LikeDepositQueue.ERC7540LikeDepositQueue__RequestDeposit__OwnerNotController.selector);
        vm.prank(tokenOwner);
        depositQueue.requestDeposit({_assets: assetAmount, _controller: controller, _owner: tokenOwner});
    }

    function test_requestDeposit_fail_zeroAssets() public {
        address controller = makeAddr("controller");
        address tokenOwner = controller;
        __test_requestDeposit_setup({_tokenOwner: tokenOwner});

        vm.expectRevert(ERC7540LikeDepositQueue.ERC7540LikeDepositQueue__RequestDeposit__ZeroAssets.selector);
        vm.prank(tokenOwner);
        depositQueue.requestDeposit({_assets: 0, _controller: controller, _owner: tokenOwner});
    }

    function test_requestDeposit_fail_controllerNotAllowedDepositor() public {
        address controller = makeAddr("controller");
        address tokenOwner = controller;
        uint256 assetAmount = 123;
        __test_requestDeposit_setup({_tokenOwner: tokenOwner});

        vm.expectRevert(
            ERC7540LikeDepositQueue.ERC7540LikeDepositQueue__RequestDeposit__ControllerNotAllowedDepositor.selector
        );
        vm.prank(tokenOwner);
        depositQueue.requestDeposit({_assets: assetAmount, _controller: controller, _owner: tokenOwner});
    }

    // Tests both requestDeposit() and requestDepositReferred()
    function test_requestDeposit_success() public {
        address controller = makeAddr("controller");
        address tokenOwner = controller;
        __test_requestDeposit_setup({_tokenOwner: tokenOwner});

        __test_requestDeposit_success({
            _controller: controller,
            _tokenOwner: tokenOwner,
            _assetAmount: 123,
            _referred: false
        });
        __test_requestDeposit_success({
            _controller: controller,
            _tokenOwner: tokenOwner,
            _assetAmount: 456,
            _referred: true
        });
    }

    function __test_requestDeposit_success(
        address _controller,
        address _tokenOwner,
        uint256 _assetAmount,
        bool _referred
    ) internal {
        // Add controller to depositor allowlist
        if (!shares.isAllowedHolder(_controller)) {
            vm.prank(admin);
            shares.addAllowedHolder(_controller);
        }

        uint256 expectedRequestId = depositQueue.getDepositLastId() + 1;
        uint256 expectedCanCancelTime = block.timestamp + depositQueue.getDepositMinRequestDuration();

        IERC20 asset = IERC20(depositQueue.asset());
        uint256 preRequestQueueAssetBalance = asset.balanceOf(address(depositQueue));
        uint256 preRequestTokenOwnerAssetBalance = asset.balanceOf(_tokenOwner);

        vm.expectEmit();
        emit IERC7540LikeDepositHandler.DepositRequest({
            controller: _controller,
            owner: _tokenOwner,
            requestId: expectedRequestId,
            sender: _tokenOwner,
            assets: _assetAmount
        });

        if (_referred) {
            bytes32 referrer = "test";

            vm.expectEmit();
            emit IERC7540LikeDepositHandler.DepositRequestReferred({requestId: expectedRequestId, referrer: referrer});

            vm.prank(_tokenOwner);
            depositQueue.requestDepositReferred({
                _assets: _assetAmount,
                _controller: _controller,
                _owner: _tokenOwner,
                _referrer: referrer
            });
        } else {
            vm.prank(_tokenOwner);
            depositQueue.requestDeposit({_assets: _assetAmount, _controller: _controller, _owner: _tokenOwner});
        }

        // Assert request storage
        ERC7540LikeDepositQueue.DepositRequestInfo memory request = depositQueue.getDepositRequest(expectedRequestId);
        assertEq(request.controller, _controller);
        assertEq(request.assetAmount, _assetAmount);
        assertEq(request.canCancelTime, expectedCanCancelTime);

        // Assert asset transfer
        assertEq(asset.balanceOf(address(depositQueue)), preRequestQueueAssetBalance + _assetAmount);
        assertEq(asset.balanceOf(_tokenOwner), preRequestTokenOwnerAssetBalance - _assetAmount);
    }

    function __test_requestDeposit_setup(address _tokenOwner) internal {
        // Set shares to use a strict depositor allowlist with no transfers
        vm.prank(admin);
        shares.setHolderRestriction(Shares.HolderRestriction.RestrictedNoTransfers);

        // Create and set the asset
        uint8 assetDecimals = 6;
        address asset = address(new MockERC20(assetDecimals));
        vm.prank(admin);
        depositQueue.setAsset({_asset: asset});

        // Seed token owner with asset, and grant allowance to the queue
        deal(asset, _tokenOwner, 1000 * 10 ** IERC20(asset).decimals(), true);
        vm.prank(_tokenOwner);
        IERC20(asset).approve(address(depositQueue), type(uint256).max);

        // Set a min request time
        vm.prank(admin);
        depositQueue.setDepositMinRequestDuration(11);

        // Warp to an arbitrary time for the request
        uint256 requestTime = 123456;
        vm.warp(requestTime);
    }

    //==================================================================================================================
    // Request fulfillment
    //==================================================================================================================

    function test_executeDepositRequests_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);
        vm.prank(randomUser);
        depositQueue.executeDepositRequests({_requestIds: new uint256[](0)});
    }

    // Queues 3 requests, and executes 2 of them
    function test_executeDepositRequests_success() public {
        // Define requests
        address request1Controller = makeAddr("controller1");
        address request2Controller = makeAddr("controller2");
        address request3Controller = makeAddr("controller3");

        uint256 request1AssetAmount = 3_000_000; // 3 units
        uint256 request3AssetAmount = 15_000_000; // 15 units

        uint256 valueAssetToDepositAssetRate = 3e8; // 1 valueAsset : 3 depositAsset
        bool quotedInValueAsset = false;
        uint256 sharePrice = 1e18; // Keep it simple with 1:1 share price

        uint256 request1ExpectedSharesAmount = 1e18; // 1 unit
        uint256 request3ExpectedSharesAmount = 5e18; // 5 units

        // Create and set the asset
        uint8 assetDecimals = 6;
        address asset = address(new MockERC20(assetDecimals));
        vm.prank(admin);
        depositQueue.setAsset({_asset: asset});

        // Create and set the oracle
        uint8 oracleDecimals = 8;
        MockChainlinkAggregator mockOracle = new MockChainlinkAggregator(oracleDecimals);
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: address(mockOracle),
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: 0
        });

        // Set rates
        shares_mockSharePrice({_shares: address(shares), _sharePrice: sharePrice, _timestamp: block.timestamp});
        mockOracle.setRate(valueAssetToDepositAssetRate);
        mockOracle.setTimestamp(block.timestamp);

        // Shares: Add the controllers as allowed holders
        vm.startPrank(admin);
        shares.addAllowedHolder(request1Controller);
        shares.addAllowedHolder(request2Controller);
        shares.addAllowedHolder(request3Controller);
        vm.stopPrank();

        // Shares: Set the deposit asset destination
        vm.prank(admin);
        shares.setDepositAssetsDest(makeAddr("depositAssetsDest"));

        // Seed controllers with asset, and grant allowance to the queue
        address[3] memory controllers = [request1Controller, request2Controller, request3Controller];
        for (uint256 i; i < controllers.length; i++) {
            deal(asset, controllers[i], 1000 * 10 ** IERC20(asset).decimals(), true);
            vm.prank(controllers[i]);
            IERC20(asset).approve(address(depositQueue), type(uint256).max);
        }

        // Create the requests
        vm.prank(request1Controller);
        depositQueue.requestDeposit({
            _assets: request1AssetAmount,
            _controller: request1Controller,
            _owner: request1Controller
        });
        vm.prank(request2Controller);
        depositQueue.requestDeposit({_assets: 456, _controller: request2Controller, _owner: request2Controller});
        vm.prank(request3Controller);
        depositQueue.requestDeposit({
            _assets: request3AssetAmount,
            _controller: request3Controller,
            _owner: request3Controller
        });

        // Define ids to execute: first and last items
        uint256[] memory requestIdsToExecute = new uint256[](2);
        requestIdsToExecute[0] = 1;
        requestIdsToExecute[1] = 3;

        // Pre-assert events
        vm.expectEmit();
        emit IERC7540LikeDepositHandler.Deposit({
            sender: request1Controller,
            owner: request1Controller,
            assets: request1AssetAmount,
            shares: request1ExpectedSharesAmount
        });
        vm.expectEmit();
        emit IERC7540LikeDepositHandler.DepositRequestExecuted({
            requestId: 1,
            sharesAmount: request1ExpectedSharesAmount
        });

        vm.expectEmit();
        emit IERC7540LikeDepositHandler.Deposit({
            sender: request3Controller,
            owner: request3Controller,
            assets: request3AssetAmount,
            shares: request3ExpectedSharesAmount
        });
        vm.expectEmit();
        emit IERC7540LikeDepositHandler.DepositRequestExecuted({
            requestId: 3,
            sharesAmount: request3ExpectedSharesAmount
        });

        // Execute the requests
        vm.prank(admin);
        depositQueue.executeDepositRequests({_requestIds: requestIdsToExecute});

        // Assert shares sent
        assertEq(shares.balanceOf(request1Controller), request1ExpectedSharesAmount);
        assertEq(shares.balanceOf(request3Controller), request3ExpectedSharesAmount);

        // Assert requests are removed
        assertEq(depositQueue.getDepositRequest(1).controller, address(0));
        assertEq(depositQueue.getDepositRequest(3).controller, address(0));
    }
}
