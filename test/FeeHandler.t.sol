// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IChainlinkAggregator} from "src/interfaces/external/IChainlinkAggregator.sol";
import {IManagementFeeTracker} from "src/components/fees/interfaces/IManagementFeeTracker.sol";
import {IPerformanceFeeTracker} from "src/components/fees/interfaces/IPerformanceFeeTracker.sol";
import {FeeHandler} from "src/components/fees/FeeHandler.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";
import {Shares} from "src/shares/Shares.sol";

import {FeeHandlerHarness} from "test/harnesses/FeeHandlerHarness.sol";
import {ValuationHandlerHarness} from "test/harnesses/ValuationHandlerHarness.sol";
import {BlankManagementFeeTracker, BlankPerformanceFeeTracker} from "test/mocks/Blanks.sol";
import {MockChainlinkAggregator} from "test/mocks/MockChainlinkAggregator.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract FeeHandlerTestHelpers is TestHelpers {
    function managementFeeTracker_mockSettleManagementFee(address _managementFeeTracker, uint256 _valueDue) internal {
        vm.mockCall(_managementFeeTracker, IManagementFeeTracker.settleManagementFee.selector, abi.encode(_valueDue));
    }

    function performanceFeeTracker_mockSettlePerformanceFee(address _performanceFeeTracker, uint256 _valueDue)
        internal
    {
        vm.mockCall(_performanceFeeTracker, IPerformanceFeeTracker.settlePerformanceFee.selector, abi.encode(_valueDue));
    }

    function setMockManagementFee(address _feeHandler, address _admin)
        internal
        returns (address managementFeeTracker_)
    {
        managementFeeTracker_ = address(new BlankManagementFeeTracker());
        address recipient = makeAddr("setMockManagementFee:recipient");

        vm.prank(_admin);
        FeeHandler(_feeHandler).setManagementFee({_managementFeeTracker: managementFeeTracker_, _recipient: recipient});
    }

    function setMockPerformanceFee(address _feeHandler, address _admin)
        internal
        returns (address performanceFeeTracker_)
    {
        performanceFeeTracker_ = address(new BlankPerformanceFeeTracker());
        address recipient = makeAddr("setMockPerformanceFee:recipient");

        vm.prank(_admin);
        FeeHandler(_feeHandler).setPerformanceFee({
            _performanceFeeTracker: performanceFeeTracker_,
            _recipient: recipient
        });
    }
}

