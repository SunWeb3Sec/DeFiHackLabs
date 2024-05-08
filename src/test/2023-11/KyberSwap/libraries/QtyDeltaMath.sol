// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {MathConstants as C} from './MathConstants.sol';
import {TickMath} from './TickMath.sol';
import {FullMath} from './FullMath.sol';
import {SafeCast} from './SafeCast.sol';

/// @title Contains helper functions for calculating
/// token0 and token1 quantites from differences in prices
/// or from burning reinvestment tokens
library QtyDeltaMath {
  using SafeCast for uint256;
  using SafeCast for int128;

  function calcUnlockQtys(uint160 initialSqrtP)
    internal
    pure
    returns (uint256 qty0, uint256 qty1)
  {
    qty0 = FullMath.mulDivCeiling(C.MIN_LIQUIDITY, C.TWO_POW_96, initialSqrtP);
    qty1 = FullMath.mulDivCeiling(C.MIN_LIQUIDITY, initialSqrtP, C.TWO_POW_96);
  }

  /// @notice Gets the qty0 delta between two prices
  /// @dev Calculates liquidity / sqrt(lower) - liquidity / sqrt(upper),
  /// i.e. liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
  /// rounds up if adding liquidity, rounds down if removing liquidity
  /// @param lowerSqrtP The lower sqrt price.
  /// @param upperSqrtP The upper sqrt price. Should be >= lowerSqrtP
  /// @param liquidity Liquidity quantity
  /// @param isAddLiquidity true = add liquidity, false = remove liquidity
  /// @return token0 qty required for position with liquidity between the 2 sqrt prices
  function calcRequiredQty0(
    uint160 lowerSqrtP,
    uint160 upperSqrtP,
    uint128 liquidity,
    bool isAddLiquidity
  ) internal pure returns (int256) {
    uint256 numerator1 = uint256(liquidity) << C.RES_96;
    uint256 numerator2;
    unchecked {
      numerator2 = upperSqrtP - lowerSqrtP;
    }
    return
      isAddLiquidity
        ? (divCeiling(FullMath.mulDivCeiling(numerator1, numerator2, upperSqrtP), lowerSqrtP))
          .toInt256()
        : (FullMath.mulDivFloor(numerator1, numerator2, upperSqrtP) / lowerSqrtP).revToInt256();
  }

  /// @notice Gets the token1 delta quantity between two prices
  /// @dev Calculates liquidity * (sqrt(upper) - sqrt(lower))
  /// rounds up if adding liquidity, rounds down if removing liquidity
  /// @param lowerSqrtP The lower sqrt price.
  /// @param upperSqrtP The upper sqrt price. Should be >= lowerSqrtP
  /// @param liquidity Liquidity quantity
  /// @param isAddLiquidity true = add liquidity, false = remove liquidity
  /// @return token1 qty required for position with liquidity between the 2 sqrt prices
  function calcRequiredQty1(
    uint160 lowerSqrtP,
    uint160 upperSqrtP,
    uint128 liquidity,
    bool isAddLiquidity
  ) internal pure returns (int256) {
    unchecked {
      return
        isAddLiquidity
          ? (FullMath.mulDivCeiling(liquidity, upperSqrtP - lowerSqrtP, C.TWO_POW_96)).toInt256()
          : (FullMath.mulDivFloor(liquidity, upperSqrtP - lowerSqrtP, C.TWO_POW_96)).revToInt256();
    }
  }

  /// @notice Calculates the token0 quantity proportion to be sent to the user
  /// for burning reinvestment tokens
  /// @param sqrtP Current pool sqrt price
  /// @param liquidity Difference in reinvestment liquidity due to reinvestment token burn
  /// @return token0 quantity to be sent to the user
  function getQty0FromBurnRTokens(uint160 sqrtP, uint256 liquidity)
    internal
    pure
    returns (uint256)
  {
    return FullMath.mulDivFloor(liquidity, C.TWO_POW_96, sqrtP);
  }

  /// @notice Calculates the token1 quantity proportion to be sent to the user
  /// for burning reinvestment tokens
  /// @param sqrtP Current pool sqrt price
  /// @param liquidity Difference in reinvestment liquidity due to reinvestment token burn
  /// @return token1 quantity to be sent to the user
  function getQty1FromBurnRTokens(uint160 sqrtP, uint256 liquidity)
    internal
    pure
    returns (uint256)
  {
    return FullMath.mulDivFloor(liquidity, sqrtP, C.TWO_POW_96);
  }

  /// @notice Returns ceil(x / y)
  /// @dev division by 0 has unspecified behavior, and must be checked externally
  /// @param x The dividend
  /// @param y The divisor
  /// @return z The quotient, ceil(x / y)
  function divCeiling(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // return x / y + ((x % y == 0) ? 0 : 1);
    require(y > 0);
    assembly {
      z := add(div(x, y), gt(mod(x, y), 0))
    }
  }
}
