// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.0;

import {IChainlinkAggregator} from "src/interfaces/external/IChainlinkAggregator.sol";
import {SHARES_PRECISION, VALUE_ASSET_PRECISION} from "src/utils/Constants.sol";

/// @title ValueHelpersLib Library
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice Common utility functions for handling value calculations
library ValueHelpersLib {
    error ValueHelpersLib__ParseValidatedRateFromAggregatorV3__InvalidAnswer(int256 answer);

    error ValueHelpersLib__ParseValidatedRateFromAggregatorV3__MinTimestampNotMet(uint256 timestamp);

    // GENERIC HELPERS

    function calcSharesAmountForValue(uint256 _valuePerShare, uint256 _value)
        internal
        pure
        returns (uint256 sharesAmount_)
    {
        return (SHARES_PRECISION * _value) / _valuePerShare;
    }

    function calcValueOfSharesAmount(uint256 _valuePerShare, uint256 _sharesAmount)
        internal
        pure
        returns (uint256 value_)
    {
        return (_valuePerShare * _sharesAmount) / SHARES_PRECISION;
    }

    function calcValuePerShare(uint256 _totalValue, uint256 _totalSharesAmount)
        internal
        pure
        returns (uint256 valuePerShare_)
    {
        return (SHARES_PRECISION * _totalValue) / _totalSharesAmount;
    }

    function convert(
        uint256 _baseAmount,
        uint256 _basePrecision,
        uint256 _quotePrecision,
        uint256 _rate,
        uint256 _ratePrecision
    ) internal pure returns (uint256 quoteAmount_) {
        return (_baseAmount * _rate * _quotePrecision) / (_ratePrecision * _basePrecision);
    }

    // CHAINLINK AGGREGATOR HELPERS

    function convertFromValueAssetWithAggregatorV3(
        uint256 _value,
        uint256 _quotePrecision,
        address _oracle,
        uint256 _oraclePrecision,
        uint256 _oracleTimestampTolerance
    ) internal view returns (uint256 quoteAmount_) {
        return convertWithAggregatorV3({
            _baseAmount: _value,
            _basePrecision: VALUE_ASSET_PRECISION,
            _quotePrecision: _quotePrecision,
            _oracle: _oracle,
            _oraclePrecision: _oraclePrecision,
            _oracleTimestampTolerance: _oracleTimestampTolerance
        });
    }

    function convertToValueAssetWithAggregatorV3(
        uint256 _baseAmount,
        uint256 _basePrecision,
        address _oracle,
        uint256 _oraclePrecision,
        uint256 _oracleTimestampTolerance
    ) internal view returns (uint256 value_) {
        return convertWithAggregatorV3({
            _baseAmount: _baseAmount,
            _basePrecision: _basePrecision,
            _quotePrecision: VALUE_ASSET_PRECISION,
            _oracle: _oracle,
            _oraclePrecision: _oraclePrecision,
            _oracleTimestampTolerance: _oracleTimestampTolerance
        });
    }

    function convertWithAggregatorV3(
        uint256 _baseAmount,
        uint256 _basePrecision,
        uint256 _quotePrecision,
        address _oracle,
        uint256 _oraclePrecision,
        uint256 _oracleTimestampTolerance
    ) internal view returns (uint256 quoteAmount_) {
        uint256 oracleRate =
            parseValidatedRateFromAggregatorV3({_aggregator: _oracle, _timestampTolerance: _oracleTimestampTolerance});

        return convert({
            _baseAmount: _baseAmount,
            _basePrecision: _basePrecision,
            _quotePrecision: _quotePrecision,
            _rate: oracleRate,
            _ratePrecision: _oraclePrecision
        });
    }

    function parseValidatedRateFromAggregatorV3(address _aggregator, uint256 _timestampTolerance)
        internal
        view
        returns (uint256 rate_)
    {
        (, int256 answer,, uint256 timestamp,) = IChainlinkAggregator(_aggregator).latestRoundData();

        require(answer > 0, ValueHelpersLib__ParseValidatedRateFromAggregatorV3__InvalidAnswer(answer));

        uint256 minTimestamp = block.timestamp - _timestampTolerance;
        require(
            timestamp >= minTimestamp,
            ValueHelpersLib__ParseValidatedRateFromAggregatorV3__MinTimestampNotMet(timestamp)
        );

        return uint256(answer);
    }
}
