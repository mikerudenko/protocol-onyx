// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {OpenAccessLimitedCallForwarder} from "src/components/roles/OpenAccessLimitedCallForwarder.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";

/// @title LimitedAccessLimitedCallForwarder Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice Executes a limited list of calls from a limited user set
/// @dev For use as an `admin` if wishing to open up specific protected actions to a subset of users
contract LimitedAccessLimitedCallForwarder is OpenAccessLimitedCallForwarder {
    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 public immutable LIMITED_ACCESS_LIMITED_CALL_FORWARDER =
        StorageHelpersLib.deriveErc7201Location("LimitedAccessLimitedCallForwarder");

    /// @custom:storage-location erc7201:enzyme.LimitedAccessLimitedCallForwarder
    struct LimitedAccessLimitedCallForwarderStorage {
        mapping(address => bool) isUser;
    }

    function __getLimitedAccessLimitedCallForwarderStorage()
        internal
        view
        returns (LimitedAccessLimitedCallForwarderStorage storage $)
    {
        bytes32 location = LIMITED_ACCESS_LIMITED_CALL_FORWARDER;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event UserAdded(address user);

    event UserRemoved(address user);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error LimitedAccessLimitedCallForwarder__AddUser__AlreadyAdded();

    error LimitedAccessLimitedCallForwarder__ExecuteCall__UnauthorizedUser();

    error LimitedAccessLimitedCallForwarder__RemoveUser__NotAdded();

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function addUser(address _user) external onlyAdminOrOwner {
        require(!isUser(_user), LimitedAccessLimitedCallForwarder__AddUser__AlreadyAdded());

        __getLimitedAccessLimitedCallForwarderStorage().isUser[_user] = true;

        emit UserAdded(_user);
    }

    function removeUser(address _user) external onlyAdminOrOwner {
        require(isUser(_user), LimitedAccessLimitedCallForwarder__RemoveUser__NotAdded());

        __getLimitedAccessLimitedCallForwarderStorage().isUser[_user] = false;

        emit UserRemoved(_user);
    }

    //==================================================================================================================
    // Calls
    //==================================================================================================================

    function executeCall(address _target, bytes calldata _data)
        public
        payable
        override
        returns (bytes memory returnData_)
    {
        require(isUser(msg.sender), LimitedAccessLimitedCallForwarder__ExecuteCall__UnauthorizedUser());

        return super.executeCall({_target: _target, _data: _data});
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    function isUser(address _who) public view returns (bool) {
        return __getLimitedAccessLimitedCallForwarderStorage().isUser[_who];
    }
}
