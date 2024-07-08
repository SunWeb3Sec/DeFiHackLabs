// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IPoolEvents {
  /// @notice Emitted only once per pool when #initialize is first called
  /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
  /// @param sqrtP The initial price of the pool
  /// @param tick The initial tick of the pool
  event Initialize(uint160 sqrtP, int24 tick);

  /// @notice Emitted when liquidity is minted for a given position
  /// @dev transfers reinvestment tokens for any collected fees earned by the position
  /// @param sender address that minted the liquidity
  /// @param owner address of owner of the position
  /// @param tickLower position's lower tick
  /// @param tickUpper position's upper tick
  /// @param qty liquidity minted to the position range
  /// @param qty0 token0 quantity needed to mint the liquidity
  /// @param qty1 token1 quantity needed to mint the liquidity
  event Mint(
    address sender,
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 qty,
    uint256 qty0,
    uint256 qty1
  );

  /// @notice Emitted when a position's liquidity is removed
  /// @dev transfers reinvestment tokens for any collected fees earned by the position
  /// @param owner address of owner of the position
  /// @param tickLower position's lower tick
  /// @param tickUpper position's upper tick
  /// @param qty liquidity removed
  /// @param qty0 token0 quantity withdrawn from removal of liquidity
  /// @param qty1 token1 quantity withdrawn from removal of liquidity
  event Burn(
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 qty,
    uint256 qty0,
    uint256 qty1
  );

  /// @notice Emitted when reinvestment tokens are burnt
  /// @param owner address which burnt the reinvestment tokens
  /// @param qty reinvestment token quantity burnt
  /// @param qty0 token0 quantity sent to owner for burning reinvestment tokens
  /// @param qty1 token1 quantity sent to owner for burning reinvestment tokens
  event BurnRTokens(address indexed owner, uint256 qty, uint256 qty0, uint256 qty1);

  /// @notice Emitted for swaps by the pool between token0 and token1
  /// @param sender Address that initiated the swap call, and that received the callback
  /// @param recipient Address that received the swap output
  /// @param deltaQty0 Change in pool's token0 balance
  /// @param deltaQty1 Change in pool's token1 balance
  /// @param sqrtP Pool's sqrt price after the swap
  /// @param liquidity Pool's liquidity after the swap
  /// @param currentTick Log base 1.0001 of pool's price after the swap
  event Swap(
    address indexed sender,
    address indexed recipient,
    int256 deltaQty0,
    int256 deltaQty1,
    uint160 sqrtP,
    uint128 liquidity,
    int24 currentTick
  );

  /// @notice Emitted by the pool for any flash loans of token0/token1
  /// @param sender The address that initiated the flash loan, and that received the callback
  /// @param recipient The address that received the flash loan quantities
  /// @param qty0 token0 quantity loaned to the recipient
  /// @param qty1 token1 quantity loaned to the recipient
  /// @param paid0 token0 quantity paid for the flash, which can exceed qty0 + fee
  /// @param paid1 token1 quantity paid for the flash, which can exceed qty0 + fee
  event Flash(
    address indexed sender,
    address indexed recipient,
    uint256 qty0,
    uint256 qty1,
    uint256 paid0,
    uint256 paid1
  );
}
