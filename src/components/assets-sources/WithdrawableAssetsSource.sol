// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";

/// @title WithdrawableAssetsSource Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice A holding contract for use as a particular Shares instance's "fee assets" and or "redeem assets" source
contract WithdrawableAssetsSource is ComponentHelpersMixin {
    using SafeERC20 for IERC20;

    event AssetApproved(address asset);

    event AssetWithdrawn(address asset, address to, uint256 amount);

    /// @notice Grants a max allowance to the Shares contract for the given ERC20 token
    /// @dev Callable by: anybody
    function approveMaxToShares(address _asset) external {
        IERC20(_asset).forceApprove(__getShares(), type(uint256).max);

        emit AssetApproved(_asset);
    }

    /// @notice Withdraws the specified amount of the given asset to the specified address
    /// @dev Allows rescuing asset surplus
    function withdrawAsset(address _asset, address _to, uint256 _amount) external onlyAdminOrOwner {
        IERC20(_asset).safeTransfer(_to, _amount);

        emit AssetWithdrawn({asset: _asset, to: _to, amount: _amount});
    }
}
