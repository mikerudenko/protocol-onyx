// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";

/// @title OpenAccessLimitedCallForwarder Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice Executes a limited list of calls from any user
/// @dev For use as an `admin` if wishing to open up specific protected actions to any caller
contract OpenAccessLimitedCallForwarder is ComponentHelpersMixin {
    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 public immutable OPEN_ACCESS_LIMITED_CALL_FORWARDER =
        StorageHelpersLib.deriveErc7201Location("OpenAccessLimitedCallForwarder");

    /// @custom:storage-location erc7201:enzyme.OpenAccessLimitedCallForwarder
    struct OpenAccessLimitedCallForwarderStorage {
        mapping(address => mapping(bytes4 => bool)) targetToSelectorToCanCall;
    }

    function __getOpenAccessLimitedCallForwarderStorage()
        internal
        view
        returns (OpenAccessLimitedCallForwarderStorage storage $)
    {
        bytes32 location = OPEN_ACCESS_LIMITED_CALL_FORWARDER;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event CallAdded(address target, bytes4 selector);

    event CallRemoved(address target, bytes4 selector);

    event CallExecuted(address sender, address target, bytes data, uint256 value);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error OpenAccessLimitedCallForwarder__AddCall__AlreadyAdded();

    error OpenAccessLimitedCallForwarder__ExecuteCall__UnauthorizedCall();

    error OpenAccessLimitedCallForwarder__RemoveCall__NotAdded();

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function addCall(address _target, bytes4 _selector) external onlyAdminOrOwner {
        require(
            !canCall({_target: _target, _selector: _selector}), OpenAccessLimitedCallForwarder__AddCall__AlreadyAdded()
        );

        __getOpenAccessLimitedCallForwarderStorage().targetToSelectorToCanCall[_target][_selector] = true;

        emit CallAdded({target: _target, selector: _selector});
    }

    function removeCall(address _target, bytes4 _selector) external onlyAdminOrOwner {
        require(
            canCall({_target: _target, _selector: _selector}), OpenAccessLimitedCallForwarder__RemoveCall__NotAdded()
        );

        __getOpenAccessLimitedCallForwarderStorage().targetToSelectorToCanCall[_target][_selector] = false;

        emit CallRemoved({target: _target, selector: _selector});
    }

    //==================================================================================================================
    // Calls
    //==================================================================================================================

    function executeCall(address _target, bytes calldata _data)
        public
        payable
        virtual
        returns (bytes memory returnData_)
    {
        require(
            canCall({_target: _target, _selector: bytes4(_data[0:4])}),
            OpenAccessLimitedCallForwarder__ExecuteCall__UnauthorizedCall()
        );

        emit CallExecuted({sender: msg.sender, target: _target, data: _data, value: msg.value});

        return Address.functionCallWithValue({target: _target, data: _data, value: msg.value});
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    function canCall(address _target, bytes4 _selector) public view returns (bool) {
        return __getOpenAccessLimitedCallForwarderStorage().targetToSelectorToCanCall[_target][_selector];
    }
}
