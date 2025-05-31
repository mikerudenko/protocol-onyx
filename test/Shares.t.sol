// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {Shares} from "src/shares/Shares.sol";

import {BlankFeeManager} from "test/mocks/Blanks.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract SharesInitTest is Test {
    struct TestInitParams {
        address owner;
        string name;
        string symbol;
        bytes32 valueAsset;
    }

    TestInitParams testInitParams =
        TestInitParams({owner: makeAddr("owner"), name: "Test Shares", symbol: "TST", valueAsset: keccak256("USD")});

    function test_init_fail_calledTwice() public {
        Shares shares = new Shares();

        shares.init({
            _owner: testInitParams.owner,
            _name: testInitParams.name,
            _symbol: testInitParams.symbol,
            _valueAsset: testInitParams.valueAsset
        });

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        shares.init({
            _owner: testInitParams.owner,
            _name: testInitParams.name,
            _symbol: testInitParams.symbol,
            _valueAsset: testInitParams.valueAsset
        });
    }

    function test_init_fail_noName() public {
        Shares shares = new Shares();

        vm.expectRevert(Shares.Shares__Init__EmptyName.selector);
        shares.init({
            _owner: testInitParams.owner,
            _name: "",
            _symbol: testInitParams.symbol,
            _valueAsset: testInitParams.valueAsset
        });
    }

    function test_init_fail_noSymbol() public {
        Shares shares = new Shares();

        vm.expectRevert(Shares.Shares__Init__EmptySymbol.selector);
        shares.init({
            _owner: testInitParams.owner,
            _name: testInitParams.name,
            _symbol: "",
            _valueAsset: testInitParams.valueAsset
        });
    }

    function test_init_success() public {
        Shares shares = new Shares();

        address owner = testInitParams.owner;
        string memory name = testInitParams.name;
        string memory symbol = testInitParams.symbol;
        bytes32 valueAsset = testInitParams.valueAsset;

        shares.init({_owner: owner, _name: name, _symbol: symbol, _valueAsset: valueAsset});

        assertEq(shares.owner(), owner);
        assertEq(shares.name(), name);
        assertEq(shares.symbol(), symbol);
        assertEq(shares.getValueAsset(), valueAsset);
    }
}

