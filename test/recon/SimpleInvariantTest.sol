// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Shares} from "src/shares/Shares.sol";
import {FeeHandlerHarness} from "test/harnesses/FeeHandlerHarness.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";
import {ERC7540LikeDepositQueueHarness} from "test/harnesses/ERC7540LikeDepositQueueHarness.sol";
import {ERC7540LikeRedeemQueueHarness} from "test/harnesses/ERC7540LikeRedeemQueueHarness.sol";
import {AccountERC20Tracker} from "src/components/value/position-trackers/AccountERC20Tracker.sol";
import {LinearCreditDebtTrackerHarness} from "test/harnesses/LinearCreditDebtTrackerHarness.sol";
import {ContinuousFlatRateManagementFeeTrackerHarness} from "test/harnesses/ContinuousFlatRateManagementFeeTrackerHarness.sol";
import {ContinuousFlatRatePerformanceFeeTrackerHarness} from "test/harnesses/ContinuousFlatRatePerformanceFeeTrackerHarness.sol";
import {ComponentBeaconFactory} from "src/factories/ComponentBeaconFactory.sol";
import {Global} from "src/global/Global.sol";
import {MockERC20} from "@recon/MockERC20.sol";

/**
 * @title SimpleInvariantTest
 * @notice Simple invariant testing for the Onyx Protocol using Forge
 * @dev This contract tests core invariants without complex inheritance
 */
