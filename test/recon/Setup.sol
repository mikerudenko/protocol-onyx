// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Core contracts
import {Shares} from "src/shares/Shares.sol";
import {FeeHandler} from "src/components/fees/FeeHandler.sol";
import {ValuationHandler} from "src/components/value/ValuationHandler.sol";
import {AccountERC20Tracker} from "src/components/value/position-trackers/AccountERC20Tracker.sol";
import {LinearCreditDebtTracker} from "src/components/value/position-trackers/LinearCreditDebtTracker.sol";
import {ERC7540LikeDepositQueue} from "src/components/issuance/deposit-handlers/ERC7540LikeDepositQueue.sol";
import {ERC7540LikeRedeemQueue} from "src/components/issuance/redeem-handlers/ERC7540LikeRedeemQueue.sol";

// Test harnesses
import {ValuationHandlerHarness} from "test/harnesses/ValuationHandlerHarness.sol";
import {ContinuousFlatRateManagementFeeTrackerHarness} from "test/harnesses/ContinuousFlatRateManagementFeeTrackerHarness.sol";
import {ContinuousFlatRatePerformanceFeeTrackerHarness} from "test/harnesses/ContinuousFlatRatePerformanceFeeTrackerHarness.sol";
import {FeeHandlerHarness} from "test/harnesses/FeeHandlerHarness.sol";
import {LinearCreditDebtTrackerHarness} from "test/harnesses/LinearCreditDebtTrackerHarness.sol";
import {ERC7540LikeDepositQueueHarness} from "test/harnesses/ERC7540LikeDepositQueueHarness.sol";
import {ERC7540LikeRedeemQueueHarness} from "test/harnesses/ERC7540LikeRedeemQueueHarness.sol";

// Fee trackers
import {ContinuousFlatRateManagementFeeTracker} from "src/components/fees/management-fee-trackers/ContinuousFlatRateManagementFeeTracker.sol";
import {ContinuousFlatRatePerformanceFeeTracker} from "src/components/fees/performance-fee-trackers/ContinuousFlatRatePerformanceFeeTracker.sol";

// Factories
import {ComponentBeaconFactory} from "src/factories/ComponentBeaconFactory.sol";
import {Global} from "src/global/Global.sol";

// Test mocks
import {MockERC20} from "@recon/MockERC20.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    // Core system contracts
    Shares public shares;
    FeeHandlerHarness public feeHandler;
    ValuationHandler public valuationHandler;
    Global public global;
    ComponentBeaconFactory public componentFactory;

    // Position trackers
    AccountERC20Tracker public erc20Tracker;
    LinearCreditDebtTrackerHarness public creditDebtTracker;

    // Issuance handlers
    ERC7540LikeDepositQueueHarness public depositQueue;
    ERC7540LikeRedeemQueueHarness public redeemQueue;

    // Fee trackers
    ContinuousFlatRateManagementFeeTrackerHarness public managementFeeTracker;
    ContinuousFlatRatePerformanceFeeTrackerHarness public performanceFeeTracker;

    // Test assets
    MockERC20 public asset1;
    MockERC20 public asset2;
    MockERC20 public feeAsset;

    // Key addresses
    address public admin;
    address public feeRecipient;
    address public testAccount;

    /// === Setup === ///
    function setup() internal virtual override {
        // Setup key addresses
        admin = address(this);
        feeRecipient = address(0x1337);
        testAccount = address(0x4444);

        // Deploy Global and factory
        global = new Global();
        global.init(admin);
        componentFactory = new ComponentBeaconFactory(address(global));

        // Deploy test assets
        asset1 = new MockERC20("Test Asset 1", "TST1", 18);
        asset2 = new MockERC20("Test Asset 2", "TST2", 6);
        feeAsset = new MockERC20("Fee Asset", "FEE", 18);

        // Deploy core Shares contract
        shares = new Shares();
        shares.init(admin, "Test Shares", "TSHARES", bytes32("USD"));

        // Deploy and setup ValuationHandler (using harness for testing)
        valuationHandler = ValuationHandler(address(new ValuationHandlerHarness(address(shares))));
        shares.setValuationHandler(address(valuationHandler));

        // Set asset rates for valuation (1:1 with USD for simplicity)
        valuationHandler.setAssetRate(ValuationHandler.AssetRateInput({
            asset: address(asset1),
            rate: 1e18,
            expiry: uint40(block.timestamp + 1 days)
        }));
        valuationHandler.setAssetRate(ValuationHandler.AssetRateInput({
            asset: address(asset2),
            rate: 1e18,
            expiry: uint40(block.timestamp + 1 days)
        }));
        valuationHandler.setAssetRate(ValuationHandler.AssetRateInput({
            asset: address(feeAsset),
            rate: 1e18,
            expiry: uint40(block.timestamp + 1 days)
        }));

        // Deploy fee trackers (using harnesses for testing)
        managementFeeTracker = new ContinuousFlatRateManagementFeeTrackerHarness(address(shares));
        performanceFeeTracker = new ContinuousFlatRatePerformanceFeeTrackerHarness(address(shares));

        // Deploy and setup FeeHandler (using harness for testing)
        feeHandler = new FeeHandlerHarness(address(shares));
        feeHandler.setFeeAsset(address(feeAsset));
        feeHandler.setManagementFee(address(managementFeeTracker), feeRecipient);
        feeHandler.setPerformanceFee(address(performanceFeeTracker), feeRecipient);
        shares.setFeeHandler(address(feeHandler));

        // Deploy position trackers
        erc20Tracker = new AccountERC20Tracker();
        erc20Tracker.init(testAccount);  // Initialize with the account to track
        erc20Tracker.addAsset(address(asset1));
        erc20Tracker.addAsset(address(asset2));

        creditDebtTracker = new LinearCreditDebtTrackerHarness(address(shares));

        // Add position trackers to valuation handler
        valuationHandler.addPositionTracker(address(erc20Tracker));
        valuationHandler.addPositionTracker(address(creditDebtTracker));

        // Deploy issuance handlers (using harnesses for testing)
        depositQueue = new ERC7540LikeDepositQueueHarness(address(shares));
        depositQueue.setAsset(address(asset1));

        redeemQueue = new ERC7540LikeRedeemQueueHarness(address(shares));

        // Setup roles
        shares.addDepositHandler(address(depositQueue));
        shares.addRedeemHandler(address(redeemQueue));
        shares.addAdmin(admin);

        // Mint initial assets for testing
        asset1.mint(testAccount, 1000000e18);
        asset2.mint(testAccount, 1000000e6);
        feeAsset.mint(address(feeHandler), 1000000e18);

        // Initial shares mint for non-zero supply
        shares.mintFor(admin, 1000e18);
    }

    /// === MODIFIERS === ///
    modifier asAdmin {
        vm.prank(admin);
        _;
    }

    modifier asActor {
        vm.prank(address(_getActor()));
        _;
    }

    modifier asFeeRecipient {
        vm.prank(feeRecipient);
        _;
    }

    modifier asTestAccount {
        vm.prank(testAccount);
        _;
    }
}
