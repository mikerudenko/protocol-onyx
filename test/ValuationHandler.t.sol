// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {IFeeHandler} from "src/interfaces/IFeeHandler.sol";
import {Shares} from "src/shares/Shares.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";

import {ValuationHandlerHarness} from "test/harnesses/ValuationHandlerHarness.sol";
import {MockChainlinkAggregator} from "test/mocks/MockChainlinkAggregator.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract ValuationHandlerTest is TestHelpers {
    Shares shares;
    address owner;
    address admin = makeAddr("ValuationHandlerTest.admin");

    ValuationHandlerHarness valuationHandler;

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        vm.prank(owner);
        shares.addAdmin(admin);

        valuationHandler = new ValuationHandlerHarness({_shares: address(shares)});
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_addPositionTracker_fail_duplicate() public {
        address newPositionTracker = makeAddr("newPositionTracker");

        vm.prank(owner);
        valuationHandler.addPositionTracker(newPositionTracker);

        vm.expectRevert(ValuationHandler.ValuationHandler__AddPositionTracker__AlreadyAdded.selector);

        vm.prank(owner);
        valuationHandler.addPositionTracker(newPositionTracker);
    }

    function test_addPositionTracker_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newPositionTracker = makeAddr("newPositionTracker");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        valuationHandler.addPositionTracker(newPositionTracker);
    }

    function test_addPositionTracker_success() public {
        address newPositionTracker = makeAddr("newPositionTracker");

        vm.expectEmit(address(valuationHandler));
        emit ValuationHandler.PositionTrackerAdded(newPositionTracker);

        vm.prank(owner);
        valuationHandler.addPositionTracker(newPositionTracker);

        assertTrue(valuationHandler.isPositionTracker(newPositionTracker));
        assertEq(valuationHandler.getPositionTrackers().length, 1);
        assertEq(valuationHandler.getPositionTrackers()[0], newPositionTracker);
    }

    function test_removePositionTracker_fail_alreadyRemoved() public {
        address trackerToRemove = makeAddr("trackerToRemove");

        vm.expectRevert(ValuationHandler.ValuationHandler__RemovePositionTracker__AlreadyRemoved.selector);

        vm.prank(owner);
        valuationHandler.removePositionTracker(trackerToRemove);
    }

    function test_removePositionTracker_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address trackerToRemove = makeAddr("trackerToRemove");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        valuationHandler.removePositionTracker(trackerToRemove);
    }

    function test_removePositionTracker_success() public {
        address trackerToRemove = makeAddr("trackerToRemove");

        vm.prank(owner);
        valuationHandler.addPositionTracker(trackerToRemove);

        vm.expectEmit(address(valuationHandler));
        emit ValuationHandler.PositionTrackerRemoved(trackerToRemove);

        vm.prank(owner);
        valuationHandler.removePositionTracker(trackerToRemove);

        assertFalse(valuationHandler.isPositionTracker(trackerToRemove));
        assertEq(valuationHandler.getPositionTrackers().length, 0);
    }

    function test_setAssetOracle_fail_notAdminOrOwner() public {
        address randomUser = makeAddr("randomUser");
        address asset = makeAddr("oracleAsset");
        address oracle = address(new MockChainlinkAggregator(18));

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: oracle,
            _quotedInValueAsset: true,
            _timestampTolerance: 0
        });
    }

    function test_setAssetOracle_success() public {
        uint8 assetDecimals = 12;
        address asset = address(new MockERC20(assetDecimals));
        uint8 oracleDecimals = 7;
        address oracle = address(new MockChainlinkAggregator(oracleDecimals));
        uint24 timestampTolerance = 100;
        bool quotedInValueAsset = true;

        vm.expectEmit();
        emit ValuationHandler.AssetOracleSet({
            asset: asset,
            oracle: oracle,
            quotedInValueAsset: quotedInValueAsset,
            timestampTolerance: timestampTolerance
        });

        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: oracle,
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: timestampTolerance
        });

        ValuationHandler.AssetOracleInfo memory oracleInfo = valuationHandler.getAssetOracleInfo({_asset: asset});

        assertEq(oracleInfo.oracle, oracle);
        assertEq(oracleInfo.timestampTolerance, timestampTolerance);
        assertEq(oracleInfo.quotedInValueAsset, quotedInValueAsset);
        assertEq(oracleInfo.oracleDecimals, oracleDecimals);
        assertEq(oracleInfo.assetDecimals, assetDecimals);
    }

    function test_unsetAssetOracle_fail_notAdminOrOwner() public {
        address randomUser = makeAddr("randomUser");
        address asset = makeAddr("asset");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        valuationHandler.unsetAssetOracle(asset);
    }

    function test_unsetAssetOracle_success() public {
        address asset = address(new MockERC20(12));
        address oracle = address(new MockChainlinkAggregator(7));

        // Set oracle
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: oracle,
            _quotedInValueAsset: true,
            _timestampTolerance: 100
        });

        vm.expectEmit();
        emit ValuationHandler.AssetOracleUnset({asset: asset});

        // Unset oracle
        vm.prank(admin);
        valuationHandler.unsetAssetOracle(asset);

        ValuationHandler.AssetOracleInfo memory oracleInfo = valuationHandler.getAssetOracleInfo({_asset: asset});
        assertEq(oracleInfo.oracle, address(0));
        assertEq(oracleInfo.timestampTolerance, 0);
        assertEq(oracleInfo.quotedInValueAsset, false);
        assertEq(oracleInfo.oracleDecimals, 0);
        assertEq(oracleInfo.assetDecimals, 0);
    }

    //==================================================================================================================
    // Valuation
    //==================================================================================================================

    function test_convertAssetAmountToValue_success() public {
        uint8 assetDecimals = 6;
        uint256 assetAmount = 15e6; // 15 units
        address asset = address(new MockERC20(assetDecimals));

        uint8 oracleDecimals = 8;
        uint256 oracleRate = 3e8; // 1 valueAsset : 3 asset
        bool quotedInValueAsset = false;
        MockChainlinkAggregator oracle = new MockChainlinkAggregator(oracleDecimals);
        oracle.setRate(oracleRate);
        oracle.setTimestamp(block.timestamp);

        uint256 expectedValue = 5e18; // 5 value units

        // Set oracle
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: address(oracle),
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: 0
        });

        uint256 actualValue = valuationHandler.convertAssetAmountToValue({_asset: asset, _assetAmount: assetAmount});
        assertEq(actualValue, expectedValue);
    }

    function test_convertValueToAssetAmount_success() public {
        uint256 value = 5e18; // 5 value units

        uint8 oracleDecimals = 8;
        uint256 oracleRate = 3e8; // 1 valueAsset : 3 asset
        bool quotedInValueAsset = false;
        MockChainlinkAggregator oracle = new MockChainlinkAggregator(oracleDecimals);
        oracle.setRate(oracleRate);
        oracle.setTimestamp(block.timestamp);

        uint8 assetDecimals = 6;
        address asset = address(new MockERC20(assetDecimals));
        uint256 expectedAssetAmount = 15e6; // 15 units

        // Set oracle
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: address(oracle),
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: 0
        });

        uint256 actualAssetAmount = valuationHandler.convertValueToAssetAmount({_value: value, _asset: asset});
        assertEq(actualAssetAmount, expectedAssetAmount);
    }

    function test_getDefaultSharePrice_success() public view {
        uint256 actualSharePrice = valuationHandler.getDefaultSharePrice();
        assertEq(actualSharePrice, 1e18);
    }

    function test_getSharePrice_success_nonZeroValue() public {
        __test_getSharePrice_success({_shareValue: 123, _expectedSharePrice: 123, _valueTimestamp: 456});
    }

    function test_getSharePrice_success_zeroValue() public {
        __test_getSharePrice_success({_shareValue: 0, _expectedSharePrice: 1e18, _valueTimestamp: 123});
    }

    function __test_getSharePrice_success(uint256 _shareValue, uint256 _expectedSharePrice, uint256 _valueTimestamp)
        public
    {
        valuationHandler.harness_setLastShareValue({_shareValue: _shareValue, _timestamp: _valueTimestamp});

        (uint256 actualSharePrice, uint256 actualTimestamp) = valuationHandler.getSharePrice();
        assertEq(actualSharePrice, _expectedSharePrice);
        assertEq(actualTimestamp, _valueTimestamp);
    }

    function test_getSharePriceAsAssetAmount_success() public {
        // Warp to arbitrary time
        vm.warp(12345);

        // Set share value
        uint256 shareValue = 5e18; // 5 value units
        uint256 shareValueTimestamp = block.timestamp - 11;
        valuationHandler.harness_setLastShareValue({_shareValue: shareValue, _timestamp: shareValueTimestamp});

        // Create oracle
        uint8 oracleDecimals = 8;
        uint256 oracleRate = 3e8; // 1 valueAsset : 3 asset
        bool quotedInValueAsset = false;
        MockChainlinkAggregator oracle = new MockChainlinkAggregator(oracleDecimals);
        oracle.setRate(oracleRate);
        oracle.setTimestamp(block.timestamp);

        // Create asset
        uint8 assetDecimals = 6;
        address asset = address(new MockERC20(assetDecimals));
        uint256 expectedAssetAmount = 15e6; // 15 units

        // Set oracle
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: asset,
            _oracle: address(oracle),
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: 0
        });

        (uint256 actualAssetAmount, uint256 actualTimestamp) =
            valuationHandler.getSharePriceAsAssetAmount({_asset: asset});
        assertEq(actualAssetAmount, expectedAssetAmount);
        assertEq(actualTimestamp, shareValueTimestamp);
    }

    //==================================================================================================================
    // Share value updates
    //==================================================================================================================

    // TODO:
    // - negative tracked positions value
    // - negative untracked positions value
    // - other combos

    function test_updateShareValue_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        valuationHandler.updateShareValue(0);
    }

    function test_updateShareValue_success_noShares() public {
        __test_updateShareValue_success({
            _totalShares: 0,
            _untrackedValue: 0,
            _positionTrackerValues: new int256[](0),
            _hasFeeHandler: true,
            _feesOwed: 0,
            _expectedValuePerShare: 0
        });
    }

    function test_updateShareValue_success_onlyUntrackedValue_noFeeHandler() public {
        // Target price: 3e18 (i.e., 3 value units per share)
        uint256 expectedValuePerShare = 3e18;
        uint256 totalShares = 9e6;
        int256 untrackedValue = int256(totalShares) * 3;

        __test_updateShareValue_success({
            _totalShares: totalShares,
            _untrackedValue: untrackedValue,
            _positionTrackerValues: new int256[](0),
            _hasFeeHandler: false,
            _feesOwed: 0,
            _expectedValuePerShare: expectedValuePerShare
        });
    }

    function test_updateShareValue_success_all() public {
        // Target price: 3e18 (i.e., 3 value units per share)
        uint256 expectedValuePerShare = 3e18;
        uint256 totalShares = 9e6;
        int256 value = int256(totalShares) * 3;

        // Split into tracked, untracked, and fees owed
        int256 trackedPositionsValue = value / 11;
        uint256 feesOwed = uint256(trackedPositionsValue) / 3;
        // Add feesOwed to untracked value to offset the fees
        int256 untrackedValue = value - trackedPositionsValue + int256(feesOwed);

        // Create two position trackers for untrackedPositionsValue
        int256[] memory positionTrackerValues = new int256[](2);
        positionTrackerValues[0] = trackedPositionsValue / 6;
        positionTrackerValues[1] = trackedPositionsValue - positionTrackerValues[0];

        __test_updateShareValue_success({
            _totalShares: totalShares,
            _untrackedValue: untrackedValue,
            _positionTrackerValues: positionTrackerValues,
            _hasFeeHandler: true,
            _feesOwed: feesOwed,
            _expectedValuePerShare: expectedValuePerShare
        });
    }

    function __test_updateShareValue_success(
        uint256 _totalShares,
        int256 _untrackedValue,
        int256[] memory _positionTrackerValues,
        bool _hasFeeHandler,
        uint256 _feesOwed,
        uint256 _expectedValuePerShare
    ) internal {
        // Validate that if there are fees owed, there is also a FeeHandler
        assertTrue(_hasFeeHandler || (!_hasFeeHandler && _feesOwed == 0), "fees owed but no FeeHandler");

        // Add FeeHandler if needed
        address feeHandler;
        if (_hasFeeHandler) {
            feeHandler = setMockFeeHandler({_shares: address(shares), _totalValueOwed: _feesOwed});
        }

        // Add position trackers if needed
        int256 trackedPositionsValue;
        for (uint256 i = 0; i < _positionTrackerValues.length; i++) {
            address tracker = makeAddr(string(abi.encodePacked("tracker", (i))));
            positionTracker_mockGetPositionValue({_positionTracker: tracker, _value: _positionTrackerValues[i]});

            vm.prank(admin);
            valuationHandler.addPositionTracker(tracker);

            trackedPositionsValue += _positionTrackerValues[i];
        }

        // Set shares supply
        increaseSharesSupply({_shares: address(shares), _increaseAmount: _totalShares});

        // Warp to some time for the update
        uint256 updateTimestamp = 123;
        vm.warp(updateTimestamp);

        if (_hasFeeHandler && _totalShares > 0) {
            // Assert FeeHandler is called with expected total positions value
            uint256 totalPositionsValue = uint256(_untrackedValue) + uint256(trackedPositionsValue);

            vm.expectCall(
                feeHandler, abi.encodeWithSelector(IFeeHandler.settleDynamicFees.selector, totalPositionsValue)
            );
        }

        // Pre-assert expected event
        vm.expectEmit(address(valuationHandler));
        emit ValuationHandler.ShareValueUpdated({
            netShareValue: _expectedValuePerShare,
            trackedPositionsValue: trackedPositionsValue,
            untrackedPositionsValue: _untrackedValue,
            totalFeesOwed: _feesOwed
        });

        // UPDATE SHARE VALUE
        vm.prank(owner);
        valuationHandler.updateShareValue(_untrackedValue);

        // Warp to some other time for the query
        vm.warp(updateTimestamp + 8);

        (uint256 valuePerShare, uint256 timestamp) = valuationHandler.getShareValue();

        assertEq(valuePerShare, _expectedValuePerShare);
        assertEq(timestamp, updateTimestamp);
    }
}