contract SharesTest is Test, TestHelpers {
    Shares shares;
    address owner;
    address admin = makeAddr("SharesTest.admin");

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        vm.prank(owner);
        shares.addAdmin(admin);
    }

    //==================================================================================================================
    // Config (access: owner)
    //==================================================================================================================

    function test_addAdmin_fail_alreadyAdded() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(owner);
        shares.addAdmin(newAdmin);

        // Second call should fail
        vm.expectRevert(Shares.Shares__AddAdmin__AlreadyAdded.selector);
        vm.prank(owner);
        shares.addAdmin(newAdmin);
    }

    function test_addAdmin_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newAdmin = makeAddr("newAdmin");

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, randomUser));
        vm.prank(randomUser);
        shares.addAdmin(newAdmin);
    }

    function test_addAdmin_success() public {
        address newAdmin = makeAddr("newAdmin");

        assertFalse(shares.isAdmin(newAdmin));

        vm.expectEmit(address(shares));
        emit Shares.AdminAdded(newAdmin);

        vm.prank(owner);
        shares.addAdmin(newAdmin);

        assertTrue(shares.isAdmin(newAdmin));
    }

    function test_removeAdmin_fail_alreadyRemoved() public {
        address newAdmin = makeAddr("newAdmin");

        vm.expectRevert(Shares.Shares__RemoveAdmin__AlreadyRemoved.selector);
        vm.prank(owner);
        shares.removeAdmin(newAdmin);
    }

    function test_removeAdmin_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newAdmin = makeAddr("newAdmin");

        vm.prank(owner);
        shares.addAdmin(newAdmin);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, randomUser));
        vm.prank(randomUser);
        shares.removeAdmin(newAdmin);
    }

    function test_removeAdmin_success() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(owner);
        shares.addAdmin(newAdmin);

        vm.expectEmit(address(shares));
        emit Shares.AdminRemoved(newAdmin);

        vm.prank(owner);
        shares.removeAdmin(newAdmin);

        assertFalse(shares.isAdmin(newAdmin));
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_isAdminOrOwner_success() public {
        address randomUser = makeAddr("randomUser");

        assertTrue(shares.isAdminOrOwner(owner));
        assertTrue(shares.isAdminOrOwner(admin));
        assertFalse(shares.isAdminOrOwner(randomUser));
    }

    function test_setValueAsset_fail_empty() public {
        vm.expectRevert(Shares.Shares__SetValueAsset__Empty.selector);

        vm.prank(admin);
        shares.setValueAsset("");
    }

    function test_setValueAsset_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setValueAsset("test");
    }

    function test_setValueAsset_success() public {
        bytes32 newValueAsset = keccak256("test_setValueAsset");

        vm.expectEmit(address(shares));
        emit Shares.ValueAssetSet(newValueAsset);

        vm.prank(admin);
        shares.setValueAsset(newValueAsset);

        assertEq(shares.getValueAsset(), newValueAsset);
    }

    // ASSET SOURCES AND DESTINATIONS

    function test_setDepositAssetsDest_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newDepositAssetsDest = makeAddr("newDepositAssetsDest");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setDepositAssetsDest(newDepositAssetsDest);
    }

    function test_setDepositAssetsDest_success() public {
        address newDepositAssetsDest = makeAddr("newDepositAssetsDest");

        vm.expectEmit(address(shares));
        emit Shares.DepositAssetsDestSet(newDepositAssetsDest);

        vm.prank(admin);
        shares.setDepositAssetsDest(newDepositAssetsDest);

        assertEq(shares.getDepositAssetsDest(), newDepositAssetsDest);
    }

    function test_setFeeAssetsSrc_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newFeeAssetsSrc = makeAddr("newFeeAssetsSrc");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setFeeAssetsSrc(newFeeAssetsSrc);
    }

    function test_setFeeAssetsSrc_success() public {
        address newFeeAssetsSrc = makeAddr("newFeeAssetsSrc");

        vm.expectEmit(address(shares));
        emit Shares.FeeAssetsSrcSet(newFeeAssetsSrc);

        vm.prank(admin);
        shares.setFeeAssetsSrc(newFeeAssetsSrc);

        assertEq(shares.getFeeAssetsSrc(), newFeeAssetsSrc);
    }

    function test_setRedeemAssetsSrc_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newRedeemAssetsSrc = makeAddr("newRedeemAssetsSrc");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setRedeemAssetsSrc(newRedeemAssetsSrc);
    }

    function test_setRedeemAssetsSrc_success() public {
        address newRedeemAssetsSrc = makeAddr("newRedeemAssetsSrc");

        vm.expectEmit(address(shares));
        emit Shares.RedeemAssetsSrcSet(newRedeemAssetsSrc);

        vm.prank(admin);
        shares.setRedeemAssetsSrc(newRedeemAssetsSrc);

        assertEq(shares.getRedeemAssetsSrc(), newRedeemAssetsSrc);
    }

    // SYSTEM CONTRACTS

    function test_addDepositHandler_fail_alreadyAdded() public {
        address newDepositHandler = makeAddr("newDepositHandler");

        vm.prank(admin);
        shares.addDepositHandler(newDepositHandler);

        // Second call should fail
        vm.expectRevert(Shares.Shares__AddDepositHandler__AlreadyAdded.selector);
        vm.prank(admin);
        shares.addDepositHandler(newDepositHandler);
    }

    function test_addDepositHandler_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newDepositHandler = makeAddr("newDepositHandler");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.addDepositHandler(newDepositHandler);
    }

    function test_addDepositHandler_success() public {
        address newDepositHandler = makeAddr("newDepositHandler");

        vm.expectEmit(address(shares));
        emit Shares.DepositHandlerAdded(newDepositHandler);

        vm.prank(admin);
        shares.addDepositHandler(newDepositHandler);

        assertTrue(shares.isDepositHandler(newDepositHandler));
    }

    function test_addRedeemHandler_fail_alreadyAdded() public {
        address newRedeemHandler = makeAddr("newRedeemHandler");

        vm.prank(admin);
        shares.addRedeemHandler(newRedeemHandler);

        // Second call should fail
        vm.expectRevert(Shares.Shares__AddRedeemHandler__AlreadyAdded.selector);
        vm.prank(admin);
        shares.addRedeemHandler(newRedeemHandler);
    }

    function test_addRedeemHandler_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newRedeemHandler = makeAddr("newRedeemHandler");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.addRedeemHandler(newRedeemHandler);
    }

    function test_addRedeemHandler_success() public {
        address newRedeemHandler = makeAddr("newRedeemHandler");

        vm.expectEmit(address(shares));
        emit Shares.RedeemHandlerAdded(newRedeemHandler);

        vm.prank(admin);
        shares.addRedeemHandler(newRedeemHandler);

        assertTrue(shares.isRedeemHandler(newRedeemHandler));
    }

    function test_removeDepositHandler_fail_alreadyRemoved() public {
        address newDepositHandler = makeAddr("newDepositHandler");

        vm.expectRevert(Shares.Shares__RemoveDepositHandler__AlreadyRemoved.selector);
        vm.prank(admin);
        shares.removeDepositHandler(newDepositHandler);
    }

    function test_removeDepositHandler_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newDepositHandler = makeAddr("newDepositHandler");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.removeDepositHandler(newDepositHandler);
    }

    function test_removeDepositHandler_success() public {
        address newDepositHandler = makeAddr("newDepositHandler");

        vm.prank(admin);
        shares.addDepositHandler(newDepositHandler);

        vm.expectEmit(address(shares));
        emit Shares.DepositHandlerRemoved(newDepositHandler);

        vm.prank(admin);
        shares.removeDepositHandler(newDepositHandler);

        assertFalse(shares.isDepositHandler(newDepositHandler));
    }

    function test_removeRedeemHandler_fail_alreadyRemoved() public {
        address newRedeemHandler = makeAddr("newRedeemHandler");

        vm.expectRevert(Shares.Shares__RemoveRedeemHandler__AlreadyRemoved.selector);
        vm.prank(admin);
        shares.removeRedeemHandler(newRedeemHandler);
    }

    function test_removeRedeemHandler_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newRedeemHandler = makeAddr("newRedeemHandler");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.removeRedeemHandler(newRedeemHandler);
    }

    function test_removeRedeemHandler_success() public {
        address newRedeemHandler = makeAddr("newRedeemHandler");

        vm.prank(admin);
        shares.addRedeemHandler(newRedeemHandler);

        vm.expectEmit(address(shares));
        emit Shares.RedeemHandlerRemoved(newRedeemHandler);

        vm.prank(admin);
        shares.removeRedeemHandler(newRedeemHandler);

        assertFalse(shares.isRedeemHandler(newRedeemHandler));
    }

    function test_setFeeManager_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newFeeManager = makeAddr("newFeeManager");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setFeeManager(newFeeManager);
    }

    function test_setFeeManager_success() public {
        address newFeeManager = makeAddr("newFeeManager");

        vm.expectEmit(address(shares));
        emit Shares.FeeManagerSet(newFeeManager);

        vm.prank(admin);
        shares.setFeeManager(newFeeManager);

        assertEq(shares.getFeeManager(), newFeeManager);
    }

    function test_setShareValueHandler_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newShareValueHandler = makeAddr("newShareValueHandler");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setShareValueHandler(newShareValueHandler);
    }

    function test_setShareValueHandler_success() public {
        address newShareValueHandler = makeAddr("newShareValueHandler");

        vm.expectEmit(address(shares));
        emit Shares.ShareValueHandlerSet(newShareValueHandler);

        vm.prank(admin);
        shares.setShareValueHandler(newShareValueHandler);

        assertEq(shares.getShareValueHandler(), newShareValueHandler);
    }

    // SHARES HOLDING

    function test_addAllowedHolder_fail_alreadyAdded() public {
        address newHolder = makeAddr("newHolder");

        vm.prank(admin);
        shares.addAllowedHolder(newHolder);

        // Second call should fail
        vm.expectRevert(Shares.Shares__AddAllowedHolder__AlreadyAdded.selector);
        vm.prank(admin);
        shares.addAllowedHolder(newHolder);
    }

    function test_addAllowedHolder_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newAllowedHolder = makeAddr("newAllowedHolder");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.addAllowedHolder(newAllowedHolder);
    }

    function test_addAllowedHolder_success() public {
        address newHolder = makeAddr("newHolder");

        vm.expectEmit(address(shares));
        emit Shares.AllowedHolderAdded(newHolder);

        vm.prank(admin);
        shares.addAllowedHolder(newHolder);

        assertTrue(shares.isAllowedHolder(newHolder));
    }

    function test_removeAllowedHolder_fail_alreadyRemoved() public {
        address newHolder = makeAddr("newHolder");

        vm.expectRevert(Shares.Shares__RemoveAllowedHolder__AlreadyRemoved.selector);
        vm.prank(admin);
        shares.removeAllowedHolder(newHolder);
    }

    function test_removeAllowedHolder_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        address newAllowedHolder = makeAddr("newAllowedHolder");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.removeAllowedHolder(newAllowedHolder);
    }

    function test_removeAllowedHolder_success() public {
        address newHolder = makeAddr("newHolder");

        vm.prank(admin);
        shares.addAllowedHolder(newHolder);

        vm.expectEmit(address(shares));
        emit Shares.AllowedHolderRemoved(newHolder);

        vm.prank(admin);
        shares.removeAllowedHolder(newHolder);

        assertFalse(shares.isAllowedHolder(newHolder));
    }

    function test_setHolderRestriction_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");
        Shares.HolderRestriction newRestriction = Shares.HolderRestriction.RestrictedWithTransfers;

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.setHolderRestriction(newRestriction);
    }

    function test_setHolderRestriction_success() public {
        // Use non-zero value (i.e., not "None")
        Shares.HolderRestriction newRestriction = Shares.HolderRestriction.RestrictedWithTransfers;
        assertNotEq(uint8(shares.getHolderRestriction()), uint8(newRestriction));

        vm.expectEmit(address(shares));
        emit Shares.HolderRestrictionSet(newRestriction);

        vm.prank(admin);
        shares.setHolderRestriction(newRestriction);

        assertEq(uint8(shares.getHolderRestriction()), uint8(newRestriction));
    }

    //==================================================================================================================
    // Valuation
    //==================================================================================================================

    function test_sharePrice_success_nonZeroValue() public {
        __test_sharePrice_success({_shareValue: 123, _expectedSharePrice: 123, _valueTimestamp: 456});
    }

    function test_sharePrice_success_zeroValue() public {
        __test_sharePrice_success({_shareValue: 0, _expectedSharePrice: 1e18, _valueTimestamp: 123});
    }

    function __test_sharePrice_success(uint256 _shareValue, uint256 _expectedSharePrice, uint256 _valueTimestamp)
        public
    {
        // Set share value handler
        address shareValueHandler = makeAddr("shareValueHandler");
        vm.prank(admin);
        shares.setShareValueHandler(shareValueHandler);

        shareValueHandler_mockGetShareValue({
            _shareValueHandler: shareValueHandler,
            _shareValue: _shareValue,
            _timestamp: _valueTimestamp
        });

        (uint256 price, uint256 timestamp) = shares.sharePrice();

        assertEq(price, _expectedSharePrice);
        assertEq(timestamp, _valueTimestamp);
    }

    //==================================================================================================================
    // Transfer
    //==================================================================================================================

    enum TestTransferRecipientType {
        Random,
        HolderAllowlist,
        RedeemHandler
    }

    function test_transferRules_success_unrestricted() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.None,
            _recipientType: TestTransferRecipientType.Random,
            _expectSuccess: true
        });
    }

    function test_transferRules_fail_restrictedWithTransfers_randomUser() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.RestrictedWithTransfers,
            _recipientType: TestTransferRecipientType.Random,
            _expectSuccess: false
        });
    }

    function test_transferRules_success_restrictedWithTransfers_holderAllowlist() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.RestrictedWithTransfers,
            _recipientType: TestTransferRecipientType.HolderAllowlist,
            _expectSuccess: true
        });
    }

    function test_transferRules_success_restrictedWithTransfers_redeemHandler() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.RestrictedWithTransfers,
            _recipientType: TestTransferRecipientType.RedeemHandler,
            _expectSuccess: true
        });
    }

    function test_transferRules_fail_restrictedNoTransfers_randomUser() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.RestrictedNoTransfers,
            _recipientType: TestTransferRecipientType.Random,
            _expectSuccess: false
        });
    }

    function test_transferRules_fail_restrictedNoTransfers_holderAllowlist() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.RestrictedNoTransfers,
            _recipientType: TestTransferRecipientType.HolderAllowlist,
            _expectSuccess: false
        });
    }

    function test_transferRules_success_restrictedNoTransfers_redeemHandler() public {
        __test_transferRules({
            _holderRestriction: Shares.HolderRestriction.RestrictedNoTransfers,
            _recipientType: TestTransferRecipientType.RedeemHandler,
            _expectSuccess: true
        });
    }

    function __test_transferRules(
        Shares.HolderRestriction _holderRestriction,
        TestTransferRecipientType _recipientType,
        bool _expectSuccess
    ) internal {
        address from = makeAddr("__test_transfer:from");
        address to = makeAddr("__test_transfer:to");

        // Give recipient necessary role
        if (_recipientType == TestTransferRecipientType.HolderAllowlist) {
            // Add to holder allowlist
            vm.prank(owner);
            shares.addAllowedHolder(to);
        } else if (_recipientType == TestTransferRecipientType.RedeemHandler) {
            // Add as redeem handler
            vm.prank(owner);
            shares.addRedeemHandler(to);
        }

        // Set specified HolderRestriction
        vm.prank(owner);
        shares.setHolderRestriction(_holderRestriction);

        // Assert getter
        assertEq(shares.isAllowedTransferRecipient(to), _expectSuccess);

        // Test both transfer() and transferFrom() functions
        __test_transferRules_assertTransfer({_from: from, _to: to, _expectSuccess: _expectSuccess, _transferFrom: false});
        __test_transferRules_assertTransfer({_from: from, _to: to, _expectSuccess: _expectSuccess, _transferFrom: true});
    }

    function __test_transferRules_assertTransfer(address _from, address _to, bool _expectSuccess, bool _transferFrom)
        internal
    {
        // Give _from shares balance to transfer
        uint256 amount = 100;
        deal({token: address(shares), to: _from, give: amount, adjust: true});

        // Grant approval to test contract to call transferFrom()
        vm.prank(_from);
        shares.approve(address(this), amount);

        uint256 prevRecipientBalance = shares.balanceOf(_to);

        if (!_expectSuccess) {
            vm.expectRevert(Shares.Shares__ValidateTransferRecipient__NotAllowed.selector);
        }

        if (_transferFrom) {
            shares.transferFrom(_from, _to, amount);
        } else {
            vm.prank(_from);
            shares.transfer(_to, amount);
        }

        if (_expectSuccess) {
            assertEq(shares.balanceOf(_to), prevRecipientBalance + amount);
        }
    }

    // NO RULES

    function test_authTransfer_fail_unauthorized() public {
        address randomUser = makeAddr("authTransfer:randomUser");

        vm.expectRevert(Shares.Shares__AuthTransfer__Unauthorized.selector);

        vm.prank(randomUser);
        shares.authTransfer({_to: address(0), _amount: 0});
    }

    function test_authTransfer_success_depositHandler() public {
        address depositHandler = makeAddr("authTransfer:depositHandler");

        vm.prank(owner);
        shares.addDepositHandler(depositHandler);

        __test_authTransfer_success({_from: depositHandler});
    }

    function test_authTransfer_success_redeemHandler() public {
        address redeemHandler = makeAddr("authTransfer:redeemHandler");

        vm.prank(owner);
        shares.addRedeemHandler(redeemHandler);

        __test_authTransfer_success({_from: redeemHandler});
    }

    /// @dev Should not be subject to transfer rules
    function __test_authTransfer_success(address _from) internal {
        address to = makeAddr("authTransfer:to");

        uint256 fromBalance = 100;
        uint256 toBalance = 70;
        uint256 transferAmount = 10;

        // Seed `_from` and `to` with shares
        deal({token: address(shares), to: _from, give: fromBalance, adjust: true});
        deal({token: address(shares), to: to, give: toBalance, adjust: true});

        // Use strictest holder restriction
        vm.prank(owner);
        shares.setHolderRestriction(Shares.HolderRestriction.RestrictedNoTransfers);

        // Auth transfer `_from` => `to`
        vm.prank(_from);
        shares.authTransfer({_to: to, _amount: transferAmount});

        assertEq(shares.balanceOf(_from), fromBalance - transferAmount);
        assertEq(shares.balanceOf(to), toBalance + transferAmount);
    }

    function test_forceTransferFrom_fail_unauthorized() public {
        address randomUser = makeAddr("forceTransferFrom:randomUser");

        vm.expectRevert(Shares.Shares__OnlyAdminOrOwner__Unauthorized.selector);

        vm.prank(randomUser);
        shares.forceTransferFrom({_from: address(0), _to: address(0), _amount: 0});
    }

    /// @dev Should not be subject to transfer rules
    function test_forceTransferFrom_success() public {
        address from = makeAddr("forceTransfer:from");
        address to = makeAddr("forceTransfer:to");

        uint256 fromBalance = 100;
        uint256 toBalance = 70;
        uint256 transferAmount = 10;

        deal({token: address(shares), to: from, give: fromBalance, adjust: true});
        deal({token: address(shares), to: to, give: toBalance, adjust: true});

        // Use strictest holder restriction
        vm.prank(owner);
        shares.setHolderRestriction(Shares.HolderRestriction.RestrictedNoTransfers);

        vm.prank(owner);
        shares.forceTransferFrom({_from: from, _to: to, _amount: transferAmount});

        assertEq(shares.balanceOf(from), fromBalance - transferAmount);
        assertEq(shares.balanceOf(to), toBalance + transferAmount);
    }

    //==================================================================================================================
    // Depositor rules
    //==================================================================================================================

    enum TestDepositRecipientType {
        Random,
        HolderAllowlist
    }

    function test_isAllowedDepositRecipient_success_unrestricted() public {
        __test_isAllowedDepositRecipient({
            _holderRestriction: Shares.HolderRestriction.None,
            _recipientType: TestDepositRecipientType.Random,
            _expectSuccess: true
        });
    }

    function test_isAllowedDepositRecipient_fail_restrictedWithTransfers_randomUser() public {
        __test_isAllowedDepositRecipient({
            _holderRestriction: Shares.HolderRestriction.RestrictedWithTransfers,
            _recipientType: TestDepositRecipientType.Random,
            _expectSuccess: false
        });
    }

    function test_isAllowedDepositRecipient_success_restrictedWithTransfers_holderAllowlist() public {
        __test_isAllowedDepositRecipient({
            _holderRestriction: Shares.HolderRestriction.RestrictedWithTransfers,
            _recipientType: TestDepositRecipientType.HolderAllowlist,
            _expectSuccess: true
        });
    }

    function test_isAllowedDepositRecipient_fail_restrictedNoTransfers_randomUser() public {
        __test_isAllowedDepositRecipient({
            _holderRestriction: Shares.HolderRestriction.RestrictedNoTransfers,
            _recipientType: TestDepositRecipientType.Random,
            _expectSuccess: false
        });
    }

    function test_isAllowedDepositRecipient_success_restrictedNoTransfers_holderAllowlist() public {
        __test_isAllowedDepositRecipient({
            _holderRestriction: Shares.HolderRestriction.RestrictedNoTransfers,
            _recipientType: TestDepositRecipientType.HolderAllowlist,
            _expectSuccess: true
        });
    }

    function __test_isAllowedDepositRecipient(
        Shares.HolderRestriction _holderRestriction,
        TestDepositRecipientType _recipientType,
        bool _expectSuccess
    ) internal {
        address to = makeAddr("__test_isAllowedDepositRecipient:to");

        // Give recipient necessary role
        if (_recipientType == TestDepositRecipientType.HolderAllowlist) {
            // Add to holder allowlist
            vm.prank(owner);
            shares.addAllowedHolder(to);
        }

        // Set specified HolderRestriction
        vm.prank(owner);
        shares.setHolderRestriction(_holderRestriction);

        // Assert getter
        assertEq(shares.isAllowedDepositRecipient(to), _expectSuccess);
    }

    //==================================================================================================================
    // Shares issuance and asset transfers
    //==================================================================================================================

    function test_mintFor_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(Shares.Shares__OnlyDepositHandler__Unauthorized.selector);

        vm.prank(randomUser);
        shares.mintFor({_to: address(0), _grossSharesAmount: 0, _skipFee: false});
    }

    function test_mintFor_success_noFeeManager() public {
        __test_mintFor_success({_grossSharesAmount: 100, _feeSharesAmount: 2, _hasFeeManager: false, _skipFee: false});
    }

    function test_mintFor_success_skipFee() public {
        __test_mintFor_success({_grossSharesAmount: 100, _feeSharesAmount: 2, _hasFeeManager: true, _skipFee: true});
    }

    function test_mintFor_success_withFee() public {
        __test_mintFor_success({_grossSharesAmount: 100, _feeSharesAmount: 2, _hasFeeManager: true, _skipFee: false});
    }

    function __test_mintFor_success(
        uint256 _grossSharesAmount,
        uint256 _feeSharesAmount,
        bool _hasFeeManager,
        bool _skipFee
    ) internal {
        uint256 expectedNetSharesAmount =
            _skipFee || !_hasFeeManager ? _grossSharesAmount : _grossSharesAmount - _feeSharesAmount;

        address to = makeAddr("mintFor:to");
        address depositHandler = makeAddr("mintFor:depositHandler");
        vm.prank(owner);
        shares.addDepositHandler(depositHandler);

        if (_hasFeeManager) {
            IFeeManager feeManager = new BlankFeeManager();
            vm.prank(owner);
            shares.setFeeManager(address(feeManager));

            feeManager_mockSettleEntranceFee({_feeManager: address(feeManager), _feeSharesAmount: _feeSharesAmount});
        }

        vm.prank(depositHandler);
        uint256 netSharesAmount = shares.mintFor({_to: to, _grossSharesAmount: _grossSharesAmount, _skipFee: _skipFee});

        // Minted amount and net amount should both be gross shares
        assertEq(netSharesAmount, expectedNetSharesAmount);
        assertEq(shares.balanceOf(to), expectedNetSharesAmount);
    }

    function test_burnFor_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(Shares.Shares__OnlyRedeemHandler__Unauthorized.selector);

        vm.prank(randomUser);
        shares.burnFor({_from: address(0), _grossSharesAmount: 0, _skipFee: false});
    }

    function test_burnFor_success_noFeeManager() public {
        __test_burnFor_success({_grossSharesAmount: 100, _feeSharesAmount: 2, _hasFeeManager: false, _skipFee: false});
    }

    function test_burnFor_success_skipFee() public {
        __test_burnFor_success({_grossSharesAmount: 100, _feeSharesAmount: 2, _hasFeeManager: true, _skipFee: true});
    }

    function test_burnFor_success_withFee() public {
        __test_burnFor_success({_grossSharesAmount: 100, _feeSharesAmount: 2, _hasFeeManager: true, _skipFee: false});
    }

    function __test_burnFor_success(
        uint256 _grossSharesAmount,
        uint256 _feeSharesAmount,
        bool _hasFeeManager,
        bool _skipFee
    ) internal {
        uint256 expectedNetSharesAmount =
            _skipFee || !_hasFeeManager ? _grossSharesAmount : _grossSharesAmount - _feeSharesAmount;

        // Mint some shares to `from`
        address from = makeAddr("burnFor:from");
        uint256 initialFromBalance = 100;
        deal({token: address(shares), to: from, give: initialFromBalance, adjust: true});

        address redeemHandler = makeAddr("burnFor:redeemHandler");
        vm.prank(owner);
        shares.addRedeemHandler(redeemHandler);

        if (_hasFeeManager) {
            IFeeManager feeManager = new BlankFeeManager();
            vm.prank(owner);
            shares.setFeeManager(address(feeManager));

            feeManager_mockSettleExitFee({_feeManager: address(feeManager), _feeSharesAmount: _feeSharesAmount});
        }

        vm.prank(redeemHandler);
        uint256 netSharesAmount =
            shares.burnFor({_from: from, _grossSharesAmount: _grossSharesAmount, _skipFee: _skipFee});

        // Burned balance should be gross shares, return value should be net shares
        assertEq(netSharesAmount, expectedNetSharesAmount);
        assertEq(shares.balanceOf(from), initialFromBalance - _grossSharesAmount);
    }

    function test_withdrawRedeemAssetTo_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(Shares.Shares__OnlyRedeemHandler__Unauthorized.selector);

        vm.prank(randomUser);
        shares.withdrawRedeemAssetTo({_asset: address(0), _to: address(0), _amount: 0});
    }

    function test_withdrawRedeemAssetTo_success() public {
        MockERC20 mockToken = new MockERC20(18);
        address to = makeAddr("withdrawRedeemAssetTo:to");
        uint256 amount = 123;
        uint256 srcInitialBalance = amount * 11;

        address redeemAssetsSrc = makeAddr("withdrawRedeemAssetTo:redeemAssetsSrc");
        vm.prank(owner);
        shares.setRedeemAssetsSrc(redeemAssetsSrc);

        // Send some token to redeem assets src
        mockToken.mintTo(redeemAssetsSrc, srcInitialBalance);

        // Grant max allowance to shares
        vm.prank(redeemAssetsSrc);
        mockToken.approve(address(shares), type(uint256).max);

        address redeemHandler = makeAddr("withdrawRedeemAssetTo:redeemHandler");
        vm.prank(owner);
        shares.addRedeemHandler(redeemHandler);

        vm.prank(redeemHandler);
        shares.withdrawRedeemAssetTo({_asset: address(mockToken), _to: to, _amount: amount});

        assertEq(mockToken.balanceOf(redeemAssetsSrc), srcInitialBalance - amount);
        assertEq(mockToken.balanceOf(to), amount);
    }

    function test_withdrawFeeAssetTo_fail_unauthorized() public {
        address randomUser = makeAddr("randomUser");

        vm.expectRevert(Shares.Shares__OnlyFeeManager__Unauthorized.selector);

        vm.prank(randomUser);
        shares.withdrawFeeAssetTo({_asset: address(0), _to: address(0), _amount: 0});
    }

    function test_withdrawFeeAssetTo_success() public {
        MockERC20 mockToken = new MockERC20(18);
        address to = makeAddr("withdrawFeeAssetTo:to");
        uint256 amount = 123;
        uint256 srcInitialBalance = amount * 11;

        address feeAssetsSrc = makeAddr("withdrawFeeAssetTo:feeAssetsSrc");
        vm.prank(owner);
        shares.setFeeAssetsSrc(feeAssetsSrc);

        // Send some token to redeem assets src
        mockToken.mintTo(feeAssetsSrc, srcInitialBalance);

        // Grant max allowance to shares
        vm.prank(feeAssetsSrc);
        mockToken.approve(address(shares), type(uint256).max);

        address feeManager = makeAddr("withdrawFeeAssetTo:feeManager");
        vm.prank(owner);
        shares.setFeeManager(address(feeManager));

        vm.prank(feeManager);
        shares.withdrawFeeAssetTo({_asset: address(mockToken), _to: to, _amount: amount});

        assertEq(mockToken.balanceOf(feeAssetsSrc), srcInitialBalance - amount);
        assertEq(mockToken.balanceOf(to), amount);
    }
}
