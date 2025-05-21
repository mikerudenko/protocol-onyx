// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IPositionTracker} from "src/interfaces/IPositionTracker.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";

/// @title LinearCreditDebtTracker Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice An IPositionTracker implementation that tracks linear credit and/or debt positions
contract LinearCreditDebtTracker is IPositionTracker, ComponentHelpersMixin {
    //==================================================================================================================
    // Types
    //==================================================================================================================

    struct Item {
        // 1st slot
        uint24 id;
        uint24 index;
        int128 settledValue;
        // 2nd slot
        int128 totalValue;
        uint64 start;
        uint64 duration; // in seconds
    }

    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 private immutable LINEAR_CREDIT_DEBT_TRACKER_STORAGE_LOCATION =
        StorageHelpersLib.deriveErc7201Location("LinearCreditDebtTracker");

    /// @custom:storage-location erc7201:enzyme.LinearCreditDebtTracker
    struct LinearCreditDebtTrackerStorage {
        uint24 lastItemId; // starts from 1
        uint24[] ids;
        mapping(uint24 => Item) idToItem;
    }

    function __getLinearCreditDebtTrackerStorage() private view returns (LinearCreditDebtTrackerStorage storage $) {
        bytes32 location = LINEAR_CREDIT_DEBT_TRACKER_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event ItemAdded(uint24 id, int128 totalValue, uint64 start, uint64 duration);

    event ItemRemoved(uint24 id);

    event ItemTotalSettledUpdated(uint24 id, int128 totalSettled);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error LinearCreditDebtTracker__AddItem__EmptyTotalValue();

    error LinearCreditDebtTracker__RemoveItem__DoesNotExist();

    error LinearCreditDebtTracker__UpdateSettledValue__DoesNotExist();

    //==================================================================================================================
    // Item management (access: Shares admin or owner)
    //==================================================================================================================

    /// @dev _duration of 0, indicate a discrete value change at their timestamp
    function addItem(int128 _totalValue, uint64 _start, uint64 _duration)
        external
        onlyAdminOrOwner
        returns (uint24 id_)
    {
        require(_totalValue != 0, LinearCreditDebtTracker__AddItem__EmptyTotalValue());

        LinearCreditDebtTrackerStorage storage $ = __getLinearCreditDebtTrackerStorage();
        id_ = ++$.lastItemId; // first item will be `id_ = 1`
        uint24 index = uint24(getItemsCount());

        $.ids.push(id_);
        $.idToItem[id_] =
            Item({id: id_, index: index, settledValue: 0, totalValue: _totalValue, start: _start, duration: _duration});

        emit ItemAdded({id: id_, totalValue: _totalValue, start: _start, duration: _duration});
    }

    function removeItem(uint24 _id) external onlyAdminOrOwner {
        Item memory item = getItem({_id: _id});
        require(item.id != 0, LinearCreditDebtTracker__RemoveItem__DoesNotExist());

        LinearCreditDebtTrackerStorage storage $ = __getLinearCreditDebtTrackerStorage();
        uint256 finalIndex = getItemsCount() - 1;
        if (item.index != finalIndex) {
            Item memory finalItem = __getItemAtIndex({_index: finalIndex});
            // move final item to old item's index
            $.ids[item.index] = finalItem.id;
            $.idToItem[finalItem.id].index = item.index;
        }
        $.ids.pop();
        delete $.idToItem[_id];

        emit ItemRemoved({id: _id});
    }

    function updateSettledValue(uint24 _id, int128 _totalSettled) external onlyAdminOrOwner {
        require(getItem({_id: _id}).id != 0, LinearCreditDebtTracker__UpdateSettledValue__DoesNotExist());

        LinearCreditDebtTrackerStorage storage $ = __getLinearCreditDebtTrackerStorage();
        $.idToItem[_id].settledValue = _totalSettled;

        emit ItemTotalSettledUpdated({id: _id, totalSettled: _totalSettled});
    }

    //==================================================================================================================
    // Position value
    //==================================================================================================================

    function getPositionValue() external view override returns (int256 value_) {
        uint24[] memory ids = getItemIds();
        for (uint256 i; i < ids.length; i++) {
            Item memory item = getItem({_id: ids[i]});

            value_ += calcItemValue({_item: item});
        }

        return value_;
    }

    function calcItemValue(Item memory _item) public view returns (int256 value_) {
        // Handle cases outside of start and stop bounds
        if (block.timestamp <= _item.start) {
            return _item.settledValue;
        } else if (block.timestamp >= _item.start + _item.duration) {
            return _item.settledValue + _item.totalValue;
        }

        uint256 lapsed = block.timestamp - _item.start;

        int256 proRatedValue = _item.totalValue * int256(lapsed) / int256(uint256(_item.duration));

        return _item.settledValue + proRatedValue;
    }

    //==================================================================================================================
    // Misc
    //==================================================================================================================

    function __getItemAtIndex(uint256 _index) internal view returns (Item memory item_) {
        return getItem({_id: __getLinearCreditDebtTrackerStorage().ids[_index]});
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    function getItem(uint24 _id) public view returns (Item memory item_) {
        return __getLinearCreditDebtTrackerStorage().idToItem[_id];
    }

    function getItemIds() public view returns (uint24[] memory ids_) {
        return __getLinearCreditDebtTrackerStorage().ids;
    }

    function getItemsCount() public view returns (uint256 count_) {
        return __getLinearCreditDebtTrackerStorage().ids.length;
    }

    function getLastItemId() public view returns (uint24 id_) {
        return __getLinearCreditDebtTrackerStorage().lastItemId;
    }
}
