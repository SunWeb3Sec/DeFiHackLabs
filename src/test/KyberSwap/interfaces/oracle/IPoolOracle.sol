// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IPoolOracle {
  /// @notice Owner withdrew funds in the pool oracle in case some funds are stuck there
  event OwnerWithdrew(
    address indexed owner,
    address indexed token,
    uint256 indexed amount
  );

  /// @notice Emitted by the Pool Oracle for increases to the number of observations that can be stored
  /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
  /// just before a mint/swap/burn.
  /// @param pool The pool address to update
  /// @param observationCardinalityNextOld The previous value of the next observation cardinality
  /// @param observationCardinalityNextNew The updated value of the next observation cardinality
  event IncreaseObservationCardinalityNext(
    address pool,
    uint16 observationCardinalityNextOld,
    uint16 observationCardinalityNextNew
  );

  /// @notice Initalize observation data for the caller.
  function initializeOracle(uint32 time)
    external
    returns (uint16 cardinality, uint16 cardinalityNext);

  /// @notice Write a new oracle entry into the array
  ///   and update the observation index and cardinality
  /// Read the Oralce.write function for more details
  function writeNewEntry(
    uint16 index,
    uint32 blockTimestamp,
    int24 tick,
    uint128 liquidity,
    uint16 cardinality,
    uint16 cardinalityNext
  )
    external
    returns (uint16 indexUpdated, uint16 cardinalityUpdated);

  /// @notice Write a new oracle entry into the array, take the latest observaion data as inputs
  ///   and update the observation index and cardinality
  /// Read the Oralce.write function for more details
  function write(
    uint32 blockTimestamp,
    int24 tick,
    uint128 liquidity
  )
    external
    returns (uint16 indexUpdated, uint16 cardinalityUpdated);

  /// @notice Increase the maximum number of price observations that this pool will store
  /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
  /// the input observationCardinalityNext.
  /// @param pool The pool address to be updated
  /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
  function increaseObservationCardinalityNext(
    address pool,
    uint16 observationCardinalityNext
  )
    external;

  /// @notice Returns the accumulator values as of each time seconds ago from the latest block time in the array of `secondsAgos`
  /// @dev Reverts if `secondsAgos` > oldest observation
  /// @dev It fetches the latest current tick data from the pool
  /// Read the Oracle.observe function for more details
  function observeFromPool(
    address pool,
    uint32[] memory secondsAgos
  )
    external view
    returns (int56[] memory tickCumulatives);

  /// @notice Returns the accumulator values as the time seconds ago from the latest block time of secondsAgo
  /// @dev Reverts if `secondsAgo` > oldest observation
  /// @dev It fetches the latest current tick data from the pool
  /// Read the Oracle.observeSingle function for more details
  function observeSingleFromPool(
    address pool,
    uint32 secondsAgo
  )
    external view
    returns (int56 tickCumulative);

  /// @notice Return the latest pool observation data given the pool address
  function getPoolObservation(address pool)
    external view
    returns (bool initialized, uint16 index, uint16 cardinality, uint16 cardinalityNext);

  /// @notice Returns data about a specific observation index
  /// @param pool The pool address of the observations array to fetch
  /// @param index The element of the observations array to fetch
  /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
  /// ago, rather than at a specific index in the array.
  /// @return blockTimestamp The timestamp of the observation,
  /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
  /// Returns initialized whether the observation has been initialized and the values are safe to use
  function getObservationAt(address pool, uint256 index)
    external view
    returns (
      uint32 blockTimestamp,
      int56 tickCumulative,
      bool initialized
    );
}
