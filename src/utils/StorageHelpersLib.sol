// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

/// @title StorageHelpersLib Library
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice Common utility functions for handling storage
library StorageHelpersLib {
    /// @dev https://eips.ethereum.org/EIPS/eip-7201
    function deriveErc7201Location(string memory _id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(string.concat("enzyme.", _id)))) - 1))
            & ~bytes32(uint256(0xff));
    }
}