contract FeeHandlerTest is Test, FeeHandlerTestHelpers {
    Shares shares;
    address owner;
    address admin = makeAddr("FeeHandlerTest.admin");
    ValuationHandler valuationHandler;

    FeeHandlerHarness feeHandler;

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        vm.prank(owner);
        shares.addAdmin(admin);

        // Deploy FeeHandler and set it on Shares
        feeHandler = new FeeHandlerHarness(address(shares));
        vm.prank(admin);
        shares.setFeeHandler(address(feeHandler));

        // Create a mock ValuationHandler and set it on Shares
        valuationHandler = ValuationHandler(address(new ValuationHandlerHarness(address(shares))));
        vm.prank(admin);
        shares.setValuationHandler(address(valuationHandler));
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_setEntranceFee_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.setEntranceFee({_feeBps: 0, _recipient: address(0)});
    }

    function test_setEntranceFee_success() public {
        uint16 feeBps = 123;
        address recipient = makeAddr("test_setEntranceFee:recipient");

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.EntranceFeeSet({feeBps: feeBps, recipient: recipient});

        vm.prank(admin);
        feeHandler.setEntranceFee({_feeBps: feeBps, _recipient: recipient});

        assertEq(feeHandler.getEntranceFeeBps(), feeBps);
        assertEq(feeHandler.getEntranceFeeRecipient(), recipient);
    }

    function test_setExitFee_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.setExitFee({_feeBps: 0, _recipient: address(0)});
    }

    function test_setExitFee_success() public {
        uint16 feeBps = 123;
        address recipient = makeAddr("test_setExitFee:recipient");

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.ExitFeeSet({feeBps: feeBps, recipient: recipient});

        vm.prank(admin);
        feeHandler.setExitFee({_feeBps: feeBps, _recipient: recipient});

        assertEq(feeHandler.getExitFeeBps(), feeBps);
        assertEq(feeHandler.getExitFeeRecipient(), recipient);
    }

    function test_setFeeAsset_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.setFeeAsset({_asset: address(0)});
    }

    function test_setFeeAsset_success() public {
        address feeAsset = makeAddr("feeAsset");

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.FeeAssetSet({asset: feeAsset});

        vm.prank(admin);
        feeHandler.setFeeAsset({_asset: feeAsset});

        assertEq(feeHandler.getFeeAsset(), feeAsset);
    }

    function test_setManagementFee_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.setManagementFee({_managementFeeTracker: address(0), _recipient: address(0)});
    }

    function test_setManagementFee_success() public {
        address managementFeeTracker = makeAddr("test_setManagementFee:managementFeeTracker");
        address recipient = makeAddr("test_setManagementFee:recipient");

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.ManagementFeeSet({managementFeeTracker: managementFeeTracker, recipient: recipient});

        vm.prank(admin);
        feeHandler.setManagementFee({_managementFeeTracker: managementFeeTracker, _recipient: recipient});

        assertEq(feeHandler.getManagementFeeTracker(), managementFeeTracker);
        assertEq(feeHandler.getManagementFeeRecipient(), recipient);
    }

    function test_setPerformanceFee_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.setPerformanceFee({_performanceFeeTracker: address(0), _recipient: address(0)});
    }

    function test_setPerformanceFee_success() public {
        address performanceFeeTracker = makeAddr("test_setPerformanceFee:performanceFeeTracker");
        address recipient = makeAddr("test_setPerformanceFee:recipient");

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.PerformanceFeeSet({performanceFeeTracker: performanceFeeTracker, recipient: recipient});

        vm.prank(admin);
        feeHandler.setPerformanceFee({_performanceFeeTracker: performanceFeeTracker, _recipient: recipient});

        assertEq(feeHandler.getPerformanceFeeTracker(), performanceFeeTracker);
        assertEq(feeHandler.getPerformanceFeeRecipient(), recipient);
    }

    //==================================================================================================================
    // Claim Fees (access: anybody)
    //==================================================================================================================

    function test_claimFees_fail_unauthorized() public {
        address owedUser = makeAddr("test_claimFees_fail_unauthorized:owedUser");
        address randomUser = makeAddr("test_claimFees_fail_unauthorized:randomUser");

        vm.expectRevert(FeeHandler.FeeHandler__ClaimFees__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.claimFees({_onBehalf: owedUser, _value: 123});
    }

    function test_claimFees_fail_zeroFeeAssetAmount() public {
        address feeAsset = address(new MockERC20(8));
        address owedUser = makeAddr("test_claimFees_fail_zeroFeeAssetAmount:owedUser");

        // Create the oracle with 1:1 conversion rate of value asset to fee asset
        MockChainlinkAggregator mockAggregator = new MockChainlinkAggregator(8);
        mockAggregator.setRate(1e8);
        mockAggregator.setTimestamp(block.timestamp);
        bool quotedInValueAsset = true; // doesn't really matter
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: feeAsset,
            _oracle: address(mockAggregator),
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: 0
        });

        // Set the fee asset
        vm.prank(admin);
        feeHandler.setFeeAsset({_asset: feeAsset});

        vm.expectRevert(FeeHandler.FeeHandler__ClaimFees__ZeroFeeAsset.selector);

        vm.prank(owedUser);
        feeHandler.claimFees({_onBehalf: owedUser, _value: 0});
    }

    function test_claimFees_success_calledByAdmin() public {
        __test_claimFees_success({_calledByAdmin: true});
    }

    function test_claimFees_success_calledByRecipient() public {
        __test_claimFees_success({_calledByAdmin: false});
    }

    function __test_claimFees_success(bool _calledByAdmin) internal {
        // Define all amount values
        uint256 valueDue = 500e18;
        uint256 valueToClaim = 100e18; // 100 value units
        uint8 feeAssetDecimals = 6;
        uint8 oracleDecimals = 9; // diff decimals from fee asset
        uint256 oracleRate = 3e9; // 1 value unit => 3 fee units
        bool quotedInValueAsset = false;
        uint256 expectedFeeAssetAmount = 300e6; // 300 fee asset units

        // Create the fee asset
        MockERC20 mockFeeAsset = new MockERC20(feeAssetDecimals);

        // Use a mock fee to add to the feeRecipient's value owed by settling the fee
        address managementFeeTracker = setMockManagementFee({_feeHandler: address(feeHandler), _admin: admin});
        managementFeeTracker_mockSettleManagementFee({_managementFeeTracker: managementFeeTracker, _valueDue: valueDue});
        vm.prank(address(valuationHandler));
        feeHandler.settleDynamicFees({_totalPositionsValue: valueDue * 3});
        address feeRecipient = feeHandler.getManagementFeeRecipient();
        assertEq(feeHandler.getValueOwedToUser(feeRecipient), valueDue);

        // Create the oracle with conversion rate of value asset to fee asset
        MockChainlinkAggregator mockAggregator = new MockChainlinkAggregator(oracleDecimals);
        mockAggregator.setRate(oracleRate);
        mockAggregator.setTimestamp(block.timestamp);
        vm.prank(admin);
        valuationHandler.setAssetOracle({
            _asset: address(mockFeeAsset),
            _oracle: address(mockAggregator),
            _quotedInValueAsset: quotedInValueAsset,
            _timestampTolerance: 0
        });

        // Set the fee asset
        vm.prank(admin);
        feeHandler.setFeeAsset({_asset: address(mockFeeAsset)});

        // Set the fee assets src...
        address feeAssetsSrc = makeAddr("test_claimFees:feeAssetsSrc");
        vm.prank(admin);
        shares.setFeeAssetsSrc(feeAssetsSrc);
        // ... seed it with the fee asset amount due...
        mockFeeAsset.mintTo(feeAssetsSrc, expectedFeeAssetAmount);
        // ... and grant the due allowance to Shares
        vm.prank(feeAssetsSrc);
        mockFeeAsset.approve(address(shares), expectedFeeAssetAmount);

        address caller = _calledByAdmin ? admin : feeRecipient;
        uint256 unclaimedValue = valueDue - valueToClaim;

        // Pre-assert events
        vm.expectEmit();
        emit FeeHandler.UserValueOwedUpdated({user: feeRecipient, value: unclaimedValue});

        vm.expectEmit();
        emit FeeHandler.TotalValueOwedUpdated({value: unclaimedValue});

        vm.expectEmit();
        emit FeeHandler.FeesClaimed({
            caller: caller,
            onBehalf: feeRecipient,
            value: valueToClaim,
            feeAsset: address(mockFeeAsset),
            feeAssetAmount: expectedFeeAssetAmount
        });

        // Claim the fees
        vm.prank(caller);
        uint256 feeAssetAmount = feeHandler.claimFees({_onBehalf: feeRecipient, _value: valueToClaim});

        // Check that the value was deducted from user and total fees owed
        assertEq(feeHandler.getValueOwedToUser(feeRecipient), unclaimedValue);
        assertEq(feeHandler.getTotalValueOwed(), unclaimedValue);

        // Check that the user received the correct amount of fee asset give the conversion rate
        assertEq(feeAssetAmount, expectedFeeAssetAmount);
        assertEq(IERC20(address(mockFeeAsset)).balanceOf(feeRecipient), expectedFeeAssetAmount);
    }

    //==================================================================================================================
    // Settle Fees (access: Shares)
    //==================================================================================================================

    function test_settleDynamicFees_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(FeeHandler.FeeHandler__SettleDynamicFees__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.settleDynamicFees(0);
    }

    function test_settleDynamicFees_success_noFees() public {
        vm.prank(address(valuationHandler));
        feeHandler.settleDynamicFees({_totalPositionsValue: 123});

        assertEq(feeHandler.getTotalValueOwed(), 0);
    }

    function test_settleDynamicFees_success_managementFeeOnly() public {
        uint256 feeValueDue = 456;
        uint256 totalPositionsValue = feeValueDue * 7;

        // Create mock ManagementFeeTracker and set the fee value due
        address managementFeeTracker = setMockManagementFee({_feeHandler: address(feeHandler), _admin: admin});
        managementFeeTracker_mockSettleManagementFee({
            _managementFeeTracker: managementFeeTracker,
            _valueDue: feeValueDue
        });

        vm.expectCall({
            callee: address(managementFeeTracker),
            data: abi.encodeCall(IManagementFeeTracker.settleManagementFee, (totalPositionsValue))
        });

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.ManagementFeeSettled({recipient: feeHandler.getManagementFeeRecipient(), value: feeValueDue});

        vm.prank(address(valuationHandler));
        feeHandler.settleDynamicFees({_totalPositionsValue: totalPositionsValue});

        assertEq(feeHandler.getTotalValueOwed(), feeValueDue);
        assertEq(feeHandler.getValueOwedToUser(feeHandler.getManagementFeeRecipient()), feeValueDue);
    }

    function test_settleDynamicFees_success_performanceFeeOnly() public {
        uint256 feeValueDue = 456;
        uint256 totalPositionsValue = feeValueDue * 7;

        // Create mock PerformanceFeeTracker and set the fee value due
        address performanceFeeTracker = setMockPerformanceFee({_feeHandler: address(feeHandler), _admin: admin});
        performanceFeeTracker_mockSettlePerformanceFee({
            _performanceFeeTracker: performanceFeeTracker,
            _valueDue: feeValueDue
        });

        vm.expectCall({
            callee: address(performanceFeeTracker),
            data: abi.encodeCall(IPerformanceFeeTracker.settlePerformanceFee, (totalPositionsValue))
        });

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.PerformanceFeeSettled({recipient: feeHandler.getPerformanceFeeRecipient(), value: feeValueDue});

        vm.prank(address(valuationHandler));
        feeHandler.settleDynamicFees({_totalPositionsValue: totalPositionsValue});

        assertEq(feeHandler.getTotalValueOwed(), feeValueDue);
        assertEq(feeHandler.getValueOwedToUser(feeHandler.getPerformanceFeeRecipient()), feeValueDue);
    }

    function test_settleDynamicFees_success_bothFees() public {
        uint256 managementFeeValueDue = 456;
        uint256 performanceFeeValueDue = 789;
        uint256 totalPositionsValue = (managementFeeValueDue + performanceFeeValueDue) * 7;

        // Create mock ManagementFeeTracker and set the fee value due
        address managementFeeTracker = setMockManagementFee({_feeHandler: address(feeHandler), _admin: admin});
        managementFeeTracker_mockSettleManagementFee({
            _managementFeeTracker: managementFeeTracker,
            _valueDue: managementFeeValueDue
        });

        // Create mock PerformanceFeeTracker and set the fee value due
        address performanceFeeTracker = setMockPerformanceFee({_feeHandler: address(feeHandler), _admin: admin});
        performanceFeeTracker_mockSettlePerformanceFee({
            _performanceFeeTracker: performanceFeeTracker,
            _valueDue: performanceFeeValueDue
        });

        vm.expectCall({
            callee: address(managementFeeTracker),
            data: abi.encodeCall(IManagementFeeTracker.settleManagementFee, (totalPositionsValue))
        });
        // Performance fee call should SUBTRACT the management fee value
        {
            uint256 expectedNetValue = totalPositionsValue - managementFeeValueDue;
            vm.expectCall({
                callee: address(performanceFeeTracker),
                data: abi.encodeCall(IPerformanceFeeTracker.settlePerformanceFee, (expectedNetValue))
            });
        }

        vm.expectEmit(address(feeHandler));
        emit FeeHandler.ManagementFeeSettled({
            recipient: feeHandler.getManagementFeeRecipient(),
            value: managementFeeValueDue
        });
        vm.expectEmit(address(feeHandler));
        emit FeeHandler.PerformanceFeeSettled({
            recipient: feeHandler.getPerformanceFeeRecipient(),
            value: performanceFeeValueDue
        });

        vm.prank(address(valuationHandler));
        feeHandler.settleDynamicFees({_totalPositionsValue: totalPositionsValue});

        uint256 totalValueOwedAfter1stSettlement = managementFeeValueDue + performanceFeeValueDue;

        assertEq(feeHandler.getTotalValueOwed(), totalValueOwedAfter1stSettlement);
        assertEq(feeHandler.getValueOwedToUser(feeHandler.getManagementFeeRecipient()), managementFeeValueDue);
        assertEq(feeHandler.getValueOwedToUser(feeHandler.getPerformanceFeeRecipient()), performanceFeeValueDue);

        // Do a 2nd round of settling fees to test that they are additive

        // This time, netValue will have deducted the previous round of fees also
        uint256 netValueAtStartOf2ndSettlement = totalPositionsValue - managementFeeValueDue - performanceFeeValueDue;

        vm.expectCall({
            callee: address(managementFeeTracker),
            data: abi.encodeCall(IManagementFeeTracker.settleManagementFee, (netValueAtStartOf2ndSettlement))
        });
        // Performance fee call should SUBTRACT the management fee value
        {
            uint256 expectedNetValue = netValueAtStartOf2ndSettlement - managementFeeValueDue;
            vm.expectCall({
                callee: address(performanceFeeTracker),
                data: abi.encodeCall(IPerformanceFeeTracker.settlePerformanceFee, (expectedNetValue))
            });
        }

        vm.prank(address(valuationHandler));
        feeHandler.settleDynamicFees({_totalPositionsValue: totalPositionsValue});

        assertEq(feeHandler.getTotalValueOwed(), 2 * totalValueOwedAfter1stSettlement);
        assertEq(feeHandler.getValueOwedToUser(feeHandler.getManagementFeeRecipient()), 2 * managementFeeValueDue);
        assertEq(feeHandler.getValueOwedToUser(feeHandler.getPerformanceFeeRecipient()), 2 * performanceFeeValueDue);
    }

    function test_settleEntranceFee_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyShares__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.settleEntranceFee(0);
    }

    function test_settleEntranceFee_success_burn() public {
        __test_settleEntranceExitFee_success({_entrance: true, _burn: true});
    }

    function test_settleEntranceFee_success_recipient() public {
        __test_settleEntranceExitFee_success({_entrance: true, _burn: false});
    }

    function test_settleExitFee_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyShares__Unauthorized.selector);

        vm.prank(randomUser);
        feeHandler.settleExitFee(0);
    }

    function test_settleExitFee_success_burn() public {
        __test_settleEntranceExitFee_success({_entrance: false, _burn: true});
    }

    function test_settleExitFee_success_recipient() public {
        __test_settleEntranceExitFee_success({_entrance: false, _burn: false});
    }

    function __test_settleEntranceExitFee_success(bool _entrance, bool _burn) internal {
        uint256 grossSharesAmount = 10_000_000;
        uint16 feeBps = 500; // 5%
        uint256 expectedFeeSharesAmount = 500_000;
        uint256 sharePrice = 3e18; // 3 value units per share
        uint256 expectedFeevalue = 1_500_000;
        address feeRecipient = _burn ? address(0) : makeAddr("test_settleEntranceExitFee:feeRecipient");

        // Mock the share price on Shares
        shares_mockSharePrice({_shares: address(shares), _sharePrice: sharePrice, _timestamp: block.timestamp});

        // Set the fee
        vm.prank(admin);
        if (_entrance) {
            feeHandler.setEntranceFee({_feeBps: feeBps, _recipient: feeRecipient});
        } else {
            feeHandler.setExitFee({_feeBps: feeBps, _recipient: feeRecipient});
        }

        // Event returns the value amount (not shares)
        vm.expectEmit(address(feeHandler));
        if (_entrance) {
            emit FeeHandler.EntranceFeeSettled({recipient: feeRecipient, value: expectedFeevalue});
        } else {
            emit FeeHandler.ExitFeeSettled({recipient: feeRecipient, value: expectedFeevalue});
        }

        // 1st settlement
        vm.prank(address(shares));
        uint256 feeSharesAmount;
        if (_entrance) {
            feeSharesAmount = feeHandler.settleEntranceFee({_grossSharesAmount: grossSharesAmount});
        } else {
            feeSharesAmount = feeHandler.settleExitFee({_grossSharesAmount: grossSharesAmount});
        }

        // Return value is the shares amount, but value owed is in value asset
        assertEq(feeSharesAmount, expectedFeeSharesAmount);
        if (_burn) {
            assertEq(feeHandler.getTotalValueOwed(), 0);
        } else {
            assertEq(feeHandler.getTotalValueOwed(), expectedFeevalue);
            assertEq(feeHandler.getValueOwedToUser(feeRecipient), expectedFeevalue);
        }
    }

    //==================================================================================================================
    // Helpers
    //==================================================================================================================

    function test_updateValueOwed_success_positiveDelta() public {
        __test_updateValueOwed_success({_initialOwedUserValue: 123, _delta: 456});
    }

    function test_updateValueOwed_success_negativeDelta() public {
        __test_updateValueOwed_success({_initialOwedUserValue: 456, _delta: -123});
    }

    function __test_updateValueOwed_success(uint256 _initialOwedUserValue, int256 _delta) internal {
        address owedUser = makeAddr("owedUser");
        address randomOwedUser = makeAddr("randomOwedUser");

        uint256 randomOwedUserValue = _initialOwedUserValue * 6;
        uint256 initialTotalValue = _initialOwedUserValue + randomOwedUserValue;

        feeHandler.exposed_updateValueOwed({_user: owedUser, _delta: int256(_initialOwedUserValue)});
        feeHandler.exposed_updateValueOwed({_user: randomOwedUser, _delta: int256(randomOwedUserValue)});

        uint256 expectedOwedUserValue = uint256(int256(_initialOwedUserValue) + _delta);
        uint256 expectedTotalValue = uint256(int256(initialTotalValue) + _delta);

        vm.expectEmit();
        emit FeeHandler.UserValueOwedUpdated({user: owedUser, value: expectedOwedUserValue});

        vm.expectEmit();
        emit FeeHandler.TotalValueOwedUpdated({value: expectedTotalValue});

        vm.prank(address(feeHandler));
        feeHandler.exposed_updateValueOwed({_user: owedUser, _delta: _delta});

        assertEq(feeHandler.getValueOwedToUser(owedUser), expectedOwedUserValue);
        assertEq(feeHandler.getTotalValueOwed(), expectedTotalValue);
    }
}
