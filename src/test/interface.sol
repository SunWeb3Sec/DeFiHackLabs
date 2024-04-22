// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";

interface CheatCodes {
    // This allows us to getRecordedLogs()
    struct Log {
        bytes32[] topics;
        bytes data;
    }
    // Set block.timestamp (newTimestamp)

    function warp(uint256) external;
    // Set block.height (newHeight)
    function roll(uint256) external;
    // Set block.basefee (newBasefee)
    function fee(uint256) external;
    // Set block.coinbase (who)
    function coinbase(address) external;
    // Loads a storage slot from an address (who, slot)
    function load(address, bytes32) external returns (bytes32);
    // Stores a value to an address' storage slot, (who, slot, value)
    function store(address, bytes32, bytes32) external;
    // Signs data, (privateKey, digest) => (v, r, s)
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);
    // Derive a private key from a provided mnenomic string (or mnenomic file path) at the derivation path m/44'/60'/0'/0/{index}
    function deriveKey(string calldata, uint32) external returns (uint256);
    // Derive a private key from a provided mnenomic string (or mnenomic file path) at the derivation path {path}{index}
    function deriveKey(string calldata, string calldata, uint32) external returns (uint256);
    // Performs a foreign function call via terminal, (stringInputs) => (result)
    function ffi(string[] calldata) external returns (bytes memory);
    // Set environment variables, (name, value)
    function setEnv(string calldata, string calldata) external;
    // Read environment variables, (name) => (value)
    function envBool(string calldata) external returns (bool);
    function envUint(string calldata) external returns (uint256);
    function envInt(string calldata) external returns (int256);
    function envAddress(string calldata) external returns (address);
    function envBytes32(string calldata) external returns (bytes32);
    function envString(string calldata) external returns (string memory);
    function envBytes(string calldata) external returns (bytes memory);
    // Read environment variables as arrays, (name, delim) => (value[])
    function envBool(string calldata, string calldata) external returns (bool[] memory);
    function envUint(string calldata, string calldata) external returns (uint256[] memory);
    function envInt(string calldata, string calldata) external returns (int256[] memory);
    function envAddress(string calldata, string calldata) external returns (address[] memory);
    function envBytes32(string calldata, string calldata) external returns (bytes32[] memory);
    function envString(string calldata, string calldata) external returns (string[] memory);
    function envBytes(string calldata, string calldata) external returns (bytes[] memory);
    // Sets the *next* call's msg.sender to be the input address
    function prank(address) external;
    // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called
    function startPrank(address) external;
    // Sets the *next* call's msg.sender to be the input address, and the tx.origin to be the second input
    function prank(address, address) external;
    // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called, and the tx.origin to be the second input
    function startPrank(address, address) external;
    // Resets subsequent calls' msg.sender to be `address(this)`
    function stopPrank() external;
    // Sets an address' balance, (who, newBalance)
    function deal(address, uint256) external;
    // Sets an address' code, (who, newCode)
    function etch(address, bytes calldata) external;
    // Expects an error on next call
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
    // Record all storage reads and writes
    function record() external;
    // Gets all accessed reads and write slot from a recording session, for a given address
    function accesses(address) external returns (bytes32[] memory reads, bytes32[] memory writes);
    // Record all the transaction logs
    function recordLogs() external;
    // Gets all the recorded logs
    function getRecordedLogs() external returns (Log[] memory);
    // Prepare an expected log with (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
    // Call this function, then emit an event, then call a function. Internally after the call, we check if
    // logs were emitted in the expected order with the expected topics and data (as specified by the booleans).
    // Second form also checks supplied address against emitting contract.
    function expectEmit(bool, bool, bool, bool) external;
    function expectEmit(bool, bool, bool, bool, address) external;
    // Mocks a call to an address, returning specified data.
    // Calldata can either be strict or a partial match, e.g. if you only
    // pass a Solidity selector to the expected calldata, then the entire Solidity
    // function will be mocked.
    function mockCall(address, bytes calldata, bytes calldata) external;
    // Mocks a call to an address with a specific msg.value, returning specified data.
    // Calldata match takes precedence over msg.value in case of ambiguity.
    function mockCall(address, uint256, bytes calldata, bytes calldata) external;
    // Clears all mocked calls
    function clearMockedCalls() external;
    // Expect a call to an address with the specified calldata.
    // Calldata can either be strict or a partial match
    function expectCall(address, bytes calldata) external;
    // Expect a call to an address with the specified msg.value and calldata
    function expectCall(address, uint256, bytes calldata) external;
    // Gets the code from an artifact file. Takes in the relative path to the json file
    function getCode(string calldata) external returns (bytes memory);
    // Labels an address in call traces
    function label(address, string calldata) external;
    // If the condition is false, discard this run's fuzz inputs and generate new ones
    function assume(bool) external;
    // Set nonce for an account
    function setNonce(address, uint64) external;
    // Get nonce for an account
    function getNonce(address) external returns (uint64);
    // Set block.chainid (newChainId)
    function chainId(uint256) external;
    // Using the address that calls the test contract, has the next call (at this call depth only) create a transaction that can later be signed and sent onchain
    function broadcast() external;
    // Has the next call (at this call depth only) create a transaction with the address provided as the sender that can later be signed and sent onchain
    function broadcast(address) external;
    // Using the address that calls the test contract, has the all subsequent calls (at this call depth only) create transactions that can later be signed and sent onchain
    function startBroadcast() external;
    // Has the all subsequent calls (at this call depth only) create transactions that can later be signed and sent onchain
    function startBroadcast(address) external;
    // Stops collecting onchain transactions
    function stopBroadcast() external;
    // Reads the entire content of file to string. Path is relative to the project root. (path) => (data)
    function readFile(string calldata) external returns (string memory);
    // Reads next line of file to string, (path) => (line)
    function readLine(string calldata) external returns (string memory);
    // Writes data to file, creating a file if it does not exist, and entirely replacing its contents if it does.
    // Path is relative to the project root. (path, data) => ()
    function writeFile(string calldata, string calldata) external;
    // Writes line to file, creating a file if it does not exist.
    // Path is relative to the project root. (path, data) => ()
    function writeLine(string calldata, string calldata) external;
    // Closes file for reading, resetting the offset and allowing to read it from beginning with readLine.
    // Path is relative to the project root. (path) => ()
    function closeFile(string calldata) external;
    // Removes file. This cheatcode will revert in the following situations, but is not limited to just these cases:
    // - Path points to a directory.
    // - The file doesn't exist.
    // - The user lacks permissions to remove the file.
    // Path is relative to the project root. (path) => ()
    function removeFile(string calldata) external;

    function toString(address) external returns (string memory);
    function toString(bytes calldata) external returns (string memory);
    function toString(bytes32) external returns (string memory);
    function toString(bool) external returns (string memory);
    function toString(uint256) external returns (string memory);
    function toString(int256) external returns (string memory);
    // Snapshot the current state of the evm.
    // Returns the id of the snapshot that was created.
    // To revert a snapshot use `revertTo`
    function snapshot() external returns (uint256);
    // Revert the state of the evm to a previous snapshot
    // Takes the snapshot id to revert to.
    // This deletes the snapshot and all snapshots taken after the given snapshot id.
    function revertTo(uint256) external returns (bool);
    // Creates a new fork with the given endpoint and block and returns the identifier of the fork
    function createFork(string calldata, uint256) external returns (uint256);
    // Creates a new fork with the given endpoint and the _latest_ block and returns the identifier of the fork
    function createFork(string calldata) external returns (uint256);
    // Creates _and_ also selects a new fork with the given endpoint and block and returns the identifier of the fork
    function createSelectFork(string calldata, uint256) external returns (uint256);
    // Creates _and_ also selects a new fork with the given endpoint and the latest block and returns the identifier of the fork
    function createSelectFork(string calldata) external returns (uint256);
    // Takes a fork identifier created by `createFork` and sets the corresponding forked state as active.
    function selectFork(uint256) external;
    /// Returns the currently active fork
    /// Reverts if no fork is currently active
    function activeFork() external returns (uint256);
    // Updates the currently active fork to given block number
    // This is similar to `roll` but for the currently active fork
    function rollFork(uint256) external;
    // Updates the given fork to given block number
    function rollFork(uint256 forkId, uint256 blockNumber) external;
    /// Returns the RPC url for the given alias
    function rpcUrl(string calldata) external returns (string memory);
    /// Returns all rpc urls and their aliases `[alias, url][]`
    function rpcUrls() external returns (string[2][] memory);
    function makePersistent(address account) external;
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function withdraw(uint256 wad) external;
    function deposit(uint256 wad) external returns (bool);
    function owner() external view returns (address);
}

