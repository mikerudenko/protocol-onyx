// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title Global Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice A contract for global values
/// @dev Proxy implementation
contract Global is Ownable2StepUpgradeable {
    //==================================================================================================================
    // Initialize
    //==================================================================================================================

    function init(address _owner) external initializer {
        __Ownable_init({initialOwner: _owner});
    }

    // TODO: add a timelock for ownership change?
}
