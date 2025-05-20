// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

/// @title IDepositHandler Interface
/// @author Enzyme Foundation <security@enzyme.finance>
interface IDepositHandler {
    enum DepositHandlerType {
        Misc,
        SingleAssetQueue
    }

    /// @notice Returns the category of the deposit handler
    /// @return handlerType_ The DepositHandlerType value
    /// @dev Used to discover instances by category, with common interfaces and behaviors
    function getDepositHandlerType() external view returns (DepositHandlerType handlerType_);
}