interface ICErc20Delegate {
    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Failure(uint256 error, uint256 info, uint256 detail);
    event LiquidateBorrow(
        address liquidator, address borrower, uint256 repayAmount, address cTokenCollateral, uint256 seizeTokens
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(address oldComptroller, address newComptroller);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event RepayBorrow(
        address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
    );
    event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function _acceptAdmin() external returns (uint256);

    function _addReserves(uint256 addAmount) external returns (uint256);

    function _becomeImplementation(bytes memory data) external;

    function _delegateCompLikeTo(address compLikeDelegatee) external;

    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function _resignImplementation() external;

    function _setComptroller(address newComptroller) external returns (uint256);

    function _setInterestRateModel(address newInterestRateModel) external returns (uint256);

    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function accrueInterest() external returns (uint256);

    function admin() external view returns (address);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function comptroller() external view returns (address);

    function decimals() external view returns (uint8);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function getCash() external view returns (uint256);

    function implementation() external view returns (address);

    function initialize(
        address underlying_,
        address comptroller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external;

    function initialize(
        address comptroller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external;

    function interestRateModel() external view returns (address);

    function isCToken() external view returns (bool);

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function name() external view returns (string memory);

    function pendingAdmin() external view returns (address);

    function protocolSeizeShareMantissa() external view returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function sweepToken(address token) external;

    function symbol() external view returns (string memory);

    function totalBorrows() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function underlying() external view returns (address);
}

interface ERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IBacon {
    function lend(uint256 index) external;

    function redeem(uint256 index) external;

    function balanceOf(address account) external view returns (uint256);
}

library DataTypesAave {
    // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        //tokens addresses
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60-63: reserved
        //bit 64-79: reserve factor
        uint256 data;
    }

    struct UserConfigurationMap {
        uint256 data;
    }

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    struct ReserveLimits {
        //The maximum amount allowed to be deposited
        uint256 depositLimit;
        //The maximum amount allowed to be borrowed
        uint256 borrowLimit;
        //The maximum amount of tokens allowed to be used as collateral for aggregate user borrowings
        uint256 collateralUsageLimit;
    }
}

interface IPriceOracleGetter {
    /**
     * @dev returns the asset price in ETH
     * @param asset the address of the asset
     * @return the ETH price of the asset
     *
     */
    function getAssetPrice(address asset) external view returns (uint256);
    /// @notice External function called by the Aave governance to set or replace sources of assets
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function setAssetSources(address[] calldata assets, address[] calldata sources) external;
    function getSourceOfAsset(address asset) external view returns (address);
    function owner() external view returns (address);
}

interface IACOWriter {
    function erc20proxy() external view returns (address);

    function weth() external view returns (address);

    function write(
        address acoToken,
        uint256 collateralAmount,
        address exchangeAddress,
        bytes memory exchangeData
    ) external payable;

    receive() external payable;
}

interface IRevest {
    struct FNFTConfig {
        address asset;
        address pipeToContract;
        uint256 depositAmount;
        uint256 depositMul;
        uint256 split;
        uint256 depositStopTime;
        bool maturityExtension;
        bool isMulti;
        bool nontransferrable;
    }

    event FNFTAddionalDeposited(
        address indexed from, uint256 indexed newFNFTId, uint256 indexed quantity, uint256 amount
    );
    event FNFTAddressLockMinted(
        address indexed asset,
        address indexed from,
        uint256 indexed fnftId,
        address trigger,
        uint256[] quantities,
        FNFTConfig fnftConfig
    );
    event FNFTMaturityExtended(address indexed from, uint256 indexed fnftId, uint256 indexed newExtendedTime);
    event FNFTSplit(address indexed from, uint256[] indexed newFNFTId, uint256[] indexed proportions, uint256 quantity);
    event FNFTTimeLockMinted(
        address indexed asset,
        address indexed from,
        uint256 indexed fnftId,
        uint256 endTime,
        uint256[] quantities,
        FNFTConfig fnftConfig
    );
    event FNFTUnlocked(address indexed from, uint256 indexed fnftId);
    event FNFTValueLockMinted(
        address indexed primaryAsset,
        address indexed from,
        uint256 indexed fnftId,
        address compareTo,
        address oracleDispatch,
        uint256[] quantities,
        FNFTConfig fnftConfig
    );
    event FNFTWithdrawn(address indexed from, uint256 indexed fnftId, uint256 indexed quantity);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function ADDRESS_LOCK_INTERFACE_ID() external view returns (bytes4);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function PAUSER_ROLE() external view returns (bytes32);

    function depositAdditionalToFNFT(uint256 fnftId, uint256 amount, uint256 quantity) external returns (uint256);

    function erc20Fee() external view returns (uint256);

    function extendFNFTMaturity(uint256 fnftId, uint256 endTime) external returns (uint256);

    function flatWeiFee() external view returns (uint256);

    function getAddressesProvider() external view returns (address);

    function getERC20Fee() external view returns (uint256);

    function getFlatWeiFee() external view returns (uint256);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function mintAddressLock(
        address trigger,
        bytes memory arguments,
        address[] memory recipients,
        uint256[] memory quantities,
        FNFTConfig memory fnftConfig
    ) external payable returns (uint256);

    function mintTimeLock(
        uint256 endTime,
        address[] memory recipients,
        uint256[] memory quantities,
        FNFTConfig memory fnftConfig
    ) external payable returns (uint256);

    function mintValueLock(
        address primaryAsset,
        address compareTo,
        uint256 unlockValue,
        bool unlockRisingEdge,
        address oracleDispatch,
        address[] memory recipients,
        uint256[] memory quantities,
        FNFTConfig memory fnftConfig
    ) external payable returns (uint256);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function setAddressRegistry(address registry) external;

    function setERC20Fee(uint256 erc20) external;

    function setFlatWeiFee(uint256 wethFee) external;

    function splitFNFT(
        uint256 fnftId,
        uint256[] memory proportions,
        uint256 quantity
    ) external returns (uint256[] memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function transferOwnership(address newOwner) external;

    function unlockFNFT(uint256 fnftId) external;

    function withdrawFNFT(uint256 fnftId, uint256 quantity) external;
}

interface AnyswapV4Router {
    function anySwapOutUnderlyingWithPermit(
        address from,
        address token,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 toChainID
    ) external;
}

interface WETH {
    function approve(address guy, uint256 wad) external returns (bool);

    function withdraw(uint256 wad) external;

    function balanceOf(address) external view returns (uint256);

    function transfer(address dst, uint256 wad) external returns (bool);
}

interface AnyswapV1ERC20 {
    function mint(address to, uint256 amount) external returns (bool);

    function burn(address from, uint256 amount) external returns (bool);

    function changeVault(address newVault) external returns (bool);

    function depositVault(uint256 amount, address to) external returns (uint256);

    function withdrawVault(address from, uint256 amount, address to) external returns (uint256);

    function underlying() external view returns (address);
}

interface IERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;

    function getManager(address _addr) external view returns (address);

    function setManager(address _addr, address _newManager) external;

    function interfaceHash(string memory _interfaceName) external pure returns (bytes32);

    function updateERC165Cache(address _contract, bytes4 _interfaceId) external;

    function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address);

    function implementsERC165InterfaceNoCache(address _contract, bytes4 _interfaceId) external view returns (bool);

    function implementsERC165Interface(address _contract, bytes4 _interfaceId) external view returns (bool);

    event InterfaceImplementerSet(address indexed addr, bytes32 indexed interfaceHash, address indexed implementer);
    event ManagerChanged(address indexed addr, address indexed newManager);
}

interface IERC777 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function granularity() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function send(address recipient, uint256 amount, bytes calldata data) external;

    function burn(uint256 amount, bytes calldata data) external;

    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);

    function authorizeOperator(address operator) external;

    function revokeOperator(address operator) external;

    function defaultOperators() external view returns (address[] memory);

    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    function operatorBurn(address account, uint256 amount, bytes calldata data, bytes calldata operatorData) external;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);

    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);

    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);

    event RevokedOperator(address indexed operator, address indexed tokenHolder);
}

interface Uni_Pair_V3 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface Uni_Pair_V2 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function MINIMUM_LIQUIDITY() external view returns (uint256);

    function PERMIT_TYPEHASH() external view returns (bytes32);

    function allowance(address, address) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function decimals() external view returns (uint8);

    function factory() external view returns (address);

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);

    function initialize(address _token0, address _token1) external;

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function name() external view returns (string memory);

    function nonces(address) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function skim(address to) external;

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;

    function symbol() external view returns (string memory);

    function sync() external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface Uni_Router_V3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable returns (uint256 amountOut);

    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    function exactInput(ExactInputParams memory params) external payable returns (uint256 amountOut);

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

interface Uni_Router_V2 {
    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function factory() external view returns (address);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    // receive () external payable;
}

interface WETH9 {
    function name() external view returns (string memory);

    function approve(address guy, uint256 wad) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(address src, address dst, uint256 wad) external returns (bool);

    function withdraw(uint256 wad) external;

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function symbol() external view returns (string memory);

    function transfer(address dst, uint256 wad) external returns (bool);

