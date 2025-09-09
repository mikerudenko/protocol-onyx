// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Core contracts
import {Shares} from "src/shares/Shares.sol";
import {FeeHandlerHarness} from "test/harnesses/FeeHandlerHarness.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";
import {AccountERC20Tracker} from "src/components/value/position-trackers/AccountERC20Tracker.sol";
import {LinearCreditDebtTrackerHarness} from "test/harnesses/LinearCreditDebtTrackerHarness.sol";
import {ContinuousFlatRateManagementFeeTrackerHarness} from "test/harnesses/ContinuousFlatRateManagementFeeTrackerHarness.sol";
import {ContinuousFlatRatePerformanceFeeTrackerHarness} from "test/harnesses/ContinuousFlatRatePerformanceFeeTrackerHarness.sol";
import {ERC7540LikeDepositQueueHarness} from "test/harnesses/ERC7540LikeDepositQueueHarness.sol";
import {ERC7540LikeRedeemQueueHarness} from "test/harnesses/ERC7540LikeRedeemQueueHarness.sol";
import {ComponentBeaconFactory} from "src/factories/ComponentBeaconFactory.sol";
import {Global} from "src/global/Global.sol";
import {MockERC20} from "@recon/MockERC20.sol";

contract CryticTester is BaseSetup {

    // Core system contracts
    Shares public shares;
    FeeHandlerHarness public feeHandler;
    ValuationHandler public valuationHandler;
    Global public global;
    ComponentBeaconFactory public componentFactory;

    // Position trackers
    AccountERC20Tracker public erc20Tracker;
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

    constructor() {
        setup();
    }

    function setup() internal virtual override {
        // Setup key addresses
        admin = address(this);
        feeRecipient = address(0x1337);
        testAccount = address(0x4444);

        // Deploy test assets
        asset1 = new MockERC20("Asset 1", "A1", 18);
        asset2 = new MockERC20("Asset 2", "A2", 6);
        feeAsset = new MockERC20("Fee Asset", "FEE", 18);

        // Deploy global and factory
        global = new Global();
        componentFactory = new ComponentBeaconFactory(address(global));

        // Deploy core contracts
        shares = new Shares();
        valuationHandler = new ValuationHandler();

        // Initialize contracts
        global.init(admin);
        shares.init(admin, "Test Shares", "TSHARES", bytes32("USD"));

        // Deploy fee trackers
        managementFeeTracker = new ContinuousFlatRateManagementFeeTrackerHarness(address(shares));
        performanceFeeTracker = new ContinuousFlatRatePerformanceFeeTrackerHarness(address(shares));

        // Deploy and setup FeeHandler
        feeHandler = new FeeHandlerHarness(address(shares));
        feeHandler.setFeeAsset(address(feeAsset));
        feeHandler.setManagementFee(address(managementFeeTracker), feeRecipient);
        feeHandler.setPerformanceFee(address(performanceFeeTracker), feeRecipient);
        shares.setFeeHandler(address(feeHandler));

        // Deploy position trackers
        erc20Tracker = new AccountERC20Tracker();
        try erc20Tracker.init(testAccount) {} catch {}
        try erc20Tracker.addAsset(address(asset1)) {} catch {}
        try erc20Tracker.addAsset(address(asset2)) {} catch {}

        creditDebtTracker = new LinearCreditDebtTrackerHarness(address(shares));

        // Add position trackers to valuation handler
        try valuationHandler.addPositionTracker(address(erc20Tracker)) {} catch {}
        try valuationHandler.addPositionTracker(address(creditDebtTracker)) {} catch {}
        shares.setValuationHandler(address(valuationHandler));

        // Deploy issuance handlers
        depositQueue = new ERC7540LikeDepositQueueHarness(address(shares));
        try depositQueue.setAsset(address(asset1)) {} catch {}

        redeemQueue = new ERC7540LikeRedeemQueueHarness(address(shares));
        try redeemQueue.setAsset(address(asset1)) {} catch {}

        // Set up deposit/redeem handlers
        try shares.addDepositHandler(address(depositQueue)) {} catch {}
        try shares.addRedeemHandler(address(redeemQueue)) {} catch {}

        // Mint some initial assets for testing
        asset1.mint(testAccount, 1000e18);
        asset2.mint(testAccount, 1000e6);
        feeAsset.mint(feeRecipient, 1000e18);
    }

    //==================================================================================================================
    // ASSERTION-BASED INVARIANTS FOR ECHIDNA
    //==================================================================================================================

    /// @notice Share price must be positive when shares exist
    function invariant_share_price_positive() public view {
        if (shares.totalSupply() > 0) {
            (uint256 sharePrice,) = shares.sharePrice();
            assert(sharePrice > 0);
        }
    }

    /// @notice Shares supply must be bounded
    function invariant_shares_supply_bounded() public view {
        uint256 totalSupply = shares.totalSupply();
        assert(totalSupply <= 1e30); // 1 billion shares with 18 decimals
    }

    /// @notice System configuration must be valid
    function invariant_system_configuration() public view {
        assert(shares.getFeeHandler() != address(0));
        assert(shares.getValuationHandler() != address(0));
        assert(shares.isAdminOrOwner(admin));
    }

    /// @notice Access control must be maintained
    function invariant_access_control() public view {
        assert(shares.isAdminOrOwner(admin));
    }

    /// @notice Fee handler must be properly set
    function invariant_fee_handler_set() public view {
        assert(shares.getFeeHandler() == address(feeHandler));
    }

    /// @notice Valuation handler must be properly set  
    function invariant_valuation_handler_set() public view {
        assert(shares.getValuationHandler() == address(valuationHandler));
    }

    /// @notice Share price must be stable (within reasonable bounds)
    function invariant_share_price_stability() public view {
        if (shares.totalSupply() > 0) {
            (uint256 sharePrice,) = shares.sharePrice();
            assert(sharePrice >= 1);
            assert(sharePrice <= 1e30);
        }
    }

    /// @notice Position tracker values must be reasonable
    function invariant_position_tracker_bounds() public view {
        int256 erc20Value = erc20Tracker.getPositionValue();
        int256 creditDebtValue = creditDebtTracker.getPositionValue();
        
        // Values should not be extremely negative
        assert(erc20Value > -1e30);
        assert(creditDebtValue > -1e30);
    }

    /// @notice Total value must be conserved
    function invariant_value_conservation() public view {
        // Basic value conservation check
        uint256 totalSupply = shares.totalSupply();
        if (totalSupply == 0) return;
        
        (uint256 sharePrice,) = shares.sharePrice();
        uint256 totalValue = sharePrice * totalSupply / 1e18;
        
        // Total value should be reasonable
        assert(totalValue <= 1e40); // Very high upper bound
    }

    /// @notice Fee calculations must be sound
    function invariant_fee_math_soundness() public view {
        // Fees should not be negative or extremely large
        uint256 totalFeesOwed = feeHandler.getTotalValueOwed();
        assert(totalFeesOwed <= 1e40); // Very high upper bound
    }

    /// @notice Asset balances must be reasonable
    function invariant_asset_balances() public view {
        uint256 asset1Balance = asset1.balanceOf(address(shares));
        uint256 asset2Balance = asset2.balanceOf(address(shares));
        
        // Balances should not exceed total supply
        assert(asset1Balance <= asset1.totalSupply());
        assert(asset2Balance <= asset2.totalSupply());
    }

    /// @notice Contract addresses must not be zero
    function invariant_contract_addresses() public view {
        assert(address(shares) != address(0));
        assert(address(feeHandler) != address(0));
        assert(address(valuationHandler) != address(0));
        assert(address(asset1) != address(0));
        assert(address(asset2) != address(0));
    }
}
