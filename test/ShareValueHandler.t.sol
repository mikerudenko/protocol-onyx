// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {Shares} from "src/shares/Shares.sol";
import {ShareValueHandler} from "src/components/value/ShareValueHandler.sol";

import {ShareValueHandlerHarness} from "test/harnesses/ShareValueHandlerHarness.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract ShareValueHandlerTest is TestHelpers {
    Shares shares;
    address owner;
    address admin = makeAddr("ShareValueHandlerTest.admin");

    ShareValueHandlerHarness shareValueHandler;

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        vm.prank(owner);
        shares.addAdmin(admin);

        shareValueHandler = new ShareValueHandlerHarness({_shares: address(shares)});
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_addPositionTracker_fail_duplicate() public {
        address newPositionTracker = makeAddr("newPositionTracker");

        vm.prank(owner);
        shareValueHandler.addPositionTracker(newPositionTracker);

        vm.expectRevert(ShareValueHandler.ShareValueHandler__AddPositionTracker__AlreadyAdded.selector);

        vm.prank(owner);
        shareValueHandler.addPositionTracker(newPositionTracker);
    }

    function test_addPositionTracker_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newPositionTracker = makeAddr("newPositionTracker");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shareValueHandler.addPositionTracker(newPositionTracker);
    }

    function test_addPositionTracker_success() public {
        address newPositionTracker = makeAddr("newPositionTracker");

        vm.expectEmit(address(shareValueHandler));
        emit ShareValueHandler.PositionTrackerAdded(newPositionTracker);

        vm.prank(owner);
        shareValueHandler.addPositionTracker(newPositionTracker);

        assertTrue(shareValueHandler.isPositionTracker(newPositionTracker));
        assertEq(shareValueHandler.getPositionTrackers().length, 1);
        assertEq(shareValueHandler.getPositionTrackers()[0], newPositionTracker);
    }

    function test_removePositionTracker_fail_alreadyRemoved() public {
        address trackerToRemove = makeAddr("trackerToRemove");

        vm.expectRevert(ShareValueHandler.ShareValueHandler__RemovePositionTracker__AlreadyRemoved.selector);

        vm.prank(owner);
        shareValueHandler.removePositionTracker(trackerToRemove);
    }

    function test_removePositionTracker_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address trackerToRemove = makeAddr("trackerToRemove");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shareValueHandler.removePositionTracker(trackerToRemove);
    }

    function test_removePositionTracker_success() public {
        address trackerToRemove = makeAddr("trackerToRemove");

        vm.prank(owner);
        shareValueHandler.addPositionTracker(trackerToRemove);

        vm.expectEmit(address(shareValueHandler));
        emit ShareValueHandler.PositionTrackerRemoved(trackerToRemove);

        vm.prank(owner);
        shareValueHandler.removePositionTracker(trackerToRemove);

        assertFalse(shareValueHandler.isPositionTracker(trackerToRemove));
        assertEq(shareValueHandler.getPositionTrackers().length, 0);
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
        shareValueHandler.updateShareValue(0);
    }

    function test_updateShareValue_success_noShares() public {
        __test_updateShareValue_success({
            _totalShares: 0,
            _untrackedValue: 0,
            _positionTrackerValues: new int256[](0),
            _hasFeeManager: true,
            _feesOwed: 0,
            _expectedValuePerShare: 0
        });
    }

    function test_updateShareValue_success_onlyUntrackedValue_noFeeManager() public {
        // Target price: 3e18 (i.e., 3 value units per share)
        uint256 expectedValuePerShare = 3e18;
        uint256 totalShares = 9e6;
        int256 untrackedValue = int256(totalShares) * 3;

        __test_updateShareValue_success({
            _totalShares: totalShares,
            _untrackedValue: untrackedValue,
            _positionTrackerValues: new int256[](0),
            _hasFeeManager: false,
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
            _hasFeeManager: true,
            _feesOwed: feesOwed,
            _expectedValuePerShare: expectedValuePerShare
        });
    }

    function __test_updateShareValue_success(
        uint256 _totalShares,
        int256 _untrackedValue,
        int256[] memory _positionTrackerValues,
        bool _hasFeeManager,
        uint256 _feesOwed,
        uint256 _expectedValuePerShare
    ) internal {
        // Validate that if there are fees owed, there is also a FeeManager
        assertTrue(_hasFeeManager || (!_hasFeeManager && _feesOwed == 0), "fees owed but no FeeManager");

        // Add FeeManager if needed
        address feeManager;
        if (_hasFeeManager) {
            feeManager = setMockFeeManager({_shares: address(shares), _totalValueOwed: _feesOwed});
        }

        // Add position trackers if needed
        int256 trackedPositionsValue;
        for (uint256 i = 0; i < _positionTrackerValues.length; i++) {
            address tracker = makeAddr(string(abi.encodePacked("tracker", (i))));
            positionTracker_mockGetPositionValue({_positionTracker: tracker, _value: _positionTrackerValues[i]});

            vm.prank(admin);
            shareValueHandler.addPositionTracker(tracker);

            trackedPositionsValue += _positionTrackerValues[i];
        }

        // Set shares supply
        increaseSharesSupply({_shares: address(shares), _increaseAmount: _totalShares});

        // Warp to some time for the update
        uint256 updateTimestamp = 123;
        vm.warp(updateTimestamp);

        if (_hasFeeManager && _totalShares > 0) {
            // Assert FeeManager is called with expected total positions value
            uint256 totalPositionsValue = uint256(_untrackedValue) + uint256(trackedPositionsValue);

            vm.expectCall(
                feeManager, abi.encodeWithSelector(IFeeManager.settleDynamicFees.selector, totalPositionsValue)
            );
        }

        // Pre-assert expected event
        vm.expectEmit(address(shareValueHandler));
        emit ShareValueHandler.ShareValueUpdated({
            netShareValue: _expectedValuePerShare,
            trackedPositionsValue: trackedPositionsValue,
            untrackedPositionsValue: _untrackedValue,
            totalFeesOwed: _feesOwed
        });

        // UPDATE SHARE VALUE
        vm.prank(owner);
        shareValueHandler.updateShareValue(_untrackedValue);

        // Warp to some other time for the query
        vm.warp(updateTimestamp + 8);

        (uint256 valuePerShare, uint256 timestamp) = shareValueHandler.getShareValue();

        assertEq(valuePerShare, _expectedValuePerShare);
        assertEq(timestamp, updateTimestamp);
    }
}