    function deposit() external payable;

    function allowance(address, address) external view returns (uint256);

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
}

interface crETH {
    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Failure(uint256 error, uint256 info, uint256 detail);
    event LiquidateBorrow(
        address liquidator, address borrower, uint256 repayAmount, address cTokenCollateral, uint256 seizeTokens
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(address oldComptroller, address newComptroller);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event RepayBorrow(
        address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
    );
    event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function _acceptAdmin() external returns (uint256);

    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function _setComptroller(address newComptroller) external returns (uint256);

    function _setInterestRateModel(address newInterestRateModel) external returns (uint256);

    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function accrueInterest() external returns (uint256);

    function admin() external view returns (address);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function comptroller() external view returns (address);

    function decimals() external view returns (uint8);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function getCash() external view returns (uint256);

    function initialize(
        address comptroller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external;

    function interestRateModel() external view returns (address);

    function isCToken() external view returns (bool);

    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;

    function mint() external payable;

    function name() external view returns (string memory);

    function pendingAdmin() external view returns (address);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function repayBorrow() external payable;

    function repayBorrowBehalf(address borrower) external payable;

    function reserveFactorMantissa() external view returns (uint256);

    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function symbol() external view returns (string memory);

    function totalBorrows() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
}

interface crAMP {
    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Failure(uint256 error, uint256 info, uint256 detail);
    event LiquidateBorrow(
        address liquidator, address borrower, uint256 repayAmount, address cTokenCollateral, uint256 seizeTokens
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(address oldComptroller, address newComptroller);
    event NewImplementation(address oldImplementation, address newImplementation);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event RepayBorrow(
        address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
    );
    event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function _acceptAdmin() external returns (uint256);

    function _addReserves(uint256 addAmount) external returns (uint256);

    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function _setComptroller(address newComptroller) external returns (uint256);

    function _setImplementation(
        address implementation_,
        bool allowResign,
        bytes memory becomeImplementationData
    ) external;

    function _setInterestRateModel(address newInterestRateModel) external returns (uint256);

    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function accrueInterest() external returns (uint256);

    function admin() external view returns (address);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function comptroller() external view returns (address);

    function decimals() external view returns (uint8);

    function delegateToImplementation(bytes memory data) external returns (bytes memory);

    function delegateToViewImplementation(bytes memory data) external view returns (bytes memory);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function getCash() external view returns (uint256);

    function implementation() external view returns (address);

    function interestRateModel() external view returns (address);

    function isCToken() external view returns (bool);

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function name() external view returns (string memory);

    function pendingAdmin() external view returns (address);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function symbol() external view returns (string memory);

    function totalBorrows() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function underlying() external view returns (address);
}

interface AMP {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ApprovalByPartition(bytes32 indexed partition, address indexed owner, address indexed spender, uint256 value);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event AuthorizedOperatorByPartition(
        bytes32 indexed partition, address indexed operator, address indexed tokenHolder
    );
    event ChangedPartition(bytes32 indexed fromPartition, bytes32 indexed toPartition, uint256 value);
    event CollateralManagerRegistered(address collateralManager);
    event Minted(address indexed operator, address indexed to, uint256 value, bytes data);
    event OwnerUpdate(address indexed oldValue, address indexed newValue);
    event OwnershipTransferAuthorization(address indexed authorizedAddress);
    event PartitionStrategySet(bytes4 flag, string name, address indexed implementation);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event Swap(address indexed operator, address indexed from, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferByPartition(
        bytes32 indexed fromPartition,
        address operator,
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data,
        bytes operatorData
    );

    function allowance(address _owner, address _spender) external view returns (uint256);

    function allowanceByPartition(
        bytes32 _partition,
        address _owner,
        address _spender
    ) external view returns (uint256);

    function approve(address _spender, uint256 _value) external returns (bool);

    function approveByPartition(bytes32 _partition, address _spender, uint256 _value) external returns (bool);

    function assumeOwnership() external;

    function authorizeOperator(address _operator) external;

    function authorizeOperatorByPartition(bytes32 _partition, address _operator) external;

    function authorizeOwnershipTransfer(address _authorizedAddress) external;

    function authorizedNewOwner() external view returns (address);

    function balanceOf(address _tokenHolder) external view returns (uint256);

    function balanceOfByPartition(bytes32 _partition, address _tokenHolder) external view returns (uint256);

    function canImplementInterfaceForAddress(bytes32 _interfaceHash, address) external view returns (bytes32);

    function collateralManagers(uint256) external view returns (address);

    function decimals() external pure returns (uint8);

    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool);

    function decreaseAllowanceByPartition(
        bytes32 _partition,
        address _spender,
        uint256 _subtractedValue
    ) external returns (bool);

    function defaultPartition() external view returns (bytes32);

    function granularity() external pure returns (uint256);

    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool);

    function increaseAllowanceByPartition(
        bytes32 _partition,
        address _spender,
        uint256 _addedValue
    ) external returns (bool);

    function isCollateralManager(address _collateralManager) external view returns (bool);

    function isOperator(address _operator, address _tokenHolder) external view returns (bool);

    function isOperatorForCollateralManager(
        bytes32 _partition,
        address _operator,
        address _collateralManager
    ) external view returns (bool);

    function isOperatorForPartition(
        bytes32 _partition,
        address _operator,
        address _tokenHolder
    ) external view returns (bool);

    function isPartitionStrategy(bytes4 _prefix) external view returns (bool);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function partitionStrategies(uint256) external view returns (bytes4);

    function partitionsOf(address _tokenHolder) external view returns (bytes32[] memory);

    function registerCollateralManager() external;

    function revokeOperator(address _operator) external;

    function revokeOperatorByPartition(bytes32 _partition, address _operator) external;

    function setPartitionStrategy(bytes4 _prefix, address _implementation) external;

    function swap(address _from) external;

    function swapToken() external view returns (address);

    function swapTokenGraveyard() external view returns (address);

    function symbol() external view returns (string memory);

    function totalPartitions() external view returns (bytes32[] memory);

    function totalSupply() external view returns (uint256);

    function totalSupplyByPartition(bytes32) external view returns (uint256);

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferByPartition(
        bytes32 _partition,
        address _from,
        address _to,
        uint256 _value,
        bytes memory _data,
        bytes memory _operatorData
    ) external returns (bytes32);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

interface IUSDC {
    function Swapin(bytes32 txhash, address account, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);
}

interface IBaseV1Router01 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IDeiLenderSolidex {
    function addCollateral(address to, uint256 amount) external;

    function borrow(
        address to,
        uint256 amount,
        uint256 price,
        uint256 timestamp,
        bytes memory reqId,
        SchnorrSign[] memory sigs
    ) external returns (uint256 debt);
}

struct SchnorrSign {
    uint256 signature;
    address owner;
    address nonce;
}

interface ISSPv4 {
    function buyDei(uint256 amountIn) external;
}

interface ILpDepositor {
    function deposit(address pool, uint256 amount) external;
}

interface IOracle {
    function getOnChainPrice() external view returns (uint256);
}

interface DVM {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;

    function init(
        address maintainer,
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 i,
        uint256 k,
        bool isOpenTWAP
    ) external;

    function _BASE_TOKEN_() external returns (address);
    function _QUOTE_TOKEN_() external returns (address);
}

interface Surge {
    function sell(uint256 tokenAmount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface USDT {
    function transfer(address to, uint256 value) external;

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external;
}

interface IMasterChef {
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawChange(address indexed user, address indexed token, uint256 change);

    function BONUS_MULTIPLIER() external view returns (uint256);

    function WETH() external view returns (address);

    function _become(address proxy) external;

    function _totalClaimed(address, uint256) external view returns (uint256);

    function _whitelist(address) external view returns (address);

    function add(
        uint256 _allocPoint,
        address _lpToken,
        uint256 _pooltype,
        address _ticket,
        bool _withUpdate
    ) external;

    function admin() external view returns (address);

    function bonusEndBlock() external view returns (uint256);

    function check_vip_limit(
        uint256 ticket_level,
        uint256 ticket_count,
        uint256 amount
    ) external view returns (uint256 allowed, uint256 overflow);

    function claimFeeRate() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function depositByAddLiquidity(uint256 _pid, address[2] memory _tokens, uint256[2] memory _amounts) external;

    function depositByAddLiquidityETH(uint256 _pid, address _token, uint256 _amount) external payable;

    function depositSingle(
        uint256 _pid,
        address _token,
        uint256 _amount,
        address[][2] memory paths,
        uint256 _minTokens
    ) external payable;

    function depositSingleTo(
        address _user,
        uint256 _pid,
        address _token,
        uint256 _amount,
        address[][2] memory paths,
        uint256 _minTokens
    ) external payable;

    function depositTo(uint256 _pid, uint256 _amount, address _user) external;

    function deposit_all_tickets(address ticket) external;

    function dev(address _devaddr) external;

    function devaddr() external view returns (address);

    function emergencyWithdraw(uint256 _pid) external;

    function farmPercent(uint256) external view returns (uint8);

    function feeDistributor() external view returns (address);

    function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);

    function implementation() external view returns (address);

    function initialize(
        address _t42,
        address _treasury,
        address _feeDistributor,
        address _devaddr,
        uint256 _bonusEndBlock,
        address _WETH,
        address _paraRouter
    ) external;

    function massUpdatePools() external;

    function migrate(uint256 _pid) external;

    function migrator() external view returns (address);

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);

    function paraRouter() external view returns (address);

    function pendingAdmin() external view returns (address);

    function pendingImplementation() external view returns (address);

    function pendingT42(uint256 _pid, address _user) external view returns (uint256 pending, uint256 fee);

    function poolInfo(uint256)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accT42PerShare,
            address ticket,
            uint256 pooltype
        );

    function poolLength() external view returns (uint256);

    function poolsTotalDeposit(uint256) external view returns (uint256);

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external;

    function setClaimFeeRate(uint256 newRate) external;

    function setFarmPercents(uint8[] memory percents) external;

    function setFeeDistributor(address _newAddress) external;

    function setMigrator(address _migrator) external;

    function setRouter(address _router) external;

    function setT42(address _t42) external;

    function setTreasury(address _treasury) external;

    function setWhitelist(address _whtie, address accpeter) external;

    function setWithdrawFeeRate(uint256 newRate) external;

    function startBlock() external view returns (uint256);

    function t42() external view returns (address);

    function t42PerBlock(uint8 index) external view returns (uint256);

    function ticket_staked_array(address who, address ticket) external view returns (uint256[] memory);

    function ticket_staked_count(address who, address ticket) external view returns (uint256);

    function ticket_stakes(address, address, uint256) external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function totalClaimed(address _user, uint256 pooltype, uint256 index) external view returns (uint256);

    function treasury() external view returns (address);

    function updatePool(uint256 _pid) external;

    function userChange(address, address) external view returns (uint256);

    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function withdraw(uint256 _pid, uint256 _amount) external;

    function withdrawAndRemoveLiquidity(uint256 _pid, uint256 _amount, bool isBNB) external;

    function withdrawChange(address[] memory tokens) external;

    function withdrawFeeRate() external view returns (uint256);

    function withdrawSingle(address tokenOut, uint256 _pid, uint256 _amount, address[][2] memory paths) external;

    function withdraw_tickets(uint256 _pid, uint256 tokenId) external;
}

interface IPancakeCallee {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeRouter {
    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function factory() external view returns (address);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    receive() external payable;
}

interface GymSinglePool {
    function depositFromOtherContract(
        uint256 _depositAmount,
        uint8 _periodId,
        bool isUnlocked,
        address _from
    ) external;

    function withdraw(uint256 _depositId) external;
}

interface GymToken {
    function approve(address spender, uint256 rawAmount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);
}

interface ILiquidityMigrationV2 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event migration(uint256 LPspended, uint256 LPrecived);

    fallback() external;

    function lpAddress() external view returns (address);

    function migrate(uint256 _lpTokens) external;

    function owner() external view returns (address);

    function renounceOwnership() external;

    function router() external view returns (address);

    function transferOwnership(address newOwner) external;

    function v1Address() external view returns (address);

    function v2Address() external view returns (address);

    function withdraw() external;

    function withdrawTokens() external;

    receive() external payable;
}

interface WBNB {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IWBNB {
    function name() external view returns (string memory);

    function approve(address guy, uint256 wad) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(address src, address dst, uint256 wad) external returns (bool);

    function withdraw(uint256 wad) external;

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function symbol() external view returns (string memory);

    function transfer(address dst, uint256 wad) external returns (bool);

    function deposit() external payable;

    function allowance(address, address) external view returns (uint256);

    fallback() external payable;

    receive() external payable;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
}

interface Pool {
    event FeesUpdated(uint256 _mintingFee, uint256 _redemptionFee);
    event MaxXftmSupplyUpdated(uint256 _value);
    event MinCollateralRatioUpdated(uint256 _minCollateralRatio);
    event Mint(address minter, uint256 amount, uint256 ftmIn, uint256 fantasmIn, uint256 fee);
    event NewCollateralRatioOptions(
        uint256 _ratioStepUp, uint256 _ratioStepDown, uint256 _priceBand, uint256 _refreshCooldown
    );
    event NewCollateralRatioSet(uint256 _cr);
    event OracleChanged(address indexed _oracle);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolUtilsChanged(address indexed _addr);
    event Recollateralized(address indexed _sender, uint256 _amount);
    event Redeem(address redeemer, uint256 amount, uint256 ftmOut, uint256 fantasmOut, uint256 fee);
    event SwapConfigUpdated(address indexed _router, uint256 _slippage, address[] _paths);
    event Toggled(bool _mintPaused, bool _redeemPaused);
    event UpdateCollateralRatioPaused(bool _collateralRatioPaused);
    event ZapMint(address minter, uint256 amount, uint256 ftmIn, uint256 fee);

    function MINTING_FEE_MAX() external view returns (uint256);

    function REDEMPTION_FEE_MAX() external view returns (uint256);

    function calcExcessFtmBalance() external view returns (uint256 _delta, bool _exceeded);

    function calcMint(
        uint256 _ftmIn,
        uint256 _fantasmIn
    ) external view returns (uint256 _xftmOut, uint256 _minFtmIn, uint256 _minFantasmIn, uint256 _fee);

    function calcRedeem(uint256 _xftmIn)
        external
        view
        returns (uint256 _ftmOut, uint256 _fantasmOut, uint256 _ftmFee, uint256 _requiredFtmBalance);

    function calcZapMint(uint256 _ftmIn)
        external
        view
        returns (uint256 _xftmOut, uint256 _fantasmOut, uint256 _ftmFee, uint256 _ftmSwapIn);

    function collateralRatio() external view returns (uint256);

    function collateralRatioPaused() external view returns (bool);

    function collect() external;

    function configSwap(address _swapRouter, uint256 _swapSlippage, address[] memory _swapPaths) external;

    function fantasm() external view returns (address);

    function feeReserve() external view returns (address);

    function info()
        external
        view
        returns (
            uint256 _collateralRatio,
            uint256 _lastRefreshCrTimestamp,
            uint256 _mintingFee,
            uint256 _redemptionFee,
            bool _mintingPaused,
            bool _redemptionPaused,
            uint256 _collateralBalance,
            uint256 _maxXftmSupply
        );

    function lastRefreshCrTimestamp() external view returns (uint256);

    function maxXftmSupply() external view returns (uint256);

    function minCollateralRatio() external view returns (uint256);

    function mint(uint256 _fantasmIn, uint256 _minXftmOut) external payable;

    function mintPaused() external view returns (bool);

    function mintingFee() external view returns (uint256);

    function oracle() external view returns (address);

    function owner() external view returns (address);

    function priceBand() external view returns (uint256);

    function priceTarget() external view returns (uint256);

    function ratioStepDown() external view returns (uint256);

    function ratioStepUp() external view returns (uint256);

    function recollateralize(uint256 _amount) external;

    function recollateralizeETH() external payable;

    function redeem(uint256 _xftmIn, uint256 _minFantasmOut, uint256 _minFtmOut) external;

    function redeemPaused() external view returns (bool);

    function redemptionFee() external view returns (uint256);

    function reduceExcessFtm(uint256 _amount) external;

    function refreshCollateralRatio() external;

    function refreshCooldown() external view returns (uint256);

    function renounceOwnership() external;

    function setCollateralRatioOptions(
        uint256 _ratioStepUp,
        uint256 _ratioStepDown,
        uint256 _priceBand,
        uint256 _refreshCooldown
    ) external;

    function setFeeReserve(address _feeReserve) external;

    function setFees(uint256 _mintingFee, uint256 _redemptionFee) external;

    function setMaxXftmSupply(uint256 _newValue) external;

    function setMinCollateralRatio(uint256 _minCollateralRatio) external;

    function setOracle(address _oracle) external;

    function swapPaths(uint256) external view returns (address);

    function swapRouter() external view returns (address);

    function swapSlippage() external view returns (uint256);

    function toggle(bool _mintPaused, bool _redeemPaused) external;

    function toggleCollateralRatio(bool _collateralRatioPaused) external;

    function transferOwnership(address newOwner) external;

    function unclaimedFantasm() external view returns (uint256);

    function unclaimedFtm() external view returns (uint256);

    function unclaimedXftm() external view returns (uint256);

    function usableFtmBalance() external view returns (uint256);

    function userInfo(address)
        external
        view
        returns (uint256 xftmBalance, uint256 fantasmBalance, uint256 ftmBalance, uint256 lastAction);

    function xftm() external view returns (address);

    function zap(uint256 _minXftmOut) external payable;

    receive() external payable;
}

interface Monoswap {
    event AddLiquidity(
        address indexed provider,
        uint256 indexed pid,
        address indexed token,
        uint256 liquidityAmount,
        uint256 vcashAmount,
        uint256 tokenAmount,
        uint256 price
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolBalanced(address _token, uint256 vcashIn);
    event PoolStatusChanged(address _token, uint8 oldStatus, uint8 newStatus);
    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed pid,
        address indexed token,
        uint256 liquidityAmount,
        uint256 vcashAmount,
        uint256 tokenAmount,
        uint256 price
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 swapVcashValue
    );
    event SyntheticPoolPriceChanged(address _token, uint256 price);

    function _removeLiquidity(
        address _token,
        uint256 liquidity,
        address to
    ) external view returns (uint256 poolValue, uint256 liquidityIn, uint256 vcashOut, uint256 tokenOut);

    function addLiquidity(address _token, uint256 _amount, address to) external returns (uint256 liquidity);

    function addLiquidityETH(address to) external payable returns (uint256 liquidity);

    function addLiquidityPair(
        address _token,
        uint256 vcashAmount,
        uint256 tokenAmount,
        address to
    ) external returns (uint256 liquidity);

    function addSpecialToken(address _token, uint256 _price, uint8 _status) external returns (uint256 _pid);

    function getAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) external view returns (uint256 tokenInPrice, uint256 tokenOutPrice, uint256 amountIn, uint256 tradeVcashValue);

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 tokenInPrice, uint256 tokenOutPrice, uint256 amountOut, uint256 tradeVcashValue);

    function getConfig()
        external
        view
        returns (address _vCash, address _weth, address _feeTo, uint16 _fees, uint16 _devFee);

    function getPool(address _token)
        external
        view
        returns (uint256 poolValue, uint256 tokenBalanceVcashValue, uint256 vcashCredit, uint256 vcashDebt);

    function initialize(address _monoXPool, address _vcash) external;

    function lastTradedBlock(address) external view returns (uint256);

    function listNewToken(
        address _token,
        uint256 _price,
        uint256 vcashAmount,
        uint256 tokenAmount,
        address to
    ) external returns (uint256 _pid, uint256 liquidity);

    function monoXPool() external view returns (address);

    function owner() external view returns (address);

    function poolSize() external view returns (uint256);

    function poolSizeMinLimit() external view returns (uint256);

    function pools(address)
        external
        view
        returns (
            uint256 pid,
            uint256 lastPoolValue,
            address token,
            uint8 status,
            uint112 vcashDebt,
            uint112 vcashCredit,
            uint112 tokenBalance,
            uint256 price,
            uint256 createdAt
        );

    function priceAdjusterRole(address) external view returns (bool);

    function rebalancePool(address _token) external;

    function removeLiquidity(
        address _token,
        uint256 liquidity,
        address to,
        uint256 minVcashOut,
        uint256 minTokenOut
    ) external returns (uint256 vcashOut, uint256 tokenOut);

    function removeLiquidityETH(
        uint256 liquidity,
        address to,
        uint256 minVcashOut,
        uint256 minTokenOut
    ) external returns (uint256 vcashOut, uint256 tokenOut);

    function renounceOwnership() external;

    function setDevFee(uint16 _devFee) external;

    function setFeeTo(address _feeTo) external;

    function setFees(uint16 _fees) external;

    function setPoolSizeMinLimit(uint256 _poolSizeMinLimit) external;

    function setSynthPoolPrice(address _token, uint256 price) external;

    function setTokenInsurance(address _token, uint256 _insurance) external;

    function setTokenStatus(address _token, uint8 _status) external;

    function swapETHForExactToken(
        address tokenOut,
        uint256 amountInMax,
        uint256 amountOut,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountIn);

    function swapExactETHForToken(
        address tokenOut,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function swapExactTokenForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapExactTokenForToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapTokenForExactETH(
        address tokenIn,
        uint256 amountInMax,
        uint256 amountOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountIn);

    function swapTokenForExactToken(
        address tokenIn,
        address tokenOut,
        uint256 amountInMax,
        uint256 amountOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountIn);

    function tokenInsurance(address) external view returns (uint256);

    function tokenPoolStatus(address) external view returns (uint8);

    function transferOwnership(address newOwner) external;

    function updatePoolPrice(address _token, uint256 _newPrice) external;

    function updatePoolStatus(address _token, uint8 _status) external;

    function updatePriceAdjuster(address account, bool _status) external;
}

interface IDMMExchangeRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata poolsPath,
        IERC20[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata poolsPath,
        IERC20[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata poolsPath,
        IERC20[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata poolsPath,
        IERC20[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata poolsPath,
        IERC20[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata poolsPath,
        IERC20[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata poolsPath,
        IERC20[] calldata path
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata poolsPath,
        IERC20[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface MonoXPool {
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event URI(string value, uint256 indexed id);

    function WETH() external view returns (address);

    function admin() external view returns (address);

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) external view returns (uint256[] memory);

    function burn(address account, uint256 id, uint256 amount) external;

    function createdAt(uint256) external view returns (uint256);

    function depositWETH(uint256 amount) external;

    function initialize(address _WETH) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);

    function isUnofficial(uint256) external view returns (bool);

    function liquidityLastAddedOf(uint256 pid, address account) external view returns (uint256);

    function mint(address account, uint256 id, uint256 amount) external;

    function mintLp(address account, uint256 id, uint256 amount, bool _isUnofficial) external;

    function owner() external view returns (address);

    function renounceOwnership() external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function safeTransferERC20Token(address token, address to, uint256 amount) external;

    function safeTransferETH(address to, uint256 amount) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;

    function setAdmin(address _admin) external;

    function setApprovalForAll(address operator, bool approved) external;

    function setURI(string memory uri) external;

    function setWhitelist(address _whitelist, bool _isWhitelist) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function topHolder(uint256) external view returns (address);

    function topLPHolderOf(uint256 pid) external view returns (address);

    function totalSupply(uint256) external view returns (uint256);

    function totalSupplyOf(uint256 pid) external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function uri(uint256) external view returns (string memory);

    function withdrawWETH(uint256 amount) external;
}

interface USDC {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);
    event Blacklisted(address indexed _account);
    event BlacklisterChanged(address indexed newBlacklister);
    event Burn(address indexed burner, uint256 amount);
    event MasterMinterChanged(address indexed newMasterMinter);
    event Mint(address indexed minter, address indexed to, uint256 amount);
    event MinterConfigured(address indexed minter, uint256 minterAllowedAmount);
    event MinterRemoved(address indexed oldMinter);
    event OwnershipTransferred(address previousOwner, address newOwner);
    event Pause();
    event PauserChanged(address indexed newAddress);
    event RescuerChanged(address indexed newRescuer);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event UnBlacklisted(address indexed _account);
    event Unpause();

    function CANCEL_AUTHORIZATION_TYPEHASH() external view returns (bytes32);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external view returns (bytes32);

    function RECEIVE_WITH_AUTHORIZATION_TYPEHASH() external view returns (bytes32);

    function TRANSFER_WITH_AUTHORIZATION_TYPEHASH() external view returns (bytes32);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function blacklist(address _account) external;

    function blacklister() external view returns (address);

    function burn(uint256 _amount) external;

    function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);

    function currency() external view returns (string memory);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 decrement) external returns (bool);

    function increaseAllowance(address spender, uint256 increment) external returns (bool);

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenCurrency,
        uint8 tokenDecimals,
        address newMasterMinter,
        address newPauser,
        address newBlacklister,
        address newOwner
    ) external;

    function initializeV2(string memory newName) external;

    function initializeV2_1(address lostAndFound) external;

    function isBlacklisted(address _account) external view returns (bool);

    function isMinter(address account) external view returns (bool);

    function masterMinter() external view returns (address);

    function mint(address _to, uint256 _amount) external returns (bool);

    function minterAllowance(address minter) external view returns (uint256);

    function name() external view returns (string memory);

    function nonces(address owner) external view returns (uint256);

    function owner() external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function pauser() external view returns (address);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function removeMinter(address minter) external returns (bool);

    function rescueERC20(address tokenContract, address to, uint256 amount) external;

    function rescuer() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function transferOwnership(address newOwner) external;

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function unBlacklist(address _account) external;

    function unpause() external;

    function updateBlacklister(address _newBlacklister) external;

    function updateMasterMinter(address _newMasterMinter) external;

    function updatePauser(address _newPauser) external;

    function updateRescuer(address newRescuer) external;

    function version() external view returns (string memory);
}

interface MonoToken {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Snapshot(uint256 id);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function DELEGATION_TYPEHASH() external view returns (bytes32);

    function DOMAIN_TYPEHASH() external view returns (bytes32);

    function MINTER_ROLE() external view returns (bytes32);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);

    function cap() external view returns (uint256);

    function checkpoints(address, uint32) external view returns (uint32 fromBlock, uint256 votes);

    function childChainManagerProxy() external view returns (address);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function delegate(address delegatee) external;

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    function delegates(address delegator) external view returns (address);

    function deposit(address user, bytes memory depositData) external;

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function mint(address _to, uint256 _amount) external;

    function name() external view returns (string memory);

    function nonces(address) external view returns (uint256);

    function numCheckpoints(address) external view returns (uint32);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function setMinter(address _minter) external;

    function snapshot() external returns (uint256 currentId);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transferOwnership(address newOwner) external;

    function updateChildChainManager(address newChildChainManagerProxy) external;

    function withdraw(uint256 amount) external;
}

interface IOneRingVault {
    function depositSafe(uint256 _amount, address _token, uint256 _minAmount) external;

    function withdraw(uint256 _amount, address _underlying) external;

    function balanceOf(address account) external view returns (uint256);
}

interface ICEtherDelegate {
    function borrow(uint256 borrowAmount) external returns (uint256);

    function getCash() external view returns (uint256);

    function mint() external payable;

    function balanceOf(address account) external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function underlying() external view returns (address);
}

interface IUnitroller {
    function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);

    function exitMarket(address cTokenAddress) external returns (uint256);

    function cTokensByUnderlying(address) external view returns (address);

    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);