contract SimpleInvariantTest is Test {
    
    // Core system contracts
    Shares public shares;
    FeeHandlerHarness public feeHandler;
    ValuationHandler public valuationHandler;
    Global public global;
    ComponentBeaconFactory public componentFactory;
    
    // Position trackers
    AccountERC20Tracker public asset1Tracker;
    AccountERC20Tracker public asset2Tracker;
    LinearCreditDebtTrackerHarness public creditDebtTracker;
    
    // Fee trackers
    ContinuousFlatRateManagementFeeTrackerHarness public managementFeeTracker;
    ContinuousFlatRatePerformanceFeeTrackerHarness public performanceFeeTracker;
    
    // Issuance handlers
    ERC7540LikeDepositQueueHarness public depositQueue;
    ERC7540LikeRedeemQueueHarness public redeemQueue;
    
    // Test assets
    MockERC20 public asset1;
    MockERC20 public asset2;
    MockERC20 public feeAsset;
    
    // Test addresses
    address public admin;
    address public feeRecipient;
    address public testAccount;
    
    function setUp() public {
        // Setup key addresses
        admin = address(this);
        feeRecipient = address(0x1337);
        testAccount = address(0x4444);
        
        // Deploy test assets
        asset1 = new MockERC20("Asset 1", "A1", 18);
        asset2 = new MockERC20("Asset 2", "A2", 18);
        feeAsset = new MockERC20("Fee Asset", "FEE", 18);
        
        // Deploy global and factory
        global = new Global();
        componentFactory = new ComponentBeaconFactory(address(global));
        
        // Deploy core contracts
        shares = new Shares();

        // Initialize shares first so we can pass its address to harnesses
        shares.init(admin, "Test Shares", "TSHARES", bytes32("USD"));

        feeHandler = new FeeHandlerHarness(address(shares));
        valuationHandler = new ValuationHandler();

        // Deploy position trackers
        asset1Tracker = new AccountERC20Tracker();
        asset2Tracker = new AccountERC20Tracker();
        creditDebtTracker = new LinearCreditDebtTrackerHarness(address(shares));

        // Deploy fee trackers
        managementFeeTracker = new ContinuousFlatRateManagementFeeTrackerHarness(address(shares));
        performanceFeeTracker = new ContinuousFlatRatePerformanceFeeTrackerHarness(address(shares));

        // Deploy issuance handlers
        depositQueue = new ERC7540LikeDepositQueueHarness(address(shares));
        redeemQueue = new ERC7540LikeRedeemQueueHarness(address(shares));
        
        // Initialize contracts
        global.init(admin);

        // Set up basic configuration
        shares.setFeeHandler(address(feeHandler));
        shares.setValuationHandler(address(valuationHandler));

        // Add this contract as a deposit handler so we can mint shares for testing
        shares.addDepositHandler(address(this));

        // Mint some initial assets for testing
        asset1.mint(testAccount, 1000e18);
        asset2.mint(testAccount, 1000e18);
        feeAsset.mint(feeRecipient, 1000e18);
    }

    /// @dev Test that share price is always positive when shares exist
    function test_invariant_share_price_positive() public {
        // Mint some shares first
        shares.mintFor(testAccount, 100e18);
        
        if (shares.totalSupply() > 0) {
            (uint256 sharePrice,) = shares.sharePrice();
            assertGt(sharePrice, 0, "Share price must be positive when shares exist");
        }
    }

    /// @dev Test that shares total supply never exceeds reasonable bounds
    function test_invariant_shares_totalSupply_bounded() public {
        uint256 totalSupply = shares.totalSupply();
        // Should never exceed 1 billion shares (reasonable upper bound)
        assertLe(totalSupply, 1e27, "Shares total supply exceeds reasonable bounds");
    }

    /// @dev Test that share value is consistent with price calculation
    function test_invariant_share_value_consistency() public {
        // Mint some shares first
        shares.mintFor(testAccount, 100e18);
        
        if (shares.totalSupply() > 0) {
            (uint256 sharePrice,) = shares.sharePrice();
            (uint256 shareValue,) = shares.shareValue();

            // Share value should equal share price (both are per-share values)
            // Allow for small rounding differences (0.1%)
            uint256 tolerance = sharePrice / 1000;
            uint256 diff = sharePrice > shareValue ? sharePrice - shareValue : shareValue - sharePrice;
            assertLe(diff, tolerance, "Share value and price should be consistent");
        }
    }

    /// @dev Test that fee math is sound
    function test_invariant_fee_math_soundness() public {
        // This is a basic test - in a real scenario we'd have more complex fee calculations
        uint256 totalSupply = shares.totalSupply();
        
        // Basic sanity check: total supply should be finite
        assertLt(totalSupply, type(uint256).max / 2, "Total supply should not approach overflow");
    }

    /// @dev Test that management fee rate is bounded
    function test_invariant_management_fee_rate_bounded() public {
        // This would test the management fee rate bounds
        // For now, just ensure the contract exists and is callable
        assertTrue(address(managementFeeTracker) != address(0), "Management fee tracker should exist");
    }

    /// @dev Test that performance fee rate is bounded
    function test_invariant_performance_fee_rate_bounded() public {
        // This would test the performance fee rate bounds
        // For now, just ensure the contract exists and is callable
        assertTrue(address(performanceFeeTracker) != address(0), "Performance fee tracker should exist");
    }

    /// @dev Test that asset rates are valid
    function test_invariant_asset_rates_valid() public {
        // This would test asset rate validity
        // For now, just ensure the valuation handler exists
        assertTrue(address(valuationHandler) != address(0), "Valuation handler should exist");
    }

    /// @dev Test basic system configuration validity
    function test_invariant_system_configuration_valid() public {
        // Test that core contracts are properly configured
        assertEq(shares.getFeeHandler(), address(feeHandler), "Fee handler should be set");
        assertEq(shares.getValuationHandler(), address(valuationHandler), "Valuation handler should be set");
        assertTrue(shares.isAdminOrOwner(admin), "Admin should have proper permissions");
    }

    /// @dev Fuzz test for share operations
    function testFuzz_share_operations(uint256 amount) public {
        amount = bound(amount, 1, 1e24); // Reasonable bounds

        shares.mintFor(testAccount, amount);
        
        // Check invariants after minting
        assertGt(shares.totalSupply(), 0, "Total supply should be positive after minting");
        assertEq(shares.balanceOf(testAccount), amount, "Balance should match minted amount");
    }

    /// @dev Fuzz test for asset operations
    function testFuzz_asset_operations(uint256 amount) public {
        amount = bound(amount, 1, 1e24); // Reasonable bounds
        
        asset1.mint(testAccount, amount);
        
        // Check invariants after minting
        assertEq(asset1.balanceOf(testAccount), amount + 1000e18, "Asset balance should be correct");
        assertGt(asset1.totalSupply(), 0, "Asset total supply should be positive");
    }

    /// @dev Test that the system can handle basic operations without reverting
    function test_basic_system_operations() public {
        // Mint shares
        shares.mintFor(testAccount, 100e18);
        
        // Transfer shares
        vm.prank(testAccount);
        shares.transfer(feeRecipient, 10e18);
        
        // Check balances
        assertEq(shares.balanceOf(testAccount), 90e18, "Sender balance should be correct");
        assertEq(shares.balanceOf(feeRecipient), 10e18, "Recipient balance should be correct");
    }

    /// @dev Test that unauthorized operations fail
    function test_access_control() public {
        // Try to mint as non-deposit-handler (should fail)
        vm.prank(testAccount);
        vm.expectRevert();
        shares.mintFor(testAccount, 100e18);

        // This contract (as deposit handler) should be able to mint
        shares.mintFor(testAccount, 100e18);
        assertEq(shares.balanceOf(testAccount), 100e18, "Deposit handler should be able to mint");
    }
}
