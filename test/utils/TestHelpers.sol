// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IPositionTracker} from "src/components/value/position-trackers/IPositionTracker.sol";
import {IShareValueHandler} from "src/interfaces/IShareValueHandler.sol";
import {Shares} from "src/shares/Shares.sol";

import {BlankFeeManager, BlankPositionTracker} from "test/mocks/Blanks.sol";

contract TestHelpers is Test {
    function createShares() internal returns (Shares shares_) {
        address owner = makeAddr("owner");
        string memory name = "Test Shares";
        string memory symbol = "TST";
        bytes32 valueAsset = keccak256("USD");

        shares_ = new Shares();
        shares_.init({_owner: owner, _name: name, _symbol: symbol, _valueAsset: valueAsset});
    }

    // MOCKS: FUNCTION CALLS

    function feeManager_mockGetTotalValueOwed(address _feeManager, uint256 _totalValueOwed) internal {
        vm.mockCall(_feeManager, IFeeManager.getTotalValueOwed.selector, abi.encode(_totalValueOwed));
    }

    function feeManager_mockSettleEntranceFee(address _feeManager, uint256 _feeSharesAmount) internal {
        vm.mockCall(_feeManager, IFeeManager.settleEntranceFee.selector, abi.encode(_feeSharesAmount));
    }

    function feeManager_mockSettleExitFee(address _feeManager, uint256 _feeSharesAmount) internal {
        vm.mockCall(_feeManager, IFeeManager.settleExitFee.selector, abi.encode(_feeSharesAmount));
    }

    function positionTracker_mockGetPositionValue(address _positionTracker, int256 _value) internal {
        vm.mockCall(_positionTracker, IPositionTracker.getPositionValue.selector, abi.encode(_value));
    }

    function shareValueHandler_mockGetDefaultSharePrice(address _shareValueHandler, uint256 _defaultSharePrice)
        internal
    {
        vm.mockCall(
            _shareValueHandler, IShareValueHandler.getDefaultSharePrice.selector, abi.encode(_defaultSharePrice)
        );
    }

    function shareValueHandler_mockGetSharePrice(address _shareValueHandler, uint256 _sharePrice, uint256 _timestamp)
        internal
    {
        vm.mockCall(_shareValueHandler, IShareValueHandler.getSharePrice.selector, abi.encode(_sharePrice, _timestamp));
    }

    function shareValueHandler_mockGetShareValue(address _shareValueHandler, uint256 _shareValue, uint256 _timestamp)
        internal
    {
        vm.mockCall(_shareValueHandler, IShareValueHandler.getShareValue.selector, abi.encode(_shareValue, _timestamp));
    }

    function shares_mockSharePrice(address _shares, uint256 _sharePrice, uint256 _timestamp) internal {
        vm.mockCall(_shares, Shares.sharePrice.selector, abi.encode(_sharePrice, _timestamp));
    }

    // MOCKS: CONTRACTS

    function setMockFeeManager(address _shares, uint256 _totalValueOwed) internal returns (address feeManager_) {
        feeManager_ = address(new BlankFeeManager());

        vm.prank(Shares(_shares).owner());
        Shares(_shares).setFeeManager(feeManager_);

        feeManager_mockGetTotalValueOwed({_feeManager: feeManager_, _totalValueOwed: _totalValueOwed});
    }

    // MISC

    function increaseSharesSupply(address _shares, uint256 _increaseAmount) internal {
        // Mint shares to create desired supply
        address mintTo = makeAddr("increaseSharesSupply:mintTo");
        deal({token: _shares, to: mintTo, give: _increaseAmount, adjust: true});
    }
}