    function borrowCaps(address) external view returns (uint256);
    function getAllMarkets() external view returns (address[] memory);
}

interface IBalancerVault {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256 amountCalculated);

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external;

    struct JoinPoolRequest {
        address[] asset;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        address[] asset;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable;

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external payable;

    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
}

interface ICointroller {
    event ActionPaused(string action, bool pauseState);
    event ActionPaused(address rToken, string action, bool pauseState);
    event ContributorRifiSpeedUpdated(address indexed contributor, uint256 newSpeed);
    event DistributedBorrowerRifi(
        address indexed rToken, address indexed borrower, uint256 rifiDelta, uint256 rifiBorrowIndex
    );
    event DistributedSupplierRifi(
        address indexed rToken, address indexed supplier, uint256 rifiDelta, uint256 rifiSupplyIndex
    );
    event Failure(uint256 error, uint256 info, uint256 detail);
    event MarketEntered(address rToken, address account);
    event MarketExited(address rToken, address account);
    event MarketListed(address rToken);
    event NewBorrowCap(address indexed rToken, uint256 newBorrowCap);
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);
    event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);
    event NewCollateralFactor(address rToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa);
    event NewLiquidationIncentive(uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa);
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);
    event NewPriceOracle(address oldPriceOracle, address newPriceOracle);
    event RifiGranted(address recipient, uint256 amount);
    event RifiSpeedUpdated(address indexed rToken, uint256 newSpeed);

    function _become(address unitroller) external;

    function _borrowGuardianPaused() external view returns (bool);

    function _grantRifi(address recipient, uint256 amount) external;

    function _mintGuardianPaused() external view returns (bool);

    function _setBorrowCapGuardian(address newBorrowCapGuardian) external;

    function _setBorrowPaused(address rToken, bool state) external returns (bool);

    function _setCloseFactor(uint256 newCloseFactorMantissa) external returns (uint256);

    function _setCollateralFactor(address rToken, uint256 newCollateralFactorMantissa) external returns (uint256);

    function _setContributorRifiSpeed(address contributor, uint256 rifiSpeed) external;

    function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa) external returns (uint256);

    function _setMarketBorrowCaps(address[] memory rTokens, uint256[] memory newBorrowCaps) external;

    function _setMintPaused(address rToken, bool state) external returns (bool);

    function _setPauseGuardian(address newPauseGuardian) external returns (uint256);

    function _setPriceOracle(address newOracle) external returns (uint256);

    function _setRifiSpeed(address rToken, uint256 rifiSpeed) external;

    function _setSeizePaused(bool state) external returns (bool);

    function _setTransferPaused(bool state) external returns (bool);

    function _supportMarket(address rToken) external returns (uint256);

    function accountAssets(address, uint256) external view returns (address);

    function admin() external view returns (address);

    function allMarkets(uint256) external view returns (address);

    function borrowAllowed(address rToken, address borrower, uint256 borrowAmount) external returns (uint256);

    function borrowCapGuardian() external view returns (address);

    function borrowCaps(address) external view returns (uint256);

    function borrowGuardianPaused(address) external view returns (bool);

    function borrowVerify(address rToken, address borrower, uint256 borrowAmount) external;

    function checkMembership(address account, address rToken) external view returns (bool);

    function claimRifi(address[] memory holders, address[] memory rTokens, bool borrowers, bool suppliers) external;

    function claimRifi(address holder, address[] memory rTokens) external;

    function claimRifi(address holder) external;

    function closeFactorMantissa() external view returns (uint256);

    function cointrollerImplementation() external view returns (address);

    function enterMarkets(address[] memory rTokens) external returns (uint256[] memory);

    function exitMarket(address rTokenAddress) external returns (uint256);

    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);

    function getAllMarkets() external view returns (address[] memory);

    function getAssetsIn(address account) external view returns (address[] memory);

    function getBlockNumber() external view returns (uint256);

    function getHypotheticalAccountLiquidity(
        address account,
        address rTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256, uint256);

    function getRifiAddress() external view returns (address);

    function initialize(address rifi) external;

    function isCointroller() external view returns (bool);

    function lastContributorBlock(address) external view returns (uint256);

    function liquidateBorrowAllowed(
        address rTokenBorrowed,
        address rTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function liquidateBorrowVerify(
        address rTokenBorrowed,
        address rTokenCollateral,
        address liquidator,
        address borrower,
        uint256 actualRepayAmount,
        uint256 seizeTokens
    ) external;

    function liquidateCalculateSeizeTokens(
        address rTokenBorrowed,
        address rTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256);

    function liquidationIncentiveMantissa() external view returns (uint256);

    function markets(address) external view returns (bool isListed, uint256 collateralFactorMantissa, bool isRified);

    function maxAssets() external view returns (uint256);

    function mintAllowed(address rToken, address minter, uint256 mintAmount) external returns (uint256);

    function mintGuardianPaused(address) external view returns (bool);

    function mintVerify(address rToken, address minter, uint256 actualMintAmount, uint256 mintTokens) external;

    function oracle() external view returns (address);

    function pauseGuardian() external view returns (address);

    function pendingAdmin() external view returns (address);

    function pendingCointrollerImplementation() external view returns (address);

    function redeemAllowed(address rToken, address redeemer, uint256 redeemTokens) external returns (uint256);

    function redeemVerify(address rToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) external;

    function repayBorrowAllowed(
        address rToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function repayBorrowVerify(
        address rToken,
        address payer,
        address borrower,
        uint256 actualRepayAmount,
        uint256 borrowerIndex
    ) external;

    function rifiAccrued(address) external view returns (uint256);

    function rifiBorrowState(address) external view returns (uint224 index, uint32 block);

    function rifiBorrowerIndex(address, address) external view returns (uint256);

    function rifiContributorSpeeds(address) external view returns (uint256);

    function rifiInitialIndex() external view returns (uint224);

    function rifiRate() external view returns (uint256);

    function rifiSpeeds(address) external view returns (uint256);

    function rifiSupplierIndex(address, address) external view returns (uint256);

    function rifiSupplyState(address) external view returns (uint224 index, uint32 block);

    function seizeAllowed(
        address rTokenCollateral,
        address rTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function seizeGuardianPaused() external view returns (bool);

    function seizeVerify(
        address rTokenCollateral,
        address rTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external;

    function transferAllowed(
        address rToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external returns (uint256);

    function transferGuardianPaused() external view returns (bool);

    function transferVerify(address rToken, address src, address dst, uint256 transferTokens) external;

    function updateContributorRewards(address contributor) external;
}

interface IPriceFeed {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function fetchPrice() external returns (uint256);
}

interface IRToken {
    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Failure(uint256 error, uint256 info, uint256 detail);
    event LiquidateBorrow(
        address liquidator, address borrower, uint256 repayAmount, address rTokenCollateral, uint256 seizeTokens
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewCointroller(address oldCointroller, address newCointroller);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event RepayBorrow(
        address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
    );
    event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function _acceptAdmin() external returns (uint256);

    function _addReserves(uint256 addAmount) external returns (uint256);

    function _becomeImplementation(bytes memory data) external;

    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function _resignImplementation() external;

    function _setCointroller(address newCointroller) external returns (uint256);

    function _setInterestRateModel(address newInterestRateModel) external returns (uint256);

    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function accrueInterest() external returns (uint256);

    function admin() external view returns (address);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function cointroller() external view returns (address);

    function decimals() external view returns (uint8);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function getCash() external view returns (uint256);

    function implementation() external view returns (address);

    function initialize(
        address underlying_,
        address cointroller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external;

    function initialize(
        address cointroller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external;

    function interestRateModel() external view returns (address);

    function isRToken() external view returns (bool);

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address rTokenCollateral
    ) external returns (uint256);

    function mint() external payable;

    function mint(uint256 mintAmount) external returns (uint256);

    function name() external view returns (string memory);

    function pendingAdmin() external view returns (address);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function sweepToken(address token) external;

    function symbol() external view returns (string memory);

    function totalBorrows() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function underlying() external view returns (address);
}

interface ISimplePriceOracle {
    event PricePosted(
        address asset, uint256 previousPriceMantissa, uint256 requestedPriceMantissa, uint256 newPriceMantissa
    );

    function getUnderlyingPrice(address rToken) external view returns (uint256);

    function isPriceOracle() external view returns (bool);

    function oracleData(address) external view returns (address);

    function setOracleData(address rToken, address _oracle) external;
}

interface ITreasureMarketplaceBuyer {
    function buyItem(
        address _nftAddress,
        uint256 _tokenId,
        address _owner,
        uint256 _quantity,
        uint256 _pricePerItem
    ) external;

    function marketplace() external view returns (address);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external returns (bytes4);

    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function withdraw() external;

    function withdrawNFT(address _nftAddress, uint256 _tokenId, uint256 _quantity) external;
}

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    function burn(uint256 id) external;
}

interface IRewardsHypervisor {
    function deposit(uint256 visrDeposit, address from, address to) external returns (uint256 shares);

    function owner() external view returns (address);

    function snapshot() external;

    function transferOwnership(address newOwner) external;

    function transferTokenOwnership(address newOwner) external;

    function visr() external view returns (address);

    function vvisr() external view returns (address);

    function withdraw(uint256 shares, address to, address from) external returns (uint256 rewards);
}

interface IvVISR {
    function balanceOf(address account) external view returns (uint256);

    function mint(address account, uint256 amount) external;
}

interface InotVerified {
    function mint(uint256 value) external;

    function redeem(uint256 value) external;
}

interface IRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface ILendingPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
    /**
     * @dev Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     *
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    /**
     * @dev Allows depositors to enable/disable a specific deposited asset as collateral
     * @param asset The address of the underlying asset deposited
     * @param useAsCollateral `true` if the user wants to use the deposit as collateral, `false` otherwise
     *
     */
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(address _reserve, uint256 _amount, address _onBehalfOf) external payable;
    /**
     * @dev Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated using the reserve asset,
     *   and receives a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     *
     */
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;
    function getReserveData(address asset) external view returns (DataTypesAave.ReserveData memory);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface ILendingPoolAddressesProvider {
    event MarketIdSet(string newMarketId);
    event LendingPoolUpdated(address indexed newAddress);
    event ConfigurationAdminUpdated(address indexed newAddress);
    event EmergencyAdminUpdated(address indexed newAddress);
    event LendingPoolConfiguratorUpdated(address indexed newAddress);
    event LendingPoolCollateralManagerUpdated(address indexed newAddress);
    event PriceOracleUpdated(address indexed newAddress);
    event LendingRateOracleUpdated(address indexed newAddress);
    event ProxyCreated(bytes32 id, address indexed newAddress);
    event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy);

    function getMarketId() external view returns (string memory);

    function setMarketId(string calldata marketId) external;

    function setAddress(bytes32 id, address newAddress) external;

    function setAddressAsProxy(bytes32 id, address impl) external;

    function getAddress(bytes32 id) external view returns (address);

    function getLendingPool() external view returns (address);

    function setLendingPoolImpl(address pool) external;

    function getLendingPoolConfigurator() external view returns (address);

    function setLendingPoolConfiguratorImpl(address configurator) external;

    function getLendingPoolCollateralManager() external view returns (address);

    function setLendingPoolCollateralManager(address manager) external;

    function getPoolAdmin() external view returns (address);

    function setPoolAdmin(address admin) external;

    function getEmergencyAdmin() external view returns (address);

    function setEmergencyAdmin(address admin) external;

    function getPriceOracle() external view returns (address);

    function setPriceOracle(address priceOracle) external;

    function getLendingRateOracle() external view returns (address);

    function setLendingRateOracle(address lendingRateOracle) external;
}

interface AToken {
    function redeem(uint256 amount) external;
}


interface VyperContract {
    function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount) external;

    function balanceOf(address account) external view returns (uint256);

    function mint(address account, uint256 value) external;

    function approve(address spender, uint256 value) external;

    function transferUnderlyingTo(address target, uint256 amount) external returns (uint256);

    function deposit(uint256 amounts, address recipient) external returns (uint256);

    function exchange(
        address _pool,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
}

interface IAggregator {
    function latestAnswer() external view returns (int256 answer);
}

interface CErc20Interface {
    function mint(uint256 mintAmount) external returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);
}

interface IUSDT {
    function approve(address _spender, uint256 _value) external;

    function balanceOf(address owner) external view returns (uint256);

    function transfer(address _to, uint256 _value) external;
}

interface IDaiFlashloan {
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

interface IAaveFlashloan {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IcurveYSwap {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface IHarvestUsdcVault {
    function deposit(uint256 amountWei) external;

    function withdraw(uint256 numberOfShares) external;

    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router {
    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function factory() external view returns (address);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    receive() external payable;
}

interface ICurvePool {
    function A() external view returns (uint256 out);

    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable returns (uint256);

    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external returns (uint256);

    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external returns (uint256);

    function admin_fee() external view returns (uint256 out);

    function balances(uint256 arg0) external view returns (uint256 out);

    function calc_token_amount(uint256[] memory amounts, bool is_deposit) external view returns (uint256 lp_tokens);

    /// @dev vyper upgrade changed this on us
    function coins(int128 arg0) external view returns (address out);

    /// @dev vyper upgrade changed this on us
    function coins(uint256 arg0) external view returns (address out);

    /// @dev vyper upgrade changed this on us
    function underlying_coins(int128 arg0) external view returns (address out);

    /// @dev vyper upgrade changed this on us
    function underlying_coins(uint256 arg0) external view returns (address out);

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable;

    // newer pools have this improved version of exchange_underlying
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth,
        address receiver
    ) external returns (uint256);

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;

    function exchange_underlying(address pool, int128 i, int128 j, uint256 dx, uint256 min_dy) external;

    function fee() external view returns (uint256 out);

    function future_A() external view returns (uint256 out);

    function future_fee() external view returns (uint256 out);

    function future_admin_fee() external view returns (uint256 out);

    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);

    function get_virtual_price() external view returns (uint256 out);

    function remove_liquidity(
        uint256 token_amount,
        uint256[2] memory min_amounts
    ) external returns (uint256[2] memory);

    function remove_liquidity(
        uint256 token_amount,
        uint256[3] memory min_amounts
    ) external returns (uint256[3] memory);

    function remove_liquidity_imbalance(uint256[3] memory amounts, uint256 max_burn_amount) external;

    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external;
}

interface IBeanStalk {
    function depositBeans(uint256) external;

    function emergencyCommit(uint32 bip) external;

    function deposit(address token, uint256 amount) external;

    function vote(uint32 bip) external;

    function bip(uint32 bipId)
        external
        view
        returns (address, uint32, uint32, bool, int256, uint128, uint256, uint256);

    struct FacetCut {
        address facetAddress;
        uint8 action;
        bytes4[] functionSelectors;
    }

    function propose(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata,
        uint8 _pauseOrUnpause
    ) external;

    function numberOfBips() external view returns (uint32);
}

library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeApprove: approve failed"
        );
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeTransfer: transfer failed"
        );
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::transferFrom: transferFrom failed"
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper::safeTransferETH: ETH transfer failed");
    }
}

library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(0, 0x09, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

interface INOVO {
    function approve(address spender, uint256 value) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IBuildFinance {
    function propose(address _target, uint256 _value, bytes memory _data) external returns (uint256);

    function vote(uint256 _proposalId, bool _support) external;

    function execute(
        uint256 _proposalId,
        address _target,
        uint256 _value,
        bytes memory _data
    ) external payable returns (bytes memory);

    function mint(address account, uint256 amount) external;

    function proposalCount() external returns (int256);

    function state(uint256 proposalId) external returns (uint256);
}

interface MultiSig {
    function confirmTransaction(uint256 transactionId) external;

    function submitTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) external returns (uint256 transactionId);

    function getConfirmations(uint256 transactionId) external view returns (address[] memory _confirmations);

    function required() external view returns (uint256);
}

interface Flippaz {
    function bid() external payable;

    function ownerWithdrawAllTo(address toAddress) external;
}

interface IDOODLENFTXVault {
    function flashLoan(address receiver, address token, uint256 amount, bytes memory data) external returns (bool);
    function redeem(uint256 amount, uint256[] calldata specificIds) external returns (uint256[] calldata);
    function balanceOf(address account) external view returns (uint256);
    function mint(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts /* ignored for ERC721 vaults */
    ) external returns (uint256);
}

interface ISushiSwap {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}

interface IOmni {
    function supplyERC721(
        address asset,
        DataTypes.ERC721SupplyParams[] memory tokenData,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdrawERC721(address asset, uint256[] memory tokenIds, address to) external returns (uint256);
    function liquidationERC721(
        address collateralAsset,
        address liquidationAsset,
        address user,
        uint256 collateralTokenId,
        uint256 liquidationAmount,
        bool receiveNToken
    ) external;

    struct ERC721SupplyParams {
        uint256 tokenId;
        bool useAsCollateral;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor,
            uint256 erc721HealthFactor
        );
}

interface DataTypes {
    struct ERC721SupplyParams {
        uint256 tokenId;
        bool useAsCollateral;
    }
}

interface ILib {
    function attack() external returns (bool);

    function withdrawAll() external returns (bool);
}

interface FToken {}

interface IGovernorAlpha {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function state(uint256 proposalId) external view;
}

interface IChain {
    function submit(
        uint32 _dataTimestamp,
        bytes32 _root,
        bytes32[] memory _keys,
        uint256[] memory _values,
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s
    ) external;
}

interface IFortressPriceOracle {
    function getUnderlyingPrice(FToken fToken) external view returns (uint256);
}

interface IFTS {
    function approve(address spender, uint256 rawAmount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IfFTS {
    function mint(uint256 mintAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

interface IFBep20Delegator {
    function getCash() external view returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function underlying() external returns (address);
}

interface IBorrowerOperations {
    function openTrove(
        uint256 _maxFee,
        uint256 _LUSDAmount,
        uint256 _ETHAmount,
        address _upperHint,
        address _lowerHint,
        address _frontEndTag
    ) external;
}

interface IARTH is IERC20 {}

interface IARTHUSD {
    function balanceOf(address) external returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IVyper {
    function exchange_underlying(int128, int128, uint256, uint256, address) external returns (uint256);
}

interface I88mph {
    function init(address newOwner, string memory tokenName, string memory tokenSymbol) external;
    function mint(address to, uint256 tokenId) external;
    function burn(uint256 tokenId) external;
    function owner() external view returns (address);
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IBAYCi {
    function setApprovalForAll(address operator, bool approved) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface INFTXVault {
    function redeem(uint256 amount, uint256[] memory specificIds) external returns (uint256[] memory);
    function flashLoan(address receiver, address token, uint256 amount, bytes memory data) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(uint256[] memory tokenIds, uint256[] memory amounts) external returns (uint256);
}

interface IAirdrop {
    function claimTokens() external;
}

interface ILand {
    function _burn(address from, address owner, uint256 id) external;
    function _numNFTPerAddress(address) external view returns (uint256);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IWFTM is IERC20Metadata {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    receive() external payable;
    fallback() external payable;
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

interface IWETH is IERC20Metadata {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    receive() external payable;
    fallback() external payable;
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

interface IGrimBoostVault {
    event NewStratCandidate(address implementation);
    event UpgradeStrat(address implementation);

    function want() external view returns (IERC20);
    function balance() external view returns (uint256);
    function available() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function depositAll() external;
    function deposit(uint256 _amount) external;
    function earn() external;
    function withdrawAll() external;
    function withdraw(uint256 _shares) external;
    function proposeStrat(address _implementation) external;
    function upgradeStrat() external;
    function inCaseTokensGetStuck(address _token) external;
    function depositFor(address token, uint256 _amount, address user) external;
}

interface IFlashLoanRecipient {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IBeethovenVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IRedactedCartelSafeERC20 {
    function unFreezeToken() external;
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IBadGuysRPFERC721 {
    function WhiteListMint(bytes32[] calldata _merkleProof, uint256 chosenAmount) external;

    function balanceOf(address owner) external view returns (uint256 balance);

    function flipPauseMinting() external;
}

interface IAkutarNFT {
    function processRefunds() external;

    function bid(uint8 amount) external payable;

    function claimProjectFunds() external;
}

interface IFortubeBank {
    function flashloan(address receiver, address token, uint256 amount, bytes memory params) external;
    function repay(address token, uint256 repayAmount) external payable returns (uint256);
    function controller() external returns (address);
}

interface IVaultFlipToFlip {
    function deposit(uint256 _amount) external;
    function earned(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function principalOf(address account) external view returns (uint256);
    function harvest() external returns (uint256 bounty);
    function pid() external returns (uint256);
    function getReward() external;
}

interface IBunnyZap {
    function zapIn(address _to) external payable;
    function zapInToken(address _from, uint256 amount, address _to) external;
}

interface IElevenNeverSellVault {
    function depositAll() external;
    function emergencyBurn() external;
    function withdrawAll() external;
}

interface IOpyn {
    function addERC20CollateralOption(uint256 amtToCreate, uint256 amtCollateral, address receiver) external;

    function exercise(uint256 oTokensToExercise, address payable[] memory vaultsToExerciseFrom) external payable;

    function removeUnderlying() external;
}

interface ICFToken {
    function _transfer(address from, address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IDPPOracle {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address _assetTo, bytes calldata data) external;
}

interface IDODOCallee {
    // function DVMSellShareCall(
    //     address sender,
    //     uint256 burnShareAmount,
    //     uint256 baseAmount,
    //     uint256 quoteAmount,
    //     bytes calldata data
    // ) external;

    // function DVMFlashLoanCall(
    //     address sender,
    //     uint256 baseAmount,
    //     uint256 quoteAmount,
    //     bytes calldata data
    // ) external;

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;

    //   function DSPFlashLoanCall(
    //       address sender,
    //       uint256 baseAmount,
    //       uint256 quoteAmount,
    //       bytes calldata data
    //   ) external;

    //   function CPCancelCall(
    //       address sender,
    //       uint256 amount,
    //       bytes calldata data
    //   ) external;

    // function CPClaimBidCall(
    //       address sender,
    //       uint256 baseAmount,
    //       uint256 quoteAmount,
    //       bytes calldata data
    //   ) external;

    //   function NFTRedeemCall(
    //       address payable assetTo,
    //       uint256 quoteAmount,
    //       bytes calldata
    //   ) external;
}

interface IQuoter {
    function quoteExactInputSingle(
        address,
        address,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256);
}

interface IPoolInitializer {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}

interface INonfungiblePositionManager is IPoolInitializer {
    event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function burn(uint256 tokenId) external payable;
}

interface IERC4626 is IERC20 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function previewDeposit(uint256 assets) external view returns (uint256);

    function previewMint(uint256 shares) external view returns (uint256);

    function previewWithdraw(uint256 assets) external view returns (uint256);

    function previewRedeem(uint256 shares) external view returns (uint256);

    function maxDeposit(address) external view returns (uint256);

    function maxMint(address) external view returns (uint256);

    function maxWithdraw(address owner) external view returns (uint256);

    function maxRedeem(address owner) external view returns (uint256);
}

interface IPresaleV4 {
    function directTotalTokensSold() external view returns (uint256);
    function maxTokensToSell() external view returns (uint256);
    function buyWithEthDynamic(uint256 amount) external payable returns (bool);
}

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2 ** 256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) { revert(0, 0) }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) { revert(0, 0) }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(uint256 x, uint256 n, uint256 scalar) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) { revert(0, 0) }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) { revert(0, 0) }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) { revert(0, 0) }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) { revert(0, 0) }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
                )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
                )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(IERC20 token, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
                )
        }

        require(success, "APPROVE_FAILED");
    }
}

abstract contract Nonces {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    mapping(address => uint256) private _nonces;

    /**
     * @dev Returns an the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual returns (uint256) {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
        return current;
    }
}

interface IPancakeV3PoolActions {
    function initialize(uint160 sqrtPriceX96) external;

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;

    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

interface IPancakeV3PoolDerivedState {
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    function snapshotCumulativesInside(
        int24 tickLower,
        int24 tickUpper
    ) external view returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside);
}

interface IPancakeV3PoolImmutables {
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function tickSpacing() external view returns (int24);

    function maxLiquidityPerTick() external view returns (uint128);
}

interface IPancakeV3PoolState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );

    function feeGrowthGlobal0X128() external view returns (uint256);

    function feeGrowthGlobal1X128() external view returns (uint256);

    function protocolFees() external view returns (uint128 token0, uint128 token1);

    function liquidity() external view returns (uint128);

    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    function tickBitmap(int16 wordPosition) external view returns (uint256);

    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

interface IPancakeV3PoolOwnerActions {
    function setFeeProtocol(uint32 feeProtocol0, uint32 feeProtocol1) external;

    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    function setLmPool(address lmPool) external;
}

interface IPancakeV3Pool is
    IPancakeV3PoolImmutables,
    IPancakeV3PoolState,
    IPancakeV3PoolDerivedState,
    IPancakeV3PoolActions,
    IPancakeV3PoolOwnerActions
{}
