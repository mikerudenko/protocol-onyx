// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ERC7540LikeIssuanceBase} from "src/components/issuance/utils/ERC7540LikeIssuanceBase.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {Shares} from "src/shares/Shares.sol";

import {ERC7540LikeIssuanceBaseHarness} from "test/harnesses/ERC7540LikeIssuanceBaseHarness.sol";
import {MockChainlinkAggregator} from "test/mocks/MockChainlinkAggregator.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract ERC7540LikeIssuanceBaseTest is TestHelpers {
    Shares shares;
    address owner;
    address admin = makeAddr("admin");

    ERC7540LikeIssuanceBaseHarness issuanceBase;

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        vm.prank(owner);
        shares.addAdmin(admin);

        // Deploy issuance base
        issuanceBase = new ERC7540LikeIssuanceBaseHarness(address(shares));
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_setAsset_fail_notAdminOrOwner() public {
        address randomUser = makeAddr("randomUser");
        address asset = address(new MockERC20(18));

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        issuanceBase.setAsset(asset);
    }

    function test_setAsset_fail_alreadySet() public {
        address asset = address(new MockERC20(18));

        vm.prank(admin);
        issuanceBase.setAsset(asset);

        vm.expectRevert(ERC7540LikeIssuanceBase.ERC7540LikeIssuanceBase__SetAsset__AlreadySet.selector);

        vm.prank(admin);
        issuanceBase.setAsset(asset);
    }

    function test_setAsset_success() public {
        uint8 decimals = 8;
        address asset = address(new MockERC20(decimals));

        vm.expectEmit();
        emit ERC7540LikeIssuanceBase.AssetSet({asset: asset});

        vm.prank(admin);
        issuanceBase.setAsset(asset);

        ERC7540LikeIssuanceBase.AssetInfo memory assetInfo = issuanceBase.getAssetInfo();
        assertEq(assetInfo.asset, asset);
        assertEq(assetInfo.assetDecimals, decimals);
        // IERC4626
        assertEq(issuanceBase.asset(), asset);
    }

    function test_setAssetOracle_fail_notAdminOrOwner() public {
        address randomUser = makeAddr("randomUser");
        address oracle = address(new MockChainlinkAggregator(18));

        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        issuanceBase.setAssetOracle(oracle, 0);
    }

    function test_setAssetOracle_success() public {
        uint8 oracleDecimals = 7;
        address oracle = address(new MockChainlinkAggregator(oracleDecimals));
        uint24 timestampTolerance = 100;

        vm.expectEmit();
        emit ERC7540LikeIssuanceBase.AssetOracleSet({oracle: oracle, timestampTolerance: timestampTolerance});

        vm.prank(admin);
        issuanceBase.setAssetOracle(oracle, timestampTolerance);

        ERC7540LikeIssuanceBase.OracleInfo memory oracleInfo = issuanceBase.getAssetOracleInfo();

        assertEq(oracleInfo.oracle, oracle);
        assertEq(oracleInfo.oracleTimestampTolerance, timestampTolerance);
        assertEq(oracleInfo.oracleDecimals, oracleDecimals);
    }

    //==================================================================================================================
    // IERC7575
    //==================================================================================================================

    function test_share_success() public view {
        assertEq(issuanceBase.share(), address(shares));
    }
}
