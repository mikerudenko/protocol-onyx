# Onyx Protocol Invariant Testing

This directory contains comprehensive invariant tests for the Onyx Protocol using the Recon framework and Echidna fuzzer.

## Overview

The invariant testing suite covers the following critical system components:

### Core System Components
- **Shares Contract**: ERC20 token with role-based access control
- **FeeHandler**: Management of entrance, exit, management, and performance fees
- **ValuationHandler**: Asset pricing and share value calculations
- **Position Trackers**: ERC20 balance tracking and linear credit/debt tracking
- **Issuance System**: Deposit and redemption queues

### Key Invariants Tested

#### 🔒 **Value Conservation**
- Total system value equals sum of share values and fees owed
- Asset balances are properly tracked across contracts
- No value can be created or destroyed unexpectedly

#### 💰 **Fee System Integrity**
- Fee calculations are mathematically sound
- Fee rates remain within reasonable bounds (≤100%)
- Management and performance fees accrue correctly
- Fee distribution maintains system consistency

#### 📊 **Share Price Stability**
- Share price remains positive when shares exist
- Share price stays within reasonable bounds
- Share value calculations are consistent

#### 🛡️ **Access Control**
- Only authorized handlers can mint/burn shares
- Admin roles are properly maintained
- System configuration remains valid

#### 🔄 **Position Tracking**
- Position tracker values correlate with actual holdings
- ERC20 tracker values are non-negative
- Credit/debt tracking remains within bounds

## File Structure

```
test/recon/
├── README.md                 # This file
├── echidna.yaml             # Echidna configuration
├── CryticTester.sol         # Main test contract
├── Setup.sol                # System setup and initialization
├── Properties.sol           # Core invariant properties
├── BeforeAfter.sol          # State tracking (ghost variables)
├── TargetFunctions.sol      # Target function aggregator
└── targets/
    ├── AdminTargets.sol     # Admin actions for state exploration
    ├── FeeTargets.sol       # Fee system interactions
    ├── IssuanceTargets.sol  # Deposit/redeem operations
    ├── SharesTargets.sol    # Share transfer operations
    ├── ValuationTargets.sol # Valuation system interactions
    ├── ManagersTargets.sol  # Actor and asset management
    └── DoomsdayTargets.sol  # Edge case testing
```

## Prerequisites

1. **Foundry**: Latest version with Solidity 0.8.28 support
2. **Echidna**: Install from [crytic/echidna](https://github.com/crytic/echidna)
3. **Recon Framework**: Ensure recon dependencies are available

## Running the Tests

### Quick Start

```bash
# Run Echidna with default configuration
echidna . --contract CryticTester --config test/recon/echidna.yaml

# Run with more verbose output
echidna . --contract CryticTester --config test/recon/echidna.yaml --format text

# Run with parallel workers for faster execution
echidna . --contract CryticTester --config test/recon/echidna.yaml --workers 4
```

### Advanced Usage

```bash
# Extended test run (1 hour, 100k tests)
echidna . --contract CryticTester --config test/recon/echidna.yaml --test-limit 100000 --timeout 3600

# Run with coverage analysis
echidna . --contract CryticTester --config test/recon/echidna.yaml --coverage

# Run specific property patterns
echidna . --contract CryticTester --config test/recon/echidna.yaml --filter-functions "echidna_value_.*"
```

### Using Medusa (Alternative Fuzzer)

```bash
# Run with Medusa
medusa fuzz --target test/recon/CryticTester.sol --config test/recon/medusa.json
```

## Understanding the Results

### Successful Run
```
echidna_value_conservation: PASSED
echidna_share_price_stability: PASSED
echidna_fee_math_soundness: PASSED
echidna_access_control_integrity: PASSED
```

### Failed Invariant
```
echidna_value_conservation: FAILED
  Call sequence:
    admin_setManagementFeeRate(5000)
    fee_settleDynamicFees(1000000000000000000000)
    shares_transferBetweenActors(500000000000000000000)
```

When an invariant fails, Echidna provides the exact sequence of function calls that led to the violation.

## Key Properties Explained

### `echidna_value_conservation`
Ensures that the total value in the system (share value + fees owed) remains consistent and doesn't exceed reasonable bounds.

### `echidna_share_price_stability`
Verifies that share prices remain positive and within reasonable ranges (1e12 to 1e24 wei per share).

### `echidna_fee_math_soundness`
Checks that fee calculations don't result in fees exceeding system value or other mathematical inconsistencies.

### `echidna_access_control_integrity`
Validates that access control mechanisms remain intact throughout all operations.

## Customization

### Adding New Properties
1. Add property functions to `Properties.sol` with `property_` prefix
2. Add Echidna-specific properties to `CryticTester.sol` with `echidna_` prefix

### Adding New Target Functions
1. Create new target files in `targets/` directory
2. Import and inherit in `TargetFunctions.sol`
3. Use `updateGhosts` modifier for state tracking

### Modifying Configuration
Edit `echidna.yaml` to adjust:
- Test limits and timeouts
- Gas limits
- Sender addresses
- Dictionary values for better fuzzing

## Troubleshooting

### Common Issues

1. **Compilation Errors**: Ensure all dependencies are properly installed and remappings are correct
2. **Out of Gas**: Increase `txGas` and `blockGas` in `echidna.yaml`
3. **Slow Execution**: Reduce `testLimit` or increase `workers`
4. **False Positives**: Review property logic and add appropriate bounds/conditions

### Debug Mode
```bash
# Run with debug output
echidna . --contract CryticTester --config test/recon/echidna.yaml --format json > results.json
```

## Best Practices

1. **Property Design**: Focus on economic properties and value flows
2. **Bounds Checking**: Always bound fuzzer inputs to realistic ranges
3. **State Exploration**: Use admin functions to explore different system states
4. **Incremental Testing**: Start with simple properties and gradually add complexity
5. **Regular Runs**: Integrate into CI/CD pipeline for continuous testing

## Contributing

When adding new invariants:
1. Follow the existing naming conventions
2. Add comprehensive comments explaining the property
3. Include appropriate bounds and edge case handling
4. Test locally before submitting

## Resources

- [Recon Book](https://book.getrecon.xyz/) - Comprehensive guide to invariant testing
- [Echidna Documentation](https://github.com/crytic/echidna) - Fuzzer documentation
- [Trail of Bits Blog](https://blog.trailofbits.com/) - Advanced testing techniques
